defmodule Wik.Markdown.Embeds.Page do
  alias Wik.Markdown
  alias Wik.Markdown.Embeds
  alias Wik.Page
  alias Wik.Utils

  def embed(meta, base_path, page_name, node, embedded_pages) do
    {group_slug, _} = Utils.read_base_path(base_path)

    opts_whitelist = ["offset", "head", "section"]
    {_, opts} = Embeds.parse_embed_alt_data(node, opts_whitelist)
    offset = Keyword.get(opts, :offset, 1)
    head? = Keyword.get(opts, :head, "yes")
    section = Keyword.get(opts, :section, nil)
    head? = if head? == "yes", do: true, else: false
    page_slug = Utils.slugify(page_name)

    markdown_unprocessed = Page.load(group_slug, page_slug)

    header_text = get_header_text(markdown_unprocessed, section)
    separator = [{"i", [{"class", "hero-chevron-right size-4"}], [], %{}}]
    maybe_separator = if header_text, do: separator, else: ""

    markdown =
      markdown_unprocessed
      |> extract_section(section)
      |> apply_page_head_removal(head?)
      |> apply_offset_replacement(offset)

    embed_link_text = [{"span", [], [page_name], %{}}]
    embed_icon = [{"i", [{"class", "hero-paper-clip embed-page-icon"}], [], %{}}]

    embed_link = [
      {"a", [{"href", page_slug}, {"class", "embed-page-link"}],
       [embed_icon, embed_link_text, maybe_separator, header_text || ""], %{}}
    ]

    recursive_embed? = page_slug in embedded_pages

    if(recursive_embed?) do
      explanation = [
        {"span", [{"class", "embed-page-blocked-explanation"}],
         ["Embed blocked to prevent an infinite loop."], %{}}
      ]

      class = "embed embed-page embed-page-blocked"
      replacement = {"div", [{"class", class}], [embed_link, explanation], meta}
      {:replace, replacement}
    else
      ast = Markdown.to_ast(markdown, base_path, [page_slug | embedded_pages])
      class = "embed embed-page embed-page-allowed"
      replacement = {"div", [{"class", class}], [embed_link, ast], meta}
      {:replace, replacement}
    end
  end

  def apply_page_head_removal(markdown, head?) do
    markdown = markdown |> String.trim()
    page_head_regex = ~r/^#+ .+/

    if !head? do
      String.replace(markdown, page_head_regex, "")
    else
      markdown
    end
  end

  def apply_offset_replacement(markdown, offset) do
    offset =
      case offset |> to_string() |> Integer.parse() do
        {int, ""} when int >= 0 -> int
        # Default if invalid or negative
        _ -> 1
      end

    case offset do
      0 -> markdown
      _ -> String.replace(markdown, ~r/^#/m, String.duplicate("#", offset + 1))
    end
  end

  def extract_section(markdown, section) when section == nil do
    markdown
  end

  def extract_section(markdown, section) do
    # Step 1: Find the matching header line
    header = find_header(markdown, section)

    # If the header is not found, return the entire markdown
    if header == nil do
      markdown
    else
      # Step 2: Extract the heading level
      level = String.length(String.split(header) |> List.first())

      # Step 3: Extract content after the header
      extract_content(markdown, header, level)
    end
  end

  def find_header(_markdown, section) when section == nil, do: nil

  @doc "Finds the first line that matches the given section name as a header"
  def find_header(markdown, section) do
    markdown
    |> String.split("\n")
    |> Enum.find(fn line ->
      String.match?(line, ~r/^#+\s+.*#{Regex.escape(section)}\s*$/i)
    end)
  end

  def get_header_text(markdown, section) do
    header = find_header(markdown, section)

    if header do
      String.replace(header, ~r/^#+\s+/, "")
    else
      nil
    end
  end

  @doc """
  Extracts content after the found header up to the next header of the same or higher level
  """
  def extract_content(markdown, header, level) do
    lines = String.split(markdown, "\n")

    # Find the index of the header in the list of lines
    start_index = Enum.find_index(lines, fn line -> line == header end)

    # Collect lines from the start index onwards
    Enum.drop(lines, start_index)
    |> Enum.reduce_while([], fn line, acc ->
      # Stop if encountering a header of the same or higher level
      if is_header?(line) and header_level(line) <= level and line != header do
        {:halt, acc}
      else
        {:cont, acc ++ [line]}
      end
    end)
    |> Enum.join("\n")
  end

  defp is_header?(line) do
    String.match?(line, ~r/^#+\s+/)
  end

  @doc "Counts the number of # to determine the header level"
  def header_level(line) do
    line
    |> String.trim()
    |> String.split(~r/\s+/)
    |> hd()
    |> String.length()
  end
end
