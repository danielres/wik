defmodule WikWeb.OnlineUsersLive do
  use WikWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket), do: WikWeb.Presence.subscribe()
    # Stream users into @streams.presences (does not track, only reads)
    socket = stream(socket, :presences, WikWeb.Presence.list_online_users())
    {:ok, socket}
  end

  def handle_info({WikWeb.Presence, {:join, presence}}, socket) do
    {:noreply, stream_insert(socket, :presences, presence)}
  end

  def handle_info({WikWeb.Presence, {:leave, presence}}, socket) do
    if presence.metas == [] do
      {:noreply, stream_delete(socket, :presences, presence)}
    else
      {:noreply, stream_insert(socket, :presences, presence)}
    end
  end

  def handle_info({WikWeb.Presence, {:update, %{id: id, meta: meta}}}, socket) do
    presence = %{id: id, metas: [meta]}
    {:noreply, stream_insert(socket, :presences, presence)}
  end

  def humanize_path(path) do
    path
    |> String.split("/")
    |> Enum.map(&URI.decode(&1))
    |> Enum.join("/")
    |> remove_path_suffix()
  end

  def remove_path_suffix(path) do
    path |> String.replace("::editing", "")
  end

  def deduplicate_metas(metas) do
    metas
    |> Enum.group_by(&base_path(&1.path))
    |> Enum.flat_map(fn {_base, group} ->
      {editing, non_editing} = Enum.split_with(group, &editing?/1)
      n_replace = min(length(editing), length(non_editing))
      keep_non_editing = Enum.drop(non_editing, n_replace)
      keep_non_editing ++ editing
    end)
  end

  defp base_path(path), do: String.replace_suffix(path, "::editing", "")

  defp editing?(meta), do: String.ends_with?(meta.path, "::editing")

  def render(assigns) do
    ~H"""
    <ul id="online_users" phx-update="stream">
      <li :for={{dom_id, %{id: _id, metas: metas}} <- @streams.presences} id={dom_id}>
        {List.first(metas).username} <sup>{length(deduplicate_metas(metas))}</sup>
        <ul class="pl-4">
          <li :for={meta <- deduplicate_metas(metas)}>
            <.link patch={meta.path |> remove_path_suffix()}>
              {meta.path |> humanize_path()}
            </.link>
            <i :if={editing?(meta)} class="hero-pencil-solid  bg-slate-500 size-4 text-transparent">
              (editing)
            </i>
          </li>
        </ul>
      </li>
    </ul>
    """
  end
end
