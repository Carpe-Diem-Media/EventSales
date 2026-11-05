defmodule EventSales.Analytics.EventSnapshotRefreshFenceTest do
  use ExUnit.Case, async: false

  alias EventSales.Analytics.EventSnapshotRefreshFence
  alias EventSales.Repo
  alias EventSales.TestSupport.EventSnapshotRefreshTestSupport
  alias EventSales.TestSupport.UnboxedPostgres

  test "prepare_coherent_transaction! establishes repeatable read before projection statements" do
    UnboxedPostgres.with_connection(fn ->
      assert EventSnapshotRefreshFence.use_repeatable_read_isolation?()

      transaction_opts =
        [timeout: 30_000] ++ EventSnapshotRefreshFence.coherent_transaction_opts()

      assert {:ok, :ok} =
               Repo.transaction(
                 fn ->
                   :ok = EventSnapshotRefreshFence.prepare_coherent_transaction!()

                   level = EventSnapshotRefreshTestSupport.transaction_isolation_level()
                   assert String.downcase(level) == "repeatable read"
                   :ok
                 end,
                 transaction_opts
               )
    end)
  end

  test "coherent_transaction_opts alone does not establish repeatable read on Postgrex" do
    UnboxedPostgres.with_connection(fn ->
      assert EventSnapshotRefreshFence.use_repeatable_read_isolation?()

      transaction_opts =
        [timeout: 30_000] ++ EventSnapshotRefreshFence.coherent_transaction_opts()

      assert {:ok, level} =
               Repo.transaction(
                 fn ->
                   EventSnapshotRefreshTestSupport.transaction_isolation_level()
                 end,
                 transaction_opts
               )

      assert String.downcase(level) == "read committed"
    end)
  end

  test "event refresh transaction fence blocks a second connection until commit" do
    event_id = Ecto.UUID.generate()
    parent = self()

    holder =
      Task.async(fn ->
        UnboxedPostgres.with_connection(fn ->
          holder_backend = EventSnapshotRefreshFence.connection_backend_pid()

          EventSnapshotRefreshFence.with_serial_event_refresh(event_id, fn ->
            send(parent, {
              :holder_ready,
              holder_backend,
              Repo.in_transaction?(),
              EventSnapshotRefreshTestSupport.transaction_isolation_level()
            })

            receive do
              :commit_refresh_fence -> :ok
            after
              15_000 -> :timeout
            end
          end)
        end)
      end)

    assert_receive {:holder_ready, holder_backend, true, "read committed"}, 5_000

    waiter =
      Task.async(fn ->
        UnboxedPostgres.with_connection(fn ->
          waiter_backend = EventSnapshotRefreshFence.connection_backend_pid()
          send(parent, {:waiter_backend, waiter_backend})

          EventSnapshotRefreshFence.with_serial_event_refresh(event_id, fn ->
            send(parent, :waiter_acquired)
            :ok
          end)
        end)
      end)

    assert_receive {:waiter_backend, waiter_backend}, 5_000
    assert waiter_backend != holder_backend

    EventSnapshotRefreshTestSupport.wait_for_advisory_lock_wait!(waiter_backend)
    refute_receive :waiter_acquired, 200

    send(holder.pid, :commit_refresh_fence)
    assert_receive :waiter_acquired, 5_000

    assert :ok = Task.await(holder, 5_000)
    assert :ok = Task.await(waiter, 5_000)
  end

  test "rejects malformed event ids" do
    assert {:error, :invalid_event_id} =
             EventSnapshotRefreshFence.with_serial_event_refresh("not-a-uuid", fn -> :ok end)
  end

  test "source transaction lock rejects calls outside a transaction" do
    UnboxedPostgres.with_connection(fn ->
      assert {:error, :event_snapshot_refresh_fence_failed} =
               EventSnapshotRefreshFence.lock_events_in_transaction([Ecto.UUID.generate()])
    end)
  end

  test "successful fenced callback releases its transaction lock" do
    event_id = Ecto.UUID.generate()
    assert {:ok, key} = EventSnapshotRefreshFence.lock_key(event_id)

    UnboxedPostgres.with_connection(fn ->
      assert :ok =
               EventSnapshotRefreshFence.with_serial_event_refresh(event_id, fn -> :ok end)

      assert transaction_lock_available?(key)
    end)
  end

  test "raised fenced callback rolls back and releases its transaction lock" do
    event_id = Ecto.UUID.generate()
    assert {:ok, key} = EventSnapshotRefreshFence.lock_key(event_id)

    UnboxedPostgres.with_connection(fn ->
      assert {:error, :event_snapshot_refresh_fence_failed} =
               EventSnapshotRefreshFence.with_serial_event_refresh(event_id, fn ->
                 raise "boom"
               end)

      assert transaction_lock_available?(key)
    end)

    parent = self()

    releaser =
      Task.async(fn ->
        UnboxedPostgres.with_connection(fn ->
          backend = EventSnapshotRefreshFence.connection_backend_pid()
          send(parent, {:releaser_backend, backend})

          EventSnapshotRefreshFence.with_serial_event_refresh(event_id, fn ->
            send(parent, :reacquired)
            :ok
          end)
        end)
      end)

    assert_receive {:releaser_backend, _backend}, 5_000
    assert_receive :reacquired, 5_000
    assert :ok = Task.await(releaser, 5_000)
  end

  test "source transaction lock blocks a refresh fence until source commit" do
    event_id = Ecto.UUID.generate()
    parent = self()

    source =
      Task.async(fn ->
        UnboxedPostgres.with_connection(fn ->
          Repo.transaction(fn ->
            assert :ok = EventSnapshotRefreshFence.lock_events_in_transaction([event_id])
            send(parent, :source_transaction_locked)

            receive do
              :commit_source -> :ok
            after
              15_000 -> Repo.rollback(:source_lock_timeout)
            end
          end)
        end)
      end)

    assert_receive :source_transaction_locked, 5_000

    worker =
      Task.async(fn ->
        UnboxedPostgres.with_connection(fn ->
          backend = EventSnapshotRefreshFence.connection_backend_pid()
          send(parent, {:worker_backend_waiting, backend})

          EventSnapshotRefreshFence.with_serial_event_refresh(event_id, fn ->
            send(parent, :worker_acquired_after_source)
            :ok
          end)
          |> then(&{backend, &1})
        end)
      end)

    assert_receive {:worker_backend_waiting, worker_backend}, 5_000
    EventSnapshotRefreshTestSupport.wait_for_advisory_lock_wait!(worker_backend)
    refute_receive :worker_acquired_after_source, 200

    send(source.pid, :commit_source)
    assert_receive :worker_acquired_after_source, 5_000
    assert {:ok, :ok} = Task.await(source, 5_000)
    assert {_, :ok} = Task.await(worker, 5_000)
  end

  test "refresh transaction fence blocks a source transaction lock until commit" do
    event_id = Ecto.UUID.generate()
    parent = self()

    worker =
      Task.async(fn ->
        UnboxedPostgres.with_connection(fn ->
          EventSnapshotRefreshFence.with_serial_event_refresh(event_id, fn ->
            send(parent, :refresh_transaction_locked)

            receive do
              :commit_refresh -> :ok
            after
              15_000 -> :timeout
            end
          end)
        end)
      end)

    assert_receive :refresh_transaction_locked, 5_000

    source =
      Task.async(fn ->
        UnboxedPostgres.with_connection(fn ->
          Repo.transaction(fn ->
            assert :ok = EventSnapshotRefreshFence.lock_events_in_transaction([event_id])
            send(parent, :source_acquired_after_worker)
            :ok
          end)
        end)
      end)

    refute_receive :source_acquired_after_worker, 200

    send(worker.pid, :commit_refresh)
    assert_receive :source_acquired_after_worker, 5_000
    assert :ok = Task.await(worker, 5_000)
    assert {:ok, :ok} = Task.await(source, 5_000)
  end

  test "different event refresh fences do not block each other" do
    parent = self()
    held_event_id = Ecto.UUID.generate()
    independent_event_id = Ecto.UUID.generate()

    holder =
      Task.async(fn ->
        UnboxedPostgres.with_connection(fn ->
          EventSnapshotRefreshFence.with_serial_event_refresh(held_event_id, fn ->
            send(parent, :first_event_fence_held)

            receive do
              :commit_first_event -> :ok
            after
              15_000 -> Repo.rollback(:first_event_timeout)
            end
          end)
        end)
      end)

    assert_receive :first_event_fence_held, 5_000

    independent =
      Task.async(fn ->
        UnboxedPostgres.with_connection(fn ->
          EventSnapshotRefreshFence.with_serial_event_refresh(independent_event_id, fn ->
            send(parent, :second_event_fence_acquired)
            :ok
          end)
        end)
      end)

    assert_receive :second_event_fence_acquired, 5_000
    assert :ok = Task.await(independent, 5_000)

    send(holder.pid, :commit_first_event)
    assert :ok = Task.await(holder, 5_000)
  end

  test "a timed out lock request returns an error and releases the transaction" do
    event_id = Ecto.UUID.generate()
    parent = self()

    holder =
      Task.async(fn ->
        UnboxedPostgres.with_connection(fn ->
          EventSnapshotRefreshFence.with_serial_event_refresh(event_id, fn ->
            send(parent, :timeout_holder_ready)

            receive do
              :commit_timeout_holder -> :ok
            after
              15_000 -> Repo.rollback(:timeout_holder_expired)
            end
          end)
        end)
      end)

    assert_receive :timeout_holder_ready, 5_000

    waiter =
      Task.async(fn ->
        UnboxedPostgres.with_connection(fn ->
          Repo.query!("SET lock_timeout = '100ms'")
          backend_pid = EventSnapshotRefreshFence.connection_backend_pid()
          send(parent, {:timeout_waiter_backend, backend_pid})

          try do
            EventSnapshotRefreshFence.with_serial_event_refresh(event_id, fn -> :ok end)
          after
            Repo.query!("RESET lock_timeout")
          end
        end)
      end)

    assert_receive {:timeout_waiter_backend, waiter_backend}, 5_000
    EventSnapshotRefreshTestSupport.wait_for_advisory_lock_wait!(waiter_backend)

    assert {:error, :event_snapshot_refresh_fence_failed} = Task.await(waiter, 5_000)

    send(holder.pid, :commit_timeout_holder)
    assert :ok = Task.await(holder, 5_000)
    assert transaction_lock_available?(elem(EventSnapshotRefreshFence.lock_key(event_id), 1))
  end

  defp transaction_lock_available?(key) do
    key
    |> try_transaction_lock()
    |> lock_acquired?()
  end

  defp try_transaction_lock(key) do
    Task.async(fn ->
      UnboxedPostgres.with_connection(fn ->
        Repo.query("SELECT pg_try_advisory_xact_lock($1::bigint)", [key])
      end)
    end)
    |> Task.await(5_000)
  end

  defp lock_acquired?({:ok, %{rows: [[true]]}}), do: true
  defp lock_acquired?(_result), do: false
end
