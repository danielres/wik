defmodule Utils.Markdown do
  @moduledoc """
  Markdown utilities tailored to Milkdown/markdown-it-anchor behavior.

  Provides heading slug generation, duplicate slug de-duplication, TOC extraction,
  tagged block collection, and header-level normalization.
  """

  @header_regex ~r/^(#+)\s+(.+)$/
  @tag_regex ~r/#([A-Za-z0-9_-]+(?:\/[A-Za-z0-9_-]+)*)/u

  @doc """
  Generates a slug compatible with Milkdown/markdown-it-anchor defaults.

  Steps:
  * trim
  * lowercase
  * keep letters, numbers, whitespace, dash, and `#`; drop everything else
  * collapse whitespace to `-`
  * collapse repeated dashes
  * trim leading/trailing dashes
  """
  @spec generate_milkdown_slug(String.t()) :: String.t()
  def generate_milkdown_slug(string) do
    string
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}\s#-]/u, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
    |> case do
      "" -> "section"
      slug -> slug
    end
  end

  @doc """
  Ensures unique fragments per page: first occurrence uses the base slug,
  subsequent duplicates get suffixed like `-#2`, `-#3` (markdown-it-anchor style).
  """
  @spec dedupe_slug(String.t(), map()) :: {String.t(), map()}
  def dedupe_slug(slug, counts) do
    current = Map.get(counts, slug, 0) + 1
    fragment = if current == 1, do: slug, else: "#{slug}-##{current}"
    {fragment, Map.put(counts, slug, current)}
  end

  @doc """
  Extracts a TOC from lines, returning maps with level, titles, tags, slug, and line index.
  """

  def extract_toc(md) when is_binary(md) do
    md
    |> String.split("\n", trim: false)
    |> extract_toc()
  end

  @spec extract_toc([String.t()]) :: list(map())
  def extract_toc(lines) do
    lines
    |> reject_code_lines()
    |> Enum.reduce([], fn {line, idx}, acc ->
      case Regex.run(@header_regex, line, capture: :all_but_first) do
        [hashes, title] ->
          level = String.length(hashes)
          tags = extract_tags(title)
          clean_title = title |> strip_tags() |> String.trim()
          slug = generate_milkdown_slug(String.trim(title))

          [
            %{
              level: level,
              title: clean_title,
              title_with_tags: String.trim(title),
              slug: slug,
              tags: tags,
              line_index: idx
            }
            | acc
          ]

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Extracts tagged blocks for the given tag. Returns a list of maps with:
  * `:markdown` normalized block markdown
  * `:header_titles_stack` header titles stack
  * `:slug_stack` slug stack (deduped)
  * `:header_text` original header line (with tags)

  Options:
  * `:headings_base_level` (default 1) — heading level to normalize tagged headers to.
  """
  @spec extract_tagged_blocks(String.t(), String.t(), keyword()) :: list(map())
  def extract_tagged_blocks(text, tag_name, opts \\ []) do
    headings_base_level = Keyword.get(opts, :headings_base_level, 1)
    tag_name = String.downcase(tag_name)

    # Fast bailout: if the tag token isn't present at all, skip parsing.
    if text && !String.contains?(String.downcase(text), "#" <> tag_name) do
      []
    else
      lines = String.split(text, "\n", trim: false)
      toc = extract_toc(lines)

      {_titles, _slugs, _counts, blocks} =
        Enum.reduce(Enum.with_index(toc), {[], [], %{}, []}, fn {header, idx},
                                                                {stack_titles, stack_slugs,
                                                                 counts, acc} ->
          stack_titles =
            stack_titles
            |> Enum.take(header.level - 1)
            |> Kernel.++([header.title])

          {unique_slug, counts} = dedupe_slug(header.slug, counts)

          stack_slugs =
            stack_slugs
            |> Enum.take(header.level - 1)
            |> Kernel.++([unique_slug])

          if Enum.any?(header.tags, &(&1 == tag_name)) do
            start_line = header.line_index
            end_line = find_block_end(toc, idx, header.level, length(lines) - 1)
            block_lines = Enum.slice(lines, start_line, end_line - start_line + 1)

            normalized = normalize_header_levels(block_lines, header.level, headings_base_level)

            {stack_titles, stack_slugs, counts,
             [
               %{
                 markdown: normalized,
                 header_titles_stack: stack_titles,
                 slug_stack: stack_slugs,
                 header_text: header.title_with_tags
               }
               | acc
             ]}
          else
            {stack_titles, stack_slugs, counts, acc}
          end
        end)

      Enum.reverse(blocks)
    end
  end

  @doc """
  Finds the end line for a block starting at toc index `idx` with `level`.
  """
  @spec find_block_end(list(map()), non_neg_integer(), pos_integer(), non_neg_integer()) ::
          non_neg_integer()
  def find_block_end(toc, idx, level, last_line) do
    toc
    |> Enum.drop(idx + 1)
    |> Enum.find_value(last_line, fn h ->
      if h.level <= level, do: h.line_index - 1, else: nil
    end)
  end

  @doc """
  Removes tag tokens (e.g., #tag, #tag/subtag) from a title.
  """
  @spec strip_tags(String.t()) :: String.t()
  def strip_tags(title) do
    Regex.replace(@tag_regex, title, "")
  end

  @doc """
  Scans a title for tag names, returning downcased bare names (no leading '#').
  """
  @spec extract_tags(String.t()) :: [String.t()]
  def extract_tags(text) do
    text
    |> String.split("\n", trim: false)
    |> reject_code_lines()
    |> Enum.flat_map(fn {line, _idx} ->
      line
      |> strip_inline_code()
      |> scan_tags()
    end)
  end

  defp scan_tags(text) do
    @tag_regex
    |> Regex.scan(text)
    |> Enum.map(fn [_, t] -> String.downcase(t) end)
  end

  defp strip_inline_code(text) do
    Regex.replace(~r/`+[^`]*`+/, text, "")
  end

  defp reject_code_lines(lines) do
    {filtered, _state} =
      lines
      |> Enum.with_index()
      |> Enum.reduce({[], %{fenced?: false, fence: nil}}, fn {line, idx}, {acc, state} ->
        {state, fence_line?} = update_fence_state(state, line)

        if fence_line? or state.fenced? or indented_code_line?(line) do
          {acc, state}
        else
          {[{line, idx} | acc], state}
        end
      end)

    Enum.reverse(filtered)
  end

  defp indented_code_line?(line) do
    String.match?(line, ~r/^(?:\t| {4,})/)
  end

  defp update_fence_state(%{fenced?: false} = state, line) do
    case Regex.run(~r/^\s{0,3}(`{3,}|~{3,})/, line, capture: :all_but_first) do
      [marker] ->
        fence = {String.at(marker, 0), String.length(marker)}
        {%{state | fenced?: true, fence: fence}, true}

      _ ->
        {state, false}
    end
  end

  defp update_fence_state(%{fenced?: true, fence: {char, len}} = state, line) do
    pattern =
      case char do
        "`" -> ~r/^\s{0,3}`{#{len},}/
        "~" -> ~r/^\s{0,3}~{#{len},}/
      end

    if Regex.match?(pattern, line) do
      {%{state | fenced?: false, fence: nil}, true}
    else
      {state, false}
    end
  end

  @doc """
  Extracts the page title from the first H1 line (`# ...`) in markdown.

  - Strips tag tokens (e.g. `#tag`, `#tag/subtag`)
  - Strips common inline markdown (links/emphasis/code)
  - Returns plain text (or `nil` if not present / empty)
  """
  @spec extract_page_title(String.t() | nil) :: String.t() | nil
  def extract_page_title(text) when is_binary(text) do
    first_line = text |> String.split("\n", parts: 2) |> hd()

    case Regex.run(@header_regex, first_line, capture: :all_but_first) do
      [hashes, title] ->
        if hashes == "#" do
          clean =
            title
            |> strip_tags()
            |> strip_inline_markdown()
            |> String.trim()

          if clean == "", do: nil, else: clean
        else
          nil
        end

      _ ->
        nil
    end
  end

  def extract_page_title(_), do: nil

  defp strip_inline_markdown(title) do
    title
    |> String.replace(~r/!\[([^\]]*)\]\([^)]+\)/, "\\1")
    |> String.replace(~r/\[([^\]]+)\]\([^)]+\)/, "\\1")
    |> String.replace(~r/`([^`]+)`/, "\\1")
    |> String.replace(~r/\*\*([^*]+)\*\*/, "\\1")
    |> String.replace(~r/\*([^*]+)\*/, "\\1")
    |> String.replace(~r/__([^_]+)__/, "\\1")
    |> String.replace(~r/_([^_]+)_/, "\\1")
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/\s+/, " ")
  end

  @doc """
  Normalizes header levels within a block to the target level, preserving relative nesting.
  """
  @spec normalize_header_levels([String.t()], pos_integer(), pos_integer()) :: String.t()
  def normalize_header_levels(block_lines, base_level, headings_base_level) do
    diff = headings_base_level - base_level

    block_lines
    |> Enum.map(fn line ->
      case Regex.run(@header_regex, line, capture: :all_but_first) do
        [hashes, title] ->
          level = String.length(hashes)
          new_level = (level + diff) |> max(1) |> min(6)
          String.duplicate("#", new_level) <> " " <> title

        _ ->
          line
      end
    end)
    |> Enum.join("\n")
  end
end
