defmodule Tron.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      TronWeb.Telemetry,
      # Start the Ecto repository
      Tron.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Tron.PubSub},
      # Start Horde Registry
      {Horde.Registry, keys: :unique, name: Tron.GameRegistry},
      # Start Horde DynamicSupervisor
      {Horde.DynamicSupervisor,
       [
         name: Tron.GameSupervisor,
         shutdown: 1000,
         strategy: :one_for_one,
         members: :auto
       ]},
      # Start Finch
      {Finch, name: Tron.Finch},
      # Start the Endpoint (http/https)
      TronWeb.Endpoint
      # Start a worker by calling: Tron.Worker.start_link(arg)
      # {Tron.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tron.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TronWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
