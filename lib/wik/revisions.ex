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
    Repo.all(
      from(r in Revision,
        order_by: [desc: r.id],
        limit: ^n,
        where: [resource_path: ^resource_path]
      )
    )
  end

  def append(user_id, resource_path, previous_document, new_document)
      when is_binary(resource_path) do
    serialized_patch =
      if previous_document do
        diffs = :diffy.diff(new_document, previous_document)
        patch = :diffy_simple_patch.make_patch(diffs)
        Wik.Revisions.Patch.to_json(patch)
      end

    %Revision{}
    |> Revision.changeset(%{
      resource_path: resource_path,
      user_id: user_id,
      patch: serialized_patch
    })
    |> Repo.insert()
  end
end
