defmodule Tron.GameServer do
  @moduledoc """
  A GenServer(Generic Server) that manages the game state.
  """
  use GenServer
  require Logger

  alias __MODULE__
  alias Phoenix.PubSub
  alias Tron.GameState
  alias Tron.Player

  def child_spec(opts) do
    name = Keyword.get(opts, :name, GameServer)
    player = Keyword.fetch!(opts, :player)

    %{
      id: "#{GameServer}_#{name}",
      start: {GameServer, :start_link, [name, player]},
      restart: :transient,
      shutdown: 10_000
    }
  end

  def start_link(name, player) do
    case GenServer.start_link(GameServer, %GameState{room: name, players: [player]},
           name: via_tuple(name)
         ) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.info("Already started GameServer #{inspect(name)} at #{inspect(pid)}")
        :ignore
    end
  end

  def generate_room_code() do
    codes = Enum.map(1..5, fn _ -> do_generate_room_code() end)

    case Enum.find(codes, &(!GameServer.room_exists?(&1))) do
      nil ->
        Logger.error("Failed to generate a unique room code")
        {:error, :room_code_generation_failed}

      code ->
        {:ok, code}
    end
  end

  def start_or_join_game(room_code, %Player{} = player) do
    case Horde.DynamicSupervisor.start_child(
           Tron.GameSupervisor,
           {GameServer, [name: room_code, player: player]}
         ) do
      {:ok, _pid} ->
        Logger.info("Started game server #{inspect(room_code)}")
        {:ok, :started}

      :ignore ->
        Logger.info("Game server #{inspect(room_code)} already running. Joining")

        case join_game(room_code, player) do
          :ok -> {:ok, :joined}
          {:error, _reason} = error -> error
        end
    end
  end

  def join_game(room_code, player_name) do
    GenServer.call(via_tuple(room_code), {:join_game, player_name})
  end

  def leave_game(room_code, player_name) do
    GenServer.call(via_tuple(room_code), {:leave_game, player_name})
  end

  def broadcast_game_state(%GameState{} = state) do
    PubSub.broadcast(Tron.PubSub, "game:#{state.room}", {:players, state.players})
    PubSub.broadcast(Tron.PubSub, "game:#{state.room}", {:snakes, state.snakes})
    PubSub.broadcast(Tron.PubSub, "game:#{state.room}", {:food, state.foods})
  end

  def via_tuple(name) do
    {:via, Horde.Registry, {Tron.GameRegistry, name}}
  end

  def do_generate_room_code() do
    range = ?A..?Z |> Enum.to_list() |> Enum.concat(1..9)

    1..9
    |> Enum.map(fn _ -> [Enum.random(range)] |> List.to_string() end)
    |> Enum.join("")
  end

  def room_exists?(room_code) do
    case Horde.Registry.lookup(Tron.GameRegistry, room_code) do
      [] -> false
      [{pid, _} | _] when is_pid(pid) -> true
    end
  end

  def init(state) do
    :timer.send_interval(100, :update)
    {:ok, state}
  end

  def handle_info(:update, state) do
    new_state = GameState.update(state)
    broadcast_game_state(new_state)
    {:noreply, new_state}
  end

  def handle_call({:join_game, player_name}, _from, state) do
    new_player = %Player{name: player_name}
    new_state = %GameState{state | players: state.players ++ [new_player]}
    broadcast_game_state(new_state)
    {:reply, {:ok, new_player}, new_state}
  end

  def handle_call({:leave_game, player_name}, _from, state) do
    new_state = %GameState{
      state
      | players: Enum.reject(state.players, fn player -> player.name == player_name end)
    }

    broadcast_game_state(new_state)
    {:reply, :ok, new_state}
  end
end
