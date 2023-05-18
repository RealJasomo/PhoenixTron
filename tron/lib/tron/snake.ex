defmodule Tron.Snake do
  @moduledoc """
  Struct that represents a snake in the game.
  """
  alias __MODULE__

  defstruct user_id: nil, pos: nil, dir: nil, protected: true, color: nil, created_at: nil

  @type t :: %Snake{
          user_id: nil | String.t(),
          pos: nil | list({integer(), integer()}),
          dir: nil | integer(),
          protected: boolean(),
          color: nil | String.t(),
          created_at: nil | DateTime.t()
        }
end
