defmodule Utils.Boolean do
  def parse("true", _default), do: true
  def parse("false", _default), do: false
  def parse(true, _default), do: true
  def parse(false, _default), do: false
  def parse(nil, default), do: default
  def parse(_, default), do: default
end
