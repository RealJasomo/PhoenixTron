defmodule TronWeb.PlayLive do
  use TronWeb, :live_view
  require Logger
  alias Phoenix.PubSub
  alias Tron.GameState
  alias Tron.GameServer

  @impl true
  def mount(%{"game" => game_code, "player" => player_id} = _params, _session, socket) do
    if connected?(socket) do
      # Subscribe to game update notifications
      PubSub.subscribe(Tron.PubSub, "game:#{game_code}")
      send(self(), :load_game_state)
    end

    {:ok,
     assign(socket,
       game_code: game_code,
       player_id: player_id,
       player: nil,
       game: %GameState{},
       server_found: GameServer.room_exists?(game_code)
     )}
  end

  def mount(_params, _session, socket) do
    {:ok, push_redirect(socket, to: Routes.page_path(socket, :index))}
  end

  @impl true
  def handle_info({:game_state, %GameState{} = state} = _event, socket) do
    updated_socket =
      socket
      |> clear_flash()
      |> assign(:game, state)

    {:noreply, updated_socket}
  end
end
