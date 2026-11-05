defmodule EventSales.Analytics.EventSnapshotRefreshFence do
  @moduledoc false

  alias EventSales.Repo

  @namespace "event_sales:analytics_event_snapshot_refresh:"

  @type error_reason :: :invalid_event_id | :event_snapshot_refresh_fence_failed

  @doc false
  @spec with_serial_event_refresh(Ecto.UUID.t() | String.t(), (-> result)) :: result
        when result: var
  def with_serial_event_refresh(event_id, fun) when is_binary(event_id) and is_function(fun, 0) do
    with {:ok, key} <- lock_key(event_id) do
      Repo.transaction(
        fn ->
          set_refresh_transaction_isolation!()
          acquire_refresh_transaction_lock!(key)
          run_refresh_callback!(fun)
        end,
        timeout: 120_000
      )
      |> case do
        {:ok, result} -> result
        {:error, reason} -> {:error, reason}
      end
    end
  rescue
    _error -> {:error, :event_snapshot_refresh_fence_failed}
  catch
    :exit, _reason -> {:error, :event_snapshot_refresh_fence_failed}
    :throw, _value -> {:error, :event_snapshot_refresh_fence_failed}
  end

  @doc false
  @spec validate_refresh_transaction_boundary() ::
          :ok | {:error, :event_snapshot_refresh_fence_failed}
  def validate_refresh_transaction_boundary do
    if Repo.in_transaction?() and not sandbox_test_transaction?() do
      {:error, :event_snapshot_refresh_fence_failed}
    else
      :ok
    end
  end

  @doc false
  @spec coherent_transaction_opts() :: Keyword.t()
  def coherent_transaction_opts do
    if use_repeatable_read_isolation?() do
      [isolation_level: :repeatable_read]
    else
      []
    end
  end

  @doc false
  @spec prepare_coherent_transaction!() :: :ok
  def prepare_coherent_transaction! do
    unless Repo.in_transaction?() do
      raise ArgumentError,
            "prepare_coherent_transaction!/0 requires an open Repo transaction"
    end

    if use_repeatable_read_isolation?() do
      case Repo.query("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ", []) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          raise DBConnection.ConnectionError,
                "failed to set PostgreSQL transaction isolation to repeatable read: #{inspect(reason)}"
      end
    else
      :ok
    end
  end

  @doc false
  @spec lock_events_in_transaction([Ecto.UUID.t() | String.t()]) ::
          :ok | {:error, :invalid_event_id | :event_snapshot_refresh_fence_failed}
  def lock_events_in_transaction(event_ids) when is_list(event_ids) do
    with true <- Repo.in_transaction?(),
         {:ok, canonical_ids} <- canonical_event_ids(event_ids),
         :ok <- acquire_transaction_locks(canonical_ids) do
      :ok
    else
      false -> {:error, :event_snapshot_refresh_fence_failed}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _error -> {:error, :event_snapshot_refresh_fence_failed}
  catch
    :exit, _reason -> {:error, :event_snapshot_refresh_fence_failed}
    :throw, _value -> {:error, :event_snapshot_refresh_fence_failed}
  end

  def lock_events_in_transaction(_event_ids), do: {:error, :invalid_event_id}

  @doc false
  @spec use_repeatable_read_isolation?() :: boolean()
  def use_repeatable_read_isolation? do
    Process.get(:ecto_sandbox_unboxed) == true or
      Repo.config()[:pool] != Ecto.Adapters.SQL.Sandbox
  end

  @doc false
  @spec connection_backend_pid() :: integer()
  def connection_backend_pid do
    %Postgrex.Result{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
    pid
  end

  @doc false
  @spec lock_key(Ecto.UUID.t() | String.t()) :: {:ok, integer()} | {:error, :invalid_event_id}
  def lock_key(event_id) when is_binary(event_id) do
    case Ecto.UUID.cast(event_id) do
      {:ok, canonical_event_id} ->
        <<key::signed-big-integer-size(64), _rest::binary>> =
          :crypto.hash(:sha256, @namespace <> canonical_event_id)

        {:ok, key}

      :error ->
        {:error, :invalid_event_id}
    end
  end

  defp canonical_event_ids(event_ids) do
    Enum.reduce_while(event_ids, {:ok, []}, fn event_id, {:ok, acc} ->
      case Ecto.UUID.cast(event_id) do
        {:ok, canonical_id} -> {:cont, {:ok, [canonical_id | acc]}}
        :error -> {:halt, {:error, :invalid_event_id}}
      end
    end)
    |> case do
      {:ok, ids} -> {:ok, ids |> Enum.uniq() |> Enum.sort()}
      {:error, _reason} = error -> error
    end
  end

  defp acquire_transaction_locks(event_ids) do
    Enum.reduce_while(event_ids, :ok, fn event_id, :ok ->
      with {:ok, key} <- lock_key(event_id),
           {:ok, _result} <- Repo.query("SELECT pg_advisory_xact_lock($1::bigint)", [key]) do
        {:cont, :ok}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      :ok -> :ok
      {:error, _reason} -> {:error, :event_snapshot_refresh_fence_failed}
    end
  end

  defp set_refresh_transaction_isolation! do
    if sandbox_test_transaction?() do
      :ok
    else
      case Repo.query("SET TRANSACTION ISOLATION LEVEL READ COMMITTED", []) do
        {:ok, _result} -> :ok
        {:error, _reason} -> Repo.rollback(:event_snapshot_refresh_fence_failed)
      end
    end
  end

  defp sandbox_test_transaction? do
    Repo.config()[:pool] == Ecto.Adapters.SQL.Sandbox and Repo.in_transaction?() and
      Process.get(:ecto_sandbox_unboxed) != true
  end

  defp acquire_refresh_transaction_lock!(key) do
    case Repo.query("SELECT pg_advisory_xact_lock($1::bigint)", [key]) do
      {:ok, _result} -> :ok
      {:error, _reason} -> Repo.rollback(:event_snapshot_refresh_fence_failed)
    end
  end

  defp run_refresh_callback!(fun) do
    case fun.() do
      {:error, reason} -> Repo.rollback(reason)
      result -> result
    end
  end
end
