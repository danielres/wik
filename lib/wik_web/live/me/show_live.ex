defmodule WikWeb.Me.ShowLive do
  use WikWeb, :live_view

  @impl true

  def mount(_params, session, socket) do
    superuser? = session["user"].id == Application.get_env(:wik, :superuser_id)

    {:ok,
     socket
     |> assign(:user, session["user"])
     |> assign(superuser?: superuser?), layout: {WikWeb.Layouts, :root}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app_layout>
      <:header_left></:header_left>

      <:header_right>
        <Components.avatar user_photo_url={@user.photo_url} />
      </:header_right>

      <:menu>
        <ul class="flex gap-2 items-center justify-end">
          <li :if={@superuser?}>
            <.link navigate={~p"/admin"} class="btn bg-pink-600 text-white font-bold">
              Admin
            </.link>
          </li>
          <li>
            <.link navigate={~p"/auth/logout"} class="btn btn-primary">
              Logout
            </.link>
          </li>
        </ul>
      </:menu>

      <:main>
        <Layouts.card>
          <div class="grid md:grid-cols-2 gap-x-8 gap-y-8 ">
            <div class="space-y-4 max-w-96 mx-auto w-full">
              <h3 class="text-lg text-slate-500 font-bold text-center ">Your groups</h3>
              <Components.groups_list groups={@user.member_of} />
            </div>

            <hr class="md:hidden" />

            <div class="space-y-4">
              <h3 class="text-lg text-slate-500 font-bold text-center ">User data</h3>
              <div class="grid grid-cols-2 gap-x-4 text-slate-500 space-y-2 items-end [&_b]:text-right">
                <b>Picture:</b>
                <img class="size-10 rounded-full" src={@user.photo_url} alt="user photo" />
                <b>Username:</b>
                <div>{@user.username}</div>
                <b>Firstname:</b>
                <div>{@user.first_name}</div>
                <b>Last name:</b>
                <div>{@user.last_name}</div>
                <b>Auth date:</b>
                <div>{@user.auth_date}</div>
              </div>
            </div>
          </div>
        </Layouts.card>
      </:main>
    </Layouts.app_layout>
    """
  end
end
