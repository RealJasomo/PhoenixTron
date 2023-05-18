defmodule Tron.GameState do
  @moduledoc """
  Model a game state for tron/snake
  """
  alias Tron.Player
  alias Tron.Snake
  alias Tron.Constants
  alias __MODULE__

  defstruct room: nil, players: [], snakes: [], foods: [], state: :waiting, created_at: nil

  @type t :: %GameState{
          room: nil | String.t(),
          players: list(Player.t()),
          snakes: list(Snake.t()),
          state: :waiting | :running | :finished,
          foods: list({integer(), integer()}),
          created_at: nil | DateTime.t()
        }
  def new(room_code, %Player{} = player) do
    %GameState{
      room: room_code,
      players: [player],
      snakes: [],
      state: :waiting,
      created_at: DateTime.utc_now()
    }
  end

  def start(%GameState{} = state) do
    %GameState{
      state
      | state: :running,
        snakes: Enum.map(state.players, fn player -> new_snake(player, state) end),
        foods: update_foods(state)
    }
  end

  def update(%GameState{} = state) do
    snakes =
      state.snakes
      |> Enum.map(&update_snake_protection(&1))

    updated_snake_state =
      snakes
      |> Enum.reduce(state, fn snake, new_state ->
        update_snake_position(snake, new_state)
      end)

    snake_locations = updated_snake_state |> get_snake_tiles()

    dead_snakes =
      updated_snake_state.snakes
      |> Enum.filter(&(wall_collision?(&1) || snake_collision?(snake_locations, &1)))

    alive_snakes =
      updated_snake_state.snakes
      |> Enum.reject(&(wall_collision?(&1) || snake_collision?(snake_locations, &1)))

    updated_food_state =
      updated_snake_state
      |> update_foods()

    new_dead_food =
      dead_snakes
      |> Enum.reduce([], fn snake, acc ->
        acc ++ generate_food_from_dead_snake(snake)
      end)

    %GameState{
      updated_food_state
      | snakes: alive_snakes,
        foods: updated_food_state.foods ++ new_dead_food,
        players:
          updated_food_state.players
          |> Enum.filter(fn player ->
            Enum.find(alive_snakes, nil, fn snake -> snake.user_id == player.id end)
          end)
    }
  end

  def update_foods(%GameState{} = state) do
    number_of_food = state.foods |> length()

    if number_of_food < Constants.game().min_food do
      state
      |> add_food(Constants.game().min_food - number_of_food)
    else
      state
    end
  end

  defp snake_collision?(snake_locations, %Snake{} = snake) do
    head = List.first(snake.pos)

    if snake.protected do
      false
    else
      Map.get(snake_locations, head, 0) > 1
    end
  end

  defp wall_collision?(%Snake{} = snake) do
    {x, y} = List.first(snake.pos)
    x < 0 || x >= Constants.game().width || y < 0 || y >= Constants.game().height
  end

  def add_food(%GameState{} = state, number_of_food) do
    foods = state.foods

    foods =
      Enum.reduce(1..number_of_food, foods, fn _i, foods ->
        foods |> get_available_position(foods) |> List.insert_at(-1, foods)
      end)

    %GameState{state | foods: foods}
  end

  def new_snake(%Player{id: id, color: color}, %GameState{} = state) do
    snake_pos_and_dir = new_snake_pos_and_dir(state)

    %Snake{
      user_id: id,
      pos: snake_pos_and_dir.pos,
      dir: snake_pos_and_dir.dir,
      protected: true,
      color: color,
      created_at: DateTime.utc_now()
    }
  end

  defp new_snake_pos_and_dir(%GameState{} = state) do
    pos =
      state
      |> get_snake_tiles()
      |> get_available_position(state.foods)

    dir = get_best_direction(pos)

    %{
      pos: Enum.map(1..Constants.snake().start_length, fn _ -> pos end),
      dir: dir
    }
  end

  defp get_best_direction({x, _y}) do
    if x < Constants.game().width - x do
      Constants.direction().right
    else
      Constants.direction().left
    end
  end

  defp get_snake_tiles(%GameState{snakes: snakes}) do
    Enum.reduce(snakes, %{}, fn snake, acc ->
      if snake.protected do
        acc
      else
        acc
        |> Map.merge(
          Enum.reduce(snake.pos, acc, fn pos, pos_acc ->
            Map.put(pos_acc, pos, Map.get(pos_acc, pos, 0) + 1)
          end)
        )
      end
    end)
  end

  defp get_available_position(snake_locations, foods) do
    unavailable_positions = snake_locations |> Map.merge(Map.new(foods, fn pos -> {pos, 0} end))

    available_positions =
      Enum.reduce(0..(Constants.game().width - 1), [], fn x, x_acc ->
        Enum.reduce(0..(Constants.game().height - 1), x_acc, fn y, y_acc ->
          if Map.get(unavailable_positions, {x, y}, 0) == 0 do
            [{x, y} | y_acc]
          else
            y_acc
          end
        end)
      end)

    Enum.random(available_positions)
  end

  defp update_snake_protection(%Snake{} = snake) do
    if snake.protected and DateTime.diff(DateTime.utc_now(), snake.created_at) > 5 do
      %Snake{snake | protected: false}
    else
      snake
    end
  end

  defp update_snake_position(%GameState{} = state, %Snake{} = snake) do
    {headx, heady} = List.first(snake.pos)

    new_head_pos =
      cond do
        snake.dir == Constants.direction().up -> {headx, heady - 1}
        snake.dir == Constants.direction().right -> {headx + 1, heady}
        snake.dir == Constants.direction().down -> {headx, heady + 1}
        snake.dir == Constants.direction().left -> {headx - 1, heady}
      end

    food_eaten =
      if snake.protected do
        nil
      else
        Enum.find_index(state.foods, fn {x, y} -> x == headx and y == heady end)
      end

    %GameState{
      state
      | foods:
          if food_eaten != nil do
            state.foods |> List.delete_at(food_eaten)
          else
            state.foods
          end,
        snakes:
          Enum.map(state.snakes, fn s ->
            if s.user_id == snake.user_id do
              %Snake{
                s
                | pos:
                    if food_eaten != nil do
                      [new_head_pos | s.pos]
                    else
                      [new_head_pos | s.pos |> List.delete_at(-1)]
                    end
              }
            else
              s
            end
          end)
    }
  end

  defp generate_food_from_dead_snake(%Snake{} = snake) do
    snake.pos
    |> Stream.with_index(0)
    |> Enum.filter(fn {_, index} -> rem(index, 5) == 1 end)
    |> Enum.map(&elem(&1, 0))
  end
end
