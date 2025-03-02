defmodule WikWeb.Me.ShowLive do
  use WikWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:user, session["user"]), layout: {WikWeb.Layouts, :root}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <WikWeb.Layouts.app_layout>
      <:header_left></:header_left>

      <:header_right>
        <WikWeb.Layouts.avatar user_photo_url={@user.photo_url} />
      </:header_right>

      <:menu>
        <ul class="flex gap-2 items-center justify-end">
          <li>
            <.link navigate={~p"/auth/logout"} class="btn btn-primary float-right">
              Logout
            </.link>
          </li>
        </ul>
      </:menu>

      <:main>
        <WikWeb.Layouts.card variant="card">
          <div class="grid grid-cols-2 gap-x-8 gap-y-2 [&_b]:text-right">
            <div class="space-y-2">
              <h3>Your groups</h3>
              <ul class="space-y-2">
                <li :for={group <- @user.member_of} class="">
                  <a class="btn btn-primary" href={~p"/#{group.slug}"}>{group.name}</a>
                </li>
              </ul>
            </div>
            <div class="grid grid-cols-2 gap-x-4 ">
              <b>Username:</b>
              <div>{@user.username}</div>
              <b>Picture:</b>
              <img class="size-10 rounded-full" src={@user.photo_url} alt="user photo" />
              <b>Firstname:</b>
              <div>{@user.first_name}</div>
              <b>Last name:</b>
              <div>{@user.last_name}</div>
              <b>Auth date:</b>
              <div>{@user.auth_date}</div>
            </div>
          </div>
        </WikWeb.Layouts.card>
      </:main>
    </WikWeb.Layouts.app_layout>
    """
  end
end
