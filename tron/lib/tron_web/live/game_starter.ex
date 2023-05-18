defmodule Tron.GameStarter do
  @moduledoc """
  Struct and changeset for starting a game of tron.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__
  alias Tron.GameState
  alias Tron.GameServer

  embedded_schema do
    field :name, :string
    field :game_code, :string
    field :type, Ecto.Enum, values: [:start, :join], default: :start
  end

  @type t :: %GameStarter{
          name: nil | String.t(),
          game_code: nil | String.t(),
          type: :start | :join
        }

  def insert_changeset(attrs) do
    %GameStarter{}
    |> cast(attrs, [:name, :game_code])
    |> validate_required([:name])
    |> validate_length(:name, max: 15)
    |> validate_length(:game_code, is: 9)
    |> uppercase_game_code()
    |> validate_game_code()
    |> compute_type()
  end

  def uppercase_game_code(changeset) do
    case get_field(changeset, :game_code) do
      nil -> changeset
      value -> put_change(changeset, :game_code, String.upcase(value))
    end
  end

  def validate_game_code(changeset) do
    if changeset.errors[:game_code] do
      changeset
    else
      case get_field(changeset, :game_code) do
        nil ->
          changeset

        value ->
          if GameServer.room_exists?(value) do
            changeset
          else
            add_error(changeset, :game_code, "not a running game")
          end
      end
    end
  end

  def compute_type(changeset) do
    case get_field(changeset, :game_code) do
      nil ->
        put_change(changeset, :type, :start)

      _game_code ->
        put_change(changeset, :type, :join)
    end
  end

  @spec get_game_code(t()) :: {:ok, GameState.game_code()} | {:error, String.t()}
  def get_game_code(%GameStarter{type: :join, game_code: code}), do: {:ok, code}

  def get_game_code(%GameStarter{type: :start}) do
    GameServer.generate_room_code()
  end

  @spec create(params :: map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(params) do
    params
    |> insert_changeset()
    |> apply_action(:insert)
  end
end
