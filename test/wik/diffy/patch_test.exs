defmodule Wik.Diffy.PatchTest do
  @moduledoc """
  Test module for diffy and the Wik.Diffy.Patch functionality.
  """

  use ExUnit.Case
  @tag timeout: :infinity
  alias FrontMatter
  alias Wik.Diffy.Patch

  require IEx

  @prev """
  Roses are red,
  Violets are blue,
  Sugar is sweet,
  And so are you.
  """

  @next """
  Rases are green,
  Reds are violets
  Violets are blue,
  And so are you.
  Sugar is sweet,
  🤯
  """

  test "diffy" do
    diffs = :diffy.diff(@prev, @next)

    assert diffs == [
             equal: "R",
             delete: "o",
             insert: "a",
             equal: "ses are ",
             insert: "g",
             equal: "re",
             insert: "en,\nRe",
             equal: "d",
             insert: "s are violets",
             delete: ",",
             equal: "\nViolets are blue,\n",
             insert: "And so are you.\n",
             equal: "Sugar is sweet,\n",
             insert: "🤯",
             delete: "And so are you.",
             equal: "\n"
           ]

    html = :diffy.pretty_html(diffs)

    assert html ==
             [
               ["<span>>", "R", "</span>"],
               ["<del style='background:#ffe6e6;'>", "o", "</del>"],
               ["<ins style='background:#e6ffe6;'>", "a", "</ins>"],
               ["<span>>", "ses are ", "</span>"],
               ["<ins style='background:#e6ffe6;'>", "g", "</ins>"],
               ["<span>>", "re", "</span>"],
               ["<ins style='background:#e6ffe6;'>", "en,\nRe", "</ins>"],
               ["<span>>", "d", "</span>"],
               ["<ins style='background:#e6ffe6;'>", "s are violets", "</ins>"],
               ["<del style='background:#ffe6e6;'>", ",", "</del>"],
               ["<span>>", "\nViolets are blue,\n", "</span>"],
               ["<ins style='background:#e6ffe6;'>", "And so are you.\n", "</ins>"],
               ["<span>>", "Sugar is sweet,\n", "</span>"],
               ["<ins style='background:#e6ffe6;'>", "🤯", "</ins>"],
               ["<del style='background:#ffe6e6;'>", "And so are you.", "</del>"],
               ["<span>>", "\n", "</span>"]
             ]

    destination_text = :diffy.destination_text(diffs)

    assert destination_text ==
             "Rases are green,\nReds are violets\nViolets are blue,\nAnd so are you.\nSugar is sweet,\n🤯\n"

    source_text = :diffy.source_text(diffs)

    assert source_text == "Roses are red,\nViolets are blue,\nSugar is sweet,\nAnd so are you.\n"

    patch = :diffy_simple_patch.make_patch(diffs)

    assert patch == [
             copy: 1,
             skip: 1,
             insert: "a",
             copy: 8,
             insert: "g",
             copy: 2,
             insert: "en,\nRe",
             copy: 1,
             insert: "s are violets",
             skip: 1,
             copy: 19,
             insert: "And so are you.\n",
             copy: 16,
             insert: "🤯",
             skip: 15,
             copy: 1
           ]

    serialized = Patch.to_json(patch)

    assert serialized ==
             "[[\"copy\",1],[\"skip\",1],[\"insert\",\"a\"],[\"copy\",8],[\"insert\",\"g\"],[\"copy\",2],[\"insert\",\"en,\\nRe\"],[\"copy\",1],[\"insert\",\"s are violets\"],[\"skip\",1],[\"copy\",19],[\"insert\",\"And so are you.\\n\"],[\"copy\",16],[\"insert\",\"🤯\"],[\"skip\",15],[\"copy\",1]]"

    deserialized = Patch.from_json(serialized)
    assert deserialized == patch
  end
end
