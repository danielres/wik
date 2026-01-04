defmodule Wik.Wiki do
  use Ash.Domain, otp_app: :wik, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Wik.Wiki.Page
    resource Wik.Wiki.PageTree
    resource Wik.Wiki.Backlink
  end
end
