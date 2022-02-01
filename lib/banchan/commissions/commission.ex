defmodule Banchan.Commissions.Commission do
  @moduledoc """
  Main module for Commission data.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @status_values [:pending, :accepted, :in_progress, :paused, :waiting, :closed]

  schema "commissions" do
    field :public_id, :string
    field :title, :string
    field :description, :string
    field :tos_ok, :boolean, virtual: true

    field :status, Ecto.Enum,
      values: @status_values,
      default: :pending

    has_many :line_items, Banchan.Commissions.LineItem, preload_order: [asc: :inserted_at]
    has_many :events, Banchan.Commissions.Event, preload_order: [asc: :inserted_at]
    belongs_to :offering, Banchan.Offerings.Offering
    belongs_to :studio, Banchan.Studios.Studio
    belongs_to :client, Banchan.Accounts.User

    timestamps()
  end

  def status_values do
    @status_values
  end

  def gen_public_id do
    random_string(10)
  end

  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end

  @doc false
  def changeset(commission, attrs) do
    commission
    |> cast(attrs, [:title, :description, :tos_ok])
    |> cast_assoc(:line_items)
    |> cast_assoc(:events)
    |> validate_change(:tos_ok, fn field, tos_ok ->
      if tos_ok do
        []
      else
        [{field, "You must agree to the Terms and Conditions"}]
      end
    end)
    |> validate_required([:title, :description, :tos_ok])
  end
end
