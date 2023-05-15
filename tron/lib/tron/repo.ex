defmodule Tron.Repo do
  use Ecto.Repo,
    otp_app: :tron,
    adapter: Ecto.Adapters.Postgres
end
