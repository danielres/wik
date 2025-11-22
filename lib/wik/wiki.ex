defmodule Wik.Wiki do
  @moduledoc """
  The Wiki domain manages wiki pages and content.

  This domain includes:
  - Pages that contain wiki content
  - Version history through event logging
  - Page relationships within groups

  All resources in this domain are available in the Ash Admin interface.
  """
  use Ash.Domain, otp_app: :wik, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Wik.Wiki.Page
  end
end
