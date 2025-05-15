defmodule WikWeb.Components do
  @moduledoc """
  Components for the WikWeb application.
  """
  use Phoenix.Component
  use WikWeb, :live_view

  attr :key, :string, required: true
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def shortcut(assigns) do
    ~H"""
    <div
      class={ "relative #{@class}" }
      id={ "shortcut-#{@key}" }
      phx-hook="ShortcutComponent"
      phx-hook-shortcut-key={@key}
    >
      {render_slot(@inner_block)}

      <span class="hint
        hidden
        absolute -top-2 -left-2
        flex items-baseline
        px-[0.5em] gap-[0.125em]
        rounded shadow-sm
        text-xs leading-none text-nowrap
        bg-emerald-200 text-emerald-800
      ">
        <span>Alt</span>
        <span>+</span>
        <b class="text-sm">{@key}</b>
      </span>
    </div>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def prose(assigns) do
    ~H"""
    <div class="prose
                prose-sm
                max-w-none
                prose-a:text-blue-600
                prose-a:no-underline
                hover:prose-a:underline
                prose-headings:text-slate-600
                text-pretty
                prose-headings:text-balance
                [&_strong]:text-slate-600
                [&_h1]:text-2xl [&_h1]:font-normal
                [&_h2]:text-xl [&_h2]:font-normal
                [&_h2]:border-b [&_h2]:border-slate-500/40
                [&_h2]:leading-snug [&_h2]:pb-2
                [&_h3]:text-lg [&_h3]:font-normal
                [&_h4]:text-base
                [&_h5]:text-sm
                [&_h6]:text-xs
                [&_pre]:whitespace-pre-wrap
            ">
      {render_slot(@inner_block)}
    </div>
    """
  end

  def telegram_login_widget(assigns) do
    ~H"""
    <script
      async
      src="https://telegram.org/js/telegram-widget.js?22"
      data-telegram-login={Application.get_env(:wik, :bot_username)}
      data-size="large"
      data-radius="3"
      data-auth-url="/auth/telegram/callback"
    >
    </script>
    """
  end

  attr :groups, :list, required: true

  def groups_list(assigns) do
    ~H"""
    <%= if Enum.empty?(@groups) do %>
      <div class="space-y-4 bg-slate-100 rounded-lg p-6 text-slate-700">
        <p>Ooops... can't see your groups?</p>
        <p class="text-sm text-slate-500">
          Telegram's auth sometimes works in mysterious ways, but there is an easy fix:
        </p>
        <ol class="list-decimal list-inside text-sm">
          <li>
            <span>Send a PM to</span>
            <a
              class="text-blue-600 hover:underline"
              href={"https://t.me/" <> Application.get_env(:wik, :bot_username)}
            >
              @{Application.get_env(:wik, :bot_username)}
            </a>
          </li>
          <li>
            <.link navigate={~p"/auth/logout"} class="text-blue-600 hover:underline">Logout</.link>
          </li>
          <li>
            Login
          </li>
        </ol>
      </div>
    <% else %>
      <ul class="space-y-2 text-center mx-auto">
        <li :for={group <- @groups} value={group.id}>
          <a href={~p"/#{group.slug}"} class="btn btn-primary block">
            {group.name}
          </a>
        </li>
      </ul>
    <% end %>
    """
  end

  attr(:user_photo_url, :string, required: true)

  def avatar(assigns) do
    ~H"""
    <a href={~p"/me"}>
      <%= if(@user_photo_url) do %>
        <img src={@user_photo_url} alt="user photo" class="w-10 h-10 rounded-full" />
      <% else %>
        <i class="hero-user-solid text-slate-600"></i>
      <% end %>
    </a>
    """
  end

  attr :class, :string, default: ""
  attr :rest, :global

  def toggle_source_button(assigns) do
    ~H"""
    <Components.shortcut key="v">
      <button
        title="Toggle source"
        class={ "text-slate-500 hover:text-slate-600 rounded p-1.5 focus:outline-none bg-white shadow-md #{@class}" }
        phx-click={
          @rest[:"phx-click"]
          |> JS.toggle_class("shadow-md")
          |> JS.toggle_class("shadow-inner")
          |> JS.toggle_class("bg-white")
          |> JS.toggle_class("bg-slate-300")
        }
        {@rest}
      >
        <i class="hero-hashtag">
          Show source
        </i>
      </button>
    </Components.shortcut>
    """
  end

  attr(:group_slug, :string, required: true)
  attr(:backlinks_slugs, :list, default: [])
  attr :class, :string, default: ""

  def backlinks_list(assigns) do
    ~H"""
    <ul class={"text-sm #{@class}"}>
      <%= for slug <- @backlinks_slugs do %>
        <li>
          <a
            class="text-blue-600 hover:underline opacity-75 hover:opacity-100 leading-none block"
            href={~p"/#{@group_slug}/wiki/#{slug}"}
          >
            {slug}
          </a>
        </li>
      <% end %>
    </ul>
    """
  end

  attr(:group_slug, :string, required: true)
  attr(:backlinks_slugs, :list, default: [])
  attr(:class, :string, default: nil)
  attr :rest, :global

  def backlinks_widget(assigns) do
    assigns =
      assigns
      |> assign(
        :class,
        """
        w-48 overflow-hidden
        p-6
        bg-white shadow
        rounded absolute left-[-9999px] sm:static
        #{assigns.class}
        """
      )

    ~H"""
    <div :if={length(@backlinks_slugs) > 0} class={@class} {@rest}>
      <h2 class="text-sm font-semibold text-slate-500">Backlinks</h2>

      <Components.backlinks_list
        class="inline-flex flex-wrap gap-y-2 gap-x-4"
        group_slug={@group_slug}
        backlinks_slugs={@backlinks_slugs}
      />
    </div>
    """
  end
end
