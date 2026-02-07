export const TelegramLoginHook = {
  mounted() {
    if (this.el.dataset.inited === "1") return
    this.el.dataset.inited = "1"

    const bot = this.el.dataset.botUsername
    const req = this.el.dataset.requestAccess || "write"
    const size = this.el.dataset.size || "large"

    const { pathname, search } = window.location
    const returnTo = `${pathname}${search || ""}` // <- path-only
    const authUrl = `/auth/telegram/callback?return_to=${encodeURIComponent(returnTo)}`

    const s = document.createElement("script")
    s.async = true
    s.src = "https://telegram.org/js/telegram-widget.js?22"
    s.dataset.telegramLogin = bot
    s.dataset.authUrl = authUrl
    s.dataset.requestAccess = req
    s.dataset.size = size

    this.el.appendChild(s)
  },
}
