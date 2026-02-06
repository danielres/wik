defmodule Wik.Wiki.PageTree.Markdown.Utils do
  def collect_wikilinks(nodes, acc) when is_list(nodes) do
    Enum.reduce(nodes, acc, fn node, acc ->
      case node do
        {tag, attrs, children, meta} when is_binary(tag) ->
          acc =
            if tag == "a" and Map.get(meta, :wikilink) == true do
              target = find_attr(attrs, "href") || ""
              label = extract_text(children)
              [%{target: String.trim(target), label: String.trim(label)} | acc]
            else
              acc
            end

          collect_wikilinks(children, acc)

        _ ->
          acc
      end
    end)
  end

  def collect_wikilinks(_nodes, acc), do: acc

  # @doc """
  # Detects whether a line is an indented code block line.
  # Treats tabs or four leading spaces as code indentation.
  # """
  def indented_code_line?(line) do
    String.starts_with?(line, "\t") or String.starts_with?(line, "    ")
  end

  @doc """
  Updates fenced code block state for a single line.
  Returns `{new_state, fence_line?}` where `fence_line?` is true when a fence starts/ends.
  """
  def update_fence_state(%{fenced?: false} = state, line) do
    case fence_marker(line) do
      {char, len} -> {%{state | fenced?: true, fence: {char, len}}, true}
      nil -> {state, false}
    end
  end

  @doc """
  Rewrites wikilinks within a single line of text.
  Returns the rewritten line and the remaining pending link state.
  """
  def rewrite_line(line, pending, path_map) do
    chars = String.to_charlist(line)
    {out, pending, _inline} = rewrite_chars(chars, pending, path_map, nil, [])
    {IO.iodata_to_binary(Enum.reverse(out)), pending}
  end

  @doc """
  Rewrites non-inline-code segments within a line of text.
  Inline code spans are preserved verbatim.
  """
  def rewrite_non_code_segments(line, fun) when is_function(fun, 1) do
    chars = String.to_charlist(line)
    {out, _inline, buffer} = rewrite_non_code_chars(chars, fun, nil, [], [])

    out =
      if buffer == [] do
        out
      else
        [fun.(IO.iodata_to_binary(Enum.reverse(buffer))) | out]
      end

    IO.iodata_to_binary(Enum.reverse(out))
  end

  # @doc """
  # Finds a single attribute value in a list of `{key, value}` pairs.
  # Returns `nil` when the key is not present or attrs are not a list.
  # """
  defp find_attr(attrs, key) when is_list(attrs) do
    Enum.find_value(attrs, fn
      {^key, value} -> value
      _ -> nil
    end)
  end

  defp find_attr(_attrs, _key), do: nil

  # @doc """
  # Extracts plain text from an AST node or list of nodes.
  # Non-text nodes are traversed and collapsed into a string.
  # """
  defp extract_text(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&extract_text/1)
    |> IO.iodata_to_binary()
  end

  defp extract_text(text) when is_binary(text), do: text
  defp extract_text({_, _attrs, children, _meta}), do: extract_text(children)
  defp extract_text(_), do: ""

  # @doc """
  # Scans a line as charlist and rewrites `[[...]]` tokens.
  # Tracks inline code fences to avoid rewriting inside code spans.
  # """
  defp rewrite_chars([], pending, _path_map, inline_len, acc),
    do: {acc, pending, inline_len}

  defp rewrite_chars([?` | rest], pending, path_map, nil, acc) do
    {count, rest} = take_run(rest, ?`)
    tick_len = count + 1
    acc = [String.duplicate("`", tick_len) | acc]
    rewrite_chars(rest, pending, path_map, tick_len, acc)
  end

  defp rewrite_chars([?` | rest], pending, path_map, inline_len, acc)
       when is_integer(inline_len) do
    {count, rest} = take_run(rest, ?`)
    tick_len = count + 1
    acc = [String.duplicate("`", tick_len) | acc]
    inline_len = if tick_len == inline_len, do: nil, else: inline_len
    rewrite_chars(rest, pending, path_map, inline_len, acc)
  end

  defp rewrite_chars([?[, ?[ | rest], pending, path_map, nil, acc) do
    case take_until_double_close(rest, []) do
      {:ok, content_chars, rest} ->
        content = content_chars |> Enum.reverse() |> to_string()
        {replacement, pending} = replace_wikilink(content, pending, path_map)
        rewrite_chars(rest, pending, path_map, nil, [replacement | acc])

      :error ->
        rewrite_chars(rest, pending, path_map, nil, ["[[" | acc])
    end
  end

  defp rewrite_chars([char | rest], pending, path_map, inline_len, acc) do
    rewrite_chars(rest, pending, path_map, inline_len, [<<char::utf8>> | acc])
  end

  defp rewrite_non_code_chars([], _fun, inline_len, out, buffer),
    do: {out, inline_len, buffer}

  defp rewrite_non_code_chars([?` | rest], fun, nil, out, buffer) do
    {count, rest} = take_run(rest, ?`)
    tick_len = count + 1

    out =
      if buffer == [] do
        out
      else
        [fun.(IO.iodata_to_binary(Enum.reverse(buffer))) | out]
      end

    out = [String.duplicate("`", tick_len) | out]
    rewrite_non_code_chars(rest, fun, tick_len, out, [])
  end

  defp rewrite_non_code_chars([?` | rest], fun, inline_len, out, buffer)
       when is_integer(inline_len) do
    {count, rest} = take_run(rest, ?`)
    tick_len = count + 1
    out = [String.duplicate("`", tick_len) | out]
    inline_len = if tick_len == inline_len, do: nil, else: inline_len
    rewrite_non_code_chars(rest, fun, inline_len, out, buffer)
  end

  defp rewrite_non_code_chars([char | rest], fun, nil, out, buffer) do
    rewrite_non_code_chars(rest, fun, nil, out, [<<char::utf8>> | buffer])
  end

  defp rewrite_non_code_chars([char | rest], fun, inline_len, out, buffer)
       when is_integer(inline_len) do
    rewrite_non_code_chars(rest, fun, inline_len, [<<char::utf8>> | out], buffer)
  end

  # @doc """
  # Replaces a `[[...]]` token when it matches the next pending wikilink.
  # Falls back to the original token when it does not match.
  # """
  defp replace_wikilink(content, pending, path_map) do
    {target, label} = split_wikilink_content(content)
    trimmed_target = String.trim(target)
    trimmed_label = String.trim(label)

    case pending do
      [%{target: expected_target, label: expected_label} | rest] ->
        if trimmed_target == expected_target and
             match_label?(trimmed_label, expected_label, trimmed_target) do
          {replacement, _} = build_replacement(trimmed_target, trimmed_label, path_map)
          {replacement, rest}
        else
          {"[[#{content}]]", pending}
        end

      _ ->
        {"[[#{content}]]", pending}
    end
  end

  # @doc """
  # Checks whether the label matches the expected wikilink label rules.
  # Allows empty labels or labels equal to the target when expected label is empty.
  # """
  defp match_label?(label, expected_label, target) do
    cond do
      expected_label == "" and label == "" -> true
      expected_label == target and label == "" -> true
      true -> label == expected_label
    end
  end

  # @doc """
  # Builds a `[label](wikid:id)` replacement from a target path.
  # Returns the original `[[...]]` text when the target cannot be resolved.
  # """
  defp build_replacement(target, label, path_map) do
    case Wik.Wiki.PageTree.Utils.normalize_path(target) do
      {:ok, normalized, _title} ->
        case Map.get(path_map, normalized) do
          %{id: id} when is_binary(id) and id != "" ->
            display = if label == "", do: normalized, else: label
            {"[#{display}](wikid:#{id})", normalized}

          _ ->
            {"[[#{target}]]", target}
        end

      _ ->
        {"[[#{target}]]", target}
    end
  end

  # @doc """
  # Splits wikilink content into target and label parts.
  # Supports `target|label` and defaults the label to empty.
  # """
  defp split_wikilink_content(content) do
    case String.split(content, "|", parts: 2) do
      [target, label] -> {target, label}
      [target] -> {target, ""}
      _ -> {content, ""}
    end
  end

  # @doc """
  # Consumes characters until a closing `]]` is found.
  # Returns `{:ok, content, rest}` or `:error` if no closing is found.
  # """
  defp take_until_double_close([?], ?] | rest], acc), do: {:ok, acc, rest}

  defp take_until_double_close([char | rest], acc),
    do: take_until_double_close(rest, [char | acc])

  defp take_until_double_close([], _acc), do: :error

  # @doc """
  # Consumes a run of the same character from a charlist.
  # Returns `{count, rest}` where count does not include the first matched char.
  # """
  defp take_run(chars, match) do
    do_take_run(chars, match, 0)
  end

  # @doc """
  # Recursive worker for counting run length.
  # Accumulates the run length and returns the remaining list.
  # """
  defp do_take_run([char | rest], char, count), do: do_take_run(rest, char, count + 1)
  defp do_take_run(rest, _char, count), do: {count, rest}

  # @doc """
  # Updates fenced code block state when already inside a fence.
  # Ends the fence only if the closing marker is at least the opening length.
  # """
  def update_fence_state(%{fenced?: true, fence: {char, len}} = state, line) do
    case fence_marker(line) do
      {^char, new_len} when new_len >= len -> {%{state | fenced?: false, fence: nil}, true}
      _ -> {state, false}
    end
  end

  # @doc """
  # Detects a fenced code marker (` ``` ` or ` ~~~ `) and its length.
  # Returns `{char, len}` or `nil` if the line is not a fence.
  # """
  defp fence_marker(line) do
    trimmed = String.trim_leading(line)

    case trimmed do
      <<"`", _::binary>> ->
        len = count_run(trimmed, ?`)
        if len >= 3, do: {?`, len}, else: nil

      <<"~", _::binary>> ->
        len = count_run(trimmed, ?~)
        if len >= 3, do: {?~, len}, else: nil

      _ ->
        nil
    end
  end

  # @doc """
  # Counts the length of a repeated character run at the start of a string.
  # Used to measure fence marker length for code blocks.
  # """
  defp count_run(<<char, rest::binary>>, char), do: 1 + count_run(rest, char)
  defp count_run(_, _char), do: 0
end
