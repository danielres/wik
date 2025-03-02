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
    groups = assigns[:groups]

    ~H"""
    <ul class="space-y-2  text-center mx-auto">
      <li :for={group <- groups} value={group.id}>
        <a href={~p"/#{group.slug}"} class="btn btn-primary block">
          {group.name}
        </a>
      </li>
    </ul>
    """
  end

  attr(:user_photo_url, :string, required: true)

  def avatar(assigns) do
    ~H"""
    <a href={~p"/me"}>
      <img src={@user_photo_url} alt="user photo" class="w-10 h-10 rounded-full" />
    </a>
    """
  end
end
