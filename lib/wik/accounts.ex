defmodule Wik.Accounts do
  use Ash.Domain, otp_app: :wik, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Wik.Accounts.Token
    resource Wik.Accounts.User
    resource Wik.Accounts.Group
    resource Wik.Accounts.GroupUserRelation
  end
end
