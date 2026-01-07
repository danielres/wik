defmodule Wik.Wiki.PageTree.Markdown do
  @moduledoc """
  Translates between user-facing [[path]] links and stored wikid links.

  This is intentionally used at the DB edge (LiveView load/save only for POC).
  """

  @wikid_regex ~r/\[[^\]]*\]\(wikid:([^\)]+)\)/u

  @spec to_editor(String.t() | nil, map()) :: String.t()
  def to_editor(markdown, tree_by_id \\ %{}) do
    text = markdown || ""

    Regex.replace(@wikid_regex, text, fn full, id ->
      case Map.get(tree_by_id, id) do
        %{path: path} when is_binary(path) and path != "" ->
          "[[#{path}]]"

        _ ->
          full
      end
    end)
  end

  @spec extract_wikilinks(String.t() | nil) :: list(%{target: String.t(), label: String.t()})
  def extract_wikilinks(markdown) do
    text = markdown || ""

    case Earmark.Parser.as_ast(text, wikilinks: true) do
      {:ok, ast, _} -> ast |> collect_wikilinks([]) |> Enum.reverse()
      {:error, ast, _} -> ast |> collect_wikilinks([]) |> Enum.reverse()
      _ -> []
    end
  end

  @spec rewrite_wikilinks(String.t() | nil, map()) :: String.t()
  def rewrite_wikilinks(markdown, path_map) do
    text = markdown || ""
    links = extract_wikilinks(text)

    if links == [] do
      text
    else
      {lines, _links, _state} =
        text
        |> String.split("\n", trim: false)
        |> Enum.reduce({[], links, %{fenced?: false, fence: nil}}, fn line,
                                                                      {acc, pending, state} ->
          {state, fence_line?} = update_fence_state(state, line)

          if fence_line? or state.fenced? or indented_code_line?(line) do
            {[line | acc], pending, state}
          else
            {rewritten, pending} = rewrite_line(line, pending, path_map)
            {[rewritten | acc], pending, state}
          end
        end)

      lines |> Enum.reverse() |> Enum.join("\n")
    end
  end

  defp collect_wikilinks(nodes, acc) when is_list(nodes) do
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

  defp collect_wikilinks(_nodes, acc), do: acc

  defp find_attr(attrs, key) when is_list(attrs) do
    Enum.find_value(attrs, fn
      {^key, value} -> value
      _ -> nil
    end)
  end

  defp find_attr(_attrs, _key), do: nil

  defp extract_text(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&extract_text/1)
    |> IO.iodata_to_binary()
  end

  defp extract_text(text) when is_binary(text), do: text
  defp extract_text({_, _attrs, children, _meta}), do: extract_text(children)
  defp extract_text(_), do: ""

  defp rewrite_line(line, pending, path_map) do
    chars = String.to_charlist(line)
    {out, pending, _inline} = rewrite_chars(chars, pending, path_map, nil, [])
    {IO.iodata_to_binary(Enum.reverse(out)), pending}
  end

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

  defp replace_wikilink(content, pending, path_map) do
    {target, label} = split_wikilink_content(content)
    trimmed_target = String.trim(target)
    trimmed_label = String.trim(label)

    case pending do
      [%{target: expected_target, label: expected_label} | rest] ->
        if trimmed_target == expected_target and match_label?(trimmed_label, expected_label, trimmed_target) do
          {replacement, _} = build_replacement(trimmed_target, trimmed_label, path_map)
          {replacement, rest}
        else
          {"[[#{content}]]", pending}
        end

      _ ->
        {"[[#{content}]]", pending}
    end
  end

  defp match_label?(label, expected_label, target) do
    cond do
      expected_label == "" and label == "" -> true
      expected_label == target and label == "" -> true
      true -> label == expected_label
    end
  end

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

  defp split_wikilink_content(content) do
    case String.split(content, "|", parts: 2) do
      [target, label] -> {target, label}
      [target] -> {target, ""}
      _ -> {content, ""}
    end
  end

  defp take_until_double_close([?], ?] | rest], acc), do: {:ok, acc, rest}

  defp take_until_double_close([char | rest], acc),
    do: take_until_double_close(rest, [char | acc])

  defp take_until_double_close([], _acc), do: :error


  defp take_run(chars, match) do
    do_take_run(chars, match, 0)
  end

  defp do_take_run([char | rest], char, count), do: do_take_run(rest, char, count + 1)
  defp do_take_run(rest, _char, count), do: {count, rest}

  defp indented_code_line?(line) do
    String.starts_with?(line, "\t") or String.starts_with?(line, "    ")
  end

  defp update_fence_state(%{fenced?: false} = state, line) do
    case fence_marker(line) do
      {char, len} -> {%{state | fenced?: true, fence: {char, len}}, true}
      nil -> {state, false}
    end
  end

  defp update_fence_state(%{fenced?: true, fence: {char, len}} = state, line) do
    case fence_marker(line) do
      {^char, new_len} when new_len >= len -> {%{state | fenced?: false, fence: nil}, true}
      _ -> {state, false}
    end
  end

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

  defp count_run(<<char, rest::binary>>, char), do: 1 + count_run(rest, char)
  defp count_run(_, _char), do: 0
end
