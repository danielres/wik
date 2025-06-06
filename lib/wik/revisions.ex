defmodule Wik.Revisions do
  @moduledoc """
  The Revisions context.
  """
  # use Wik.DataCase
  import Ecto.Query, warn: false
  alias Wik.Repo

  alias Wik.Revisions.Revision

  def count(resource_path) do
    query =
      from(Revision,
        order_by: [desc: :id],
        where: [resource_path: ^resource_path]
      )

    Repo.aggregate(query, :count)
  end

  def take(resource_path, n) do
    cond do
      n > 0 ->
        Repo.all(
          from(r in Revision,
            order_by: [asc: r.id],
            limit: ^n,
            where: [resource_path: ^resource_path]
          )
        )

      n < 0 ->
        take_latest(resource_path, abs(n))
    end
  end

  defp take_latest(resource_path, n) do
    Repo.all(
      from(r in Revision,
        order_by: [desc: r.id],
        limit: ^n,
        where: [resource_path: ^resource_path]
      )
    )
  end

  def append(user_id, resource_path, previous_document \\ "", new_document)
      when is_binary(resource_path) do
    patch_as_json =
      previous_document
      |> Wik.Revisions.Patch.make(new_document)
      |> Wik.Revisions.Patch.to_json()

    %Revision{}
    |> Revision.changeset(%{
      resource_path: resource_path,
      user_id: user_id,
      patch: patch_as_json
    })
    |> Repo.insert()
  end

  # CRUD -----------------

  def list_revisions do
    Repo.all(Revision)
  end

  def get_revision!(id), do: Repo.get!(Revision, id)

  def create_revision(attrs \\ %{}) do
    %Revision{}
    |> Revision.changeset(attrs)
    |> Repo.insert()
  end

  def update_revision(%Revision{} = revision, attrs) do
    revision
    |> Revision.changeset(attrs)
    |> Repo.update()
  end

  def delete_revision(%Revision{} = revision) do
    Repo.delete(revision)
  end

  def change_revision(%Revision{} = revision, attrs \\ %{}) do
    Revision.changeset(revision, attrs)
  end

  def list_revisions_by_resource_path(resource_path) do
    from(r in Revision, where: r.resource_path == ^resource_path)
    |> Repo.all()
    |> Enum.sort(&(&1.id >= &2.id))
  end

  def delete_all_by_resource_path(resource_path) do
    from(r in Revision, where: r.resource_path == ^resource_path)
    |> Repo.delete_all()
  end

  def list_distinct_resource_paths do
    from(r in Revision, distinct: true, select: r.resource_path)
    |> Repo.all()
    |> Enum.sort()
  end
end
