defmodule Wik.Page do
  @pages_dir "pages"

  def file_path(slug), do: Path.join(@pages_dir, "#{slug}.md")

  def load(slug) do
    path = file_path(slug)

    if File.exists?(path) do
      {:ok, File.read!(path)}
    else
      :not_found
    end
  end

  def save(slug, content) do
    File.mkdir_p!(@pages_dir)
    File.write!(file_path(slug), content)
  end
end
