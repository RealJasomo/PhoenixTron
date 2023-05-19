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
       positions: %{},
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

  @impl true
  def handle_info(:load_game_state, %{assigns: %{server_found: true}} = socket) do
    case GameServer.get_current_game_state(socket.assigns.game_code) do
      %GameState{} = game ->
        player = GameState.get_player(game, socket.assigns.player_id)
        {:noreply, assign(socket, server_found: true, game: game, player: player)}

      error ->
        Logger.error("Failed to load game server state. #{inspect(error)}")
        {:noreply, assign(socket, :server_found, false)}
    end
  end

  @impl true
  def handle_info(:load_game_state, socket) do
    Logger.debug("Game server #{inspect(socket.assigns.game_code)} not found")
    # Schedule to check again
    Process.send_after(self(), :load_game_state, 500)
    {:noreply, assign(socket, :server_found, GameServer.room_exists?(socket.assigns.game_code))}
  end

  def color_loc(i, j, game) do
    cond do
      Enum.member?(game.foods, {i, j}) ->
        "black"

      Enum.any?(game.snakes, fn snake -> Enum.member?(snake.pos, {i, j}) end) ->
        "##{Enum.find(game.snakes, fn snake -> Enum.member?(snake.pos, {i, j}) end).color}"

      true ->
        "lightgray"
    end
  end
end
