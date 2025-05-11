defmodule Wik.Utils.Href do
  def external?(href) do
    String.starts_with?(href, [
      "http",
      "https",
      "/",
      "//",
      "mailto:",
      "tel:",
      "ftp:",
      "sftp:",
      "git:",
      "file:",
      "data:"
    ])
  end
end
