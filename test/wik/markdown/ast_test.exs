defmodule Wik.Markdown.AstTest do
  use ExUnit.Case, async: true
  alias Wik.Markdown.Ast

  describe "to_text/1" do
    test "joins plain text nodes" do
      ast = ["hello ", "world"]
      assert Ast.to_text(ast) == "hello world"
    end

    test "strips simple tags" do
      ast = [
        {"p", [], ["This is ", {"em", [], ["important"], %{}}, "."], %{}}
      ]

      assert Ast.to_text(ast) == "This is important."
    end

    test "handles nested tags" do
      ast = [
        {:div, [],
         [
           {"p", [], ["foo"], %{}},
           {"p", [], ["bar"], %{}}
         ], %{}}
      ]

      assert Ast.to_text(ast) == "foobar"
    end

    test "ignores nodes without children" do
      ast = [
        {"img", [{"src", "x"}], [], %{}},
        " after image"
      ]

      assert Ast.to_text(ast) == " after image"
    end

    test "combines multiple sibling nodes" do
      ast = [
        "start ",
        {"strong", [], ["mid"], %{}},
        " end"
      ]

      assert Ast.to_text(ast) == "start mid end"
    end
  end
end
