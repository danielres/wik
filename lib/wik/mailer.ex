defmodule Wik.Mailer do
  @moduledoc """
  Application mailer for sending emails via Swoosh.

  Configured in config files. In development, emails are sent to
  the local mailbox preview available at `/dev/mailbox`.
  """
  use Swoosh.Mailer, otp_app: :wik
end
