defmodule VpsTest do
  use ExUnit.Case
  doctest Vps

  test "greets the world" do
    assert Vps.hello() == :world
  end
end
