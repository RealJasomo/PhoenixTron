defmodule Tron.Player do
  @moduledoc """
  Model a player in a game.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  embedded_schema do
    field :name, :string
    field :color, :string
  end

  @type t :: %Player{
          name: nil | String.t(),
          color: nil | String.t()
        }

  def insert_changeset(attrs) do
    changeset(%Player{}, attrs)
  end

  def changeset(player, attrs) do
    player
    |> cast(attrs, [:name, :color])
    |> generate_color()
    |> validate_required([:name, :color])
    |> generate_id()
  end

  defp generate_id(changeset) do
    case get_field(changeset, :id) do
      nil ->
        put_change(changeset, :id, Ecto.UUID.generate())

      _ ->
        changeset
    end
  end

  defp generate_color(changeset) do
    case get_field(changeset, :color) do
      nil ->
        put_change(changeset, :color, ColorStream.hex() |> Enum.take(1) |> List.first())

      _ ->
        changeset
    end
  end

  def create(params) do
    params
    |> insert_changeset()
    |> apply_action(:insert)
  end
end
