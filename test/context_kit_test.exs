defmodule ContextKitTest do
  use ExUnit.Case
  doctest ContextKit

  test "greets the world" do
    assert ContextKit.hello() == :world
  end
end
