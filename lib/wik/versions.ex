defmodule Wik.Versions do
  use Ash.Domain, otp_app: :wik, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Wik.Versions.Version
  end
end
