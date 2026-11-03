defmodule EventSales.Accounts.AuthenticationSigningSecret do
  @moduledoc false

  use AshAuthentication.Secret

  @impl true
  def secret_for(_secret_name, _resource, _opts, _context) do
    case Application.fetch_env(:event_sales, :ash_authentication_token_signing_secret) do
      {:ok, secret} when is_binary(secret) and secret != "" -> {:ok, secret}
      _ -> :error
    end
  end
end
