defmodule Wik.Tags do
  use Ash.Domain, otp_app: :wik, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Wik.Tags.Tag
    resource Wik.Tags.PageToTag
  end
end
