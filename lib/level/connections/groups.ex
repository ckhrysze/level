defmodule Level.Connections.Groups do
  @moduledoc """
  A paginated connection for fetching groups within the authenticated user's space.
  """

  import Ecto.Query

  alias Level.Groups
  alias Level.Pagination
  alias Level.Pagination.Args
  alias Level.Repo

  defstruct first: nil,
            last: nil,
            before: nil,
            after: nil,
            state: "OPEN",
            order_by: %{
              field: :name,
              direction: :asc
            }

  @type t :: %__MODULE__{
          first: integer() | nil,
          last: integer() | nil,
          before: String.t() | nil,
          after: String.t() | nil,
          state: String.t(),
          order_by: %{field: :name, direction: :asc | :desc}
        }

  @doc """
  Executes a paginated query for groups belonging to a given space.
  """
  def get(_space, args, %{context: %{current_user: user}} = _context) do
    base_query =
      user
      |> Groups.list_groups_query()
      |> where(state: ^args.state)

    Pagination.fetch_result(Repo, base_query, Args.build(args))
  end
end
