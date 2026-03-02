defmodule WikWeb.UpdatesLive.Index do
  use WikWeb, :live_view

  import Ecto.Query, warn: false

  alias Wik.Groups
  alias Wik.Repo
  alias Wik.Revisions.Revision
  alias Wik.Users.User

  @updates_limit 100

  @impl true
  def mount(%{"group_slug" => group_slug}, session, socket) do
    user = session["user"]
    group_name = Groups.get_group_name(group_slug)

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:group_slug, group_slug)
     |> assign(:group_name, group_name)
     |> assign(:updates_limit, @updates_limit)
     |> assign(:page_title, "Recent updates | #{group_name}")
     |> assign(:updates, [])
     |> assign(:page, 1)
     |> assign(:has_prev, false)
     |> assign(:has_next, false)
     |> assign(:prev_page, 1)
     |> assign(:next_page, 1)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    group_slug = socket.assigns.group_slug
    requested_page = parse_page(params["page"])
    total_updates = count_updates(group_slug)
    total_pages = total_pages(total_updates, @updates_limit)
    page = min(requested_page, total_pages)
    offset = (page - 1) * @updates_limit

    updates = list_recent_updates(group_slug, @updates_limit, offset)

    {:noreply,
     socket
     |> assign(:updates, updates)
     |> assign(:page, page)
     |> assign(:has_prev, page > 1)
     |> assign(:has_next, page < total_pages)
     |> assign(:prev_page, max(page - 1, 1))
     |> assign(:next_page, page + 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app_layout>
      <:header_left>
        <a
          href={~p"/#{@group_slug}"}
          class="flex text-slate-500 hover:text-slate-600"
          style="font-variant: small-caps"
        >
          {@group_name}
        </a>
      </:header_left>

      <:header_right>
        <.link navigate={~p"/me"}>
          <Components.avatar user_photo_url={@user.photo_url} />
        </.link>
      </:header_right>

      <:menu>
        <div class="flex justify-between items-end">
          <Components.shortcut key="b">
            <.link
              id="btn-cancel"
              navigate={~p"/#{@group_slug}/wiki"}
              class="btn text-slate-700 font-bold bg-slate-300"
              title="Go back"
              autofocus
            >
              <i class="hero-arrow-left-mini"></i>
              <span>Back to wiki</span>
            </.link>
          </Components.shortcut>
        </div>
      </:menu>

      <:main>
        <Layouts.card>
          <div class="flex justify-between items-end mb-8">
            <h2 class="text-2xl">Latest updates</h2>

            <%= if !Enum.empty?(@updates) do %>
              <WikWeb.UpdatesLive.Components.pagination
                group_slug={@group_slug}
                page={@page}
                has_prev={@has_prev}
                has_next={@has_next}
                prev_page={@prev_page}
                next_page={@next_page}
              />
            <% end %>
          </div>

          <%= if Enum.empty?(@updates) do %>
            <div class="text-sm">No updates yet.</div>
          <% else %>
            <div class="overflow-x-auto">
              <table id="updates" class="[&_td]:align-top [&_th]:text-left w-full text-sm">
                <thead class="opacity-60">
                  <tr class="[&_th]:whitespace-nowrap [&_th]:pb-5">
                    <th class="">Page title</th>
                    <th class="">Version</th>
                    <th class="">Updated</th>
                    <th class="">By</th>
                    <th class="">Type</th>
                  </tr>
                </thead>
                <tbody class="">
                  <tr :for={update <- @updates} class="">
                    <td class="max-w-64">
                      <.link
                        href={~p"/#{@group_slug}/wiki/#{update.page_slug}"}
                        class="text-blue-600 hover:underline"
                      >
                        {update.page_title}
                      </.link>
                    </td>
                    <td class="">
                      <.link
                        href={
                          ~p"/#{@group_slug}/wiki/#{update.page_slug}/revisions/#{update.revision_number}"
                        }
                        class="text-blue-600 hover:underline"
                      >
                        #{update.revision_number}
                      </.link>
                    </td>
                    <td class="">
                      {update.updated_at |> Utils.Time.relative() |> String.replace(" ago", "")}
                    </td>
                    <td class="">{update.updated_by}</td>
                    <td class={[
                      update.change_type == "created" && "text-green-700",
                      update.change_type == "updated" && "text-gray-400"
                    ]}>
                      {update.change_type}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <%= if !Enum.empty?(@updates) do %>
              <div class="flex justify-end items-end my-8">
                <WikWeb.UpdatesLive.Components.pagination
                  group_slug={@group_slug}
                  page={@page}
                  has_prev={@has_prev}
                  has_next={@has_next}
                  prev_page={@prev_page}
                  next_page={@next_page}
                />
              </div>
            <% end %>
          <% end %>
        </Layouts.card>
      </:main>
    </Layouts.app_layout>
    """
  end

  defp list_recent_updates(group_slug, limit, offset) do
    grouped_revisions_query =
      from(r in Revision,
        where: like(r.resource_path, ^"#{group_slug}/wiki/%"),
        windows: [per_page: [partition_by: r.resource_path, order_by: [asc: r.id]]],
        select: %{
          id: r.id,
          resource_path: r.resource_path,
          user_id: r.user_id,
          inserted_at: r.inserted_at,
          revision_number: over(row_number(), :per_page)
        }
      )

    from(r in subquery(grouped_revisions_query),
      left_join: u in User,
      on: u.id == r.user_id,
      order_by: [desc: r.inserted_at, desc: r.id],
      limit: ^limit,
      offset: ^offset,
      select: %{
        resource_path: r.resource_path,
        revision_number: r.revision_number,
        updated_at: r.inserted_at,
        user_id: r.user_id,
        username: u.username,
        first_name: u.first_name,
        last_name: u.last_name
      }
    )
    |> Repo.all()
    |> Enum.map(&to_update_row(&1, group_slug))
  end

  defp count_updates(group_slug) do
    from(r in Revision, where: like(r.resource_path, ^"#{group_slug}/wiki/%"))
    |> Repo.aggregate(:count)
  end

  defp total_pages(total_updates, _per_page) when total_updates <= 0, do: 1
  defp total_pages(total_updates, per_page), do: div(total_updates + per_page - 1, per_page)

  defp parse_page(nil), do: 1

  defp parse_page(page) do
    case Integer.parse(page) do
      {n, ""} when n > 0 -> n
      _ -> 1
    end
  end

  defp to_update_row(revision, group_slug) do
    page_slug = String.replace_prefix(revision.resource_path, "#{group_slug}/wiki/", "")

    %{
      page_slug: page_slug,
      page_title: page_slug,
      revision_number: revision.revision_number,
      updated_at: revision.updated_at,
      updated_by: updated_by_label(revision),
      change_type: change_type(revision.revision_number)
    }
  end

  defp updated_by_label(%{username: username})
       when is_binary(username) and byte_size(username) > 0 do
    username
  end

  defp updated_by_label(%{first_name: first_name, last_name: last_name, user_id: user_id}) do
    [first_name, last_name]
    |> Enum.filter(&present?/1)
    |> Enum.join(" ")
    |> case do
      "" -> user_id
      full_name -> full_name
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp change_type(1), do: "created"
  defp change_type(_revision_number), do: "updated"
end

defmodule WikWeb.UpdatesLive.Components do
  use WikWeb, :live_view

  def pagination(assigns) do
    ~H"""
    <div class="flex gap-4 w-min whitespace-nowrap border bg-black/5 px-4 py-2">
      <%= if @has_prev do %>
        <.link
          patch={~p"/#{@group_slug}/updates?page=#{@prev_page}"}
          class="text-sm text-blue-600 hover:underline"
        >
          Previous
        </.link>
      <% else %>
        <span class="text-sm text-slate-400">Previous</span>
      <% end %>

      <span class="text-sm text-slate-500">Page {@page}</span>

      <%= if @has_next do %>
        <.link
          patch={~p"/#{@group_slug}/updates?page=#{@next_page}"}
          class="text-sm text-blue-600 hover:underline"
        >
          Next
        </.link>
      <% else %>
        <span class="text-sm text-slate-400">Next</span>
      <% end %>
    </div>
    """
  end
end
