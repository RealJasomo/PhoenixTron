defmodule TronWeb.PageLive do
  use TronWeb, :live_view
  import Phoenix.HTML.Form
  alias Tron.Player
  alias Tron.GameServer
  alias Tron.GameStarter

  @impl true
  @spec mount(any, any, map) :: {:ok, map}
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:changeset, GameStarter.insert_changeset(%{}))}
  end

  @impl true
  def handle_event("validate", %{"game_starter" => params}, socket) do
    changeset =
      params
      |> GameStarter.insert_changeset()
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"game_starter" => params}, socket) do
    with {:ok, starter} <- GameStarter.create(params),
         {:ok, game_code} <- GameStarter.get_game_code(starter),
         {:ok, player} <- Player.create(%{name: starter.name}),
         {:ok, _} <- GameServer.start_or_join_game(game_code, player) do
      socket =
        push_redirect(socket,
          to: Routes.play_path(socket, :index, game: game_code, player: player.id)
        )

      {:noreply, socket}
    else
      {:error, reason} when is_binary(reason) ->
        {:noreply, put_flash(socket, :error, reason)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp new_game?(changeset) do
    Ecto.Changeset.get_field(changeset, :type) == :start
  end
end
