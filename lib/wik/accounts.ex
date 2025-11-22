defmodule Wik.Accounts do
  @moduledoc """
  The Accounts domain manages users, groups, and authentication.

  This domain includes:
  - Users and authentication (via AshAuthentication)
  - Groups that organize users
  - Group membership relationships
  - Authentication tokens

  All resources in this domain are available in the Ash Admin interface.
  """
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
