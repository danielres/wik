defmodule Wik.Events do
  use Ash.Domain, otp_app: :wik, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Wik.Events.Event
  end
end
