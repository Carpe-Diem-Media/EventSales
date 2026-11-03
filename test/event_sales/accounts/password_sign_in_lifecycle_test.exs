defmodule EventSales.Accounts.PasswordSignInLifecycleTest do
  use EventSales.DataCase, async: true

  alias EventSales.Accounts.Resources.User
  alias EventSales.TestSupport.AuthHelpers

  @password "lifecycle-pass-123"

  test "password sign-in keeps tokens disabled and does not mint JWT metadata" do
    assert AshAuthentication.Info.authentication_tokens_enabled?(User) == false

    AuthHelpers.create_user!("lifecycle@example.com", @password)

    strategy = AshAuthentication.Info.strategy!(User, :password)

    assert {:ok, signed_in} =
             AshAuthentication.Strategy.action(strategy, :sign_in, %{
               email: "lifecycle@example.com",
               password: @password
             }, [])

    refute Map.has_key?(signed_in.__metadata__ || %{}, :token)
    assert signed_in.__metadata__[:authentication_strategies] == [:password]
  end
end
