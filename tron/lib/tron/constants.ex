defmodule Tron.Constants do
  @moduledoc """
  Constants for the game.
  """
  @direction %{
    up: 0,
    right: 1,
    down: 2,
    left: 3
  }

  @game %{
    width: 100,
    height: 100,
    min_food: 5
  }

  @snake %{
    start_length: 3
  }

  def direction, do: @direction
  def game, do: @game
  def snake, do: @snake
end
