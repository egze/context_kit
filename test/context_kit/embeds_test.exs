defmodule ContextKit.EmbedsTest do
  use ExUnit.Case, async: false

  alias ContextKit.Profile
  alias ContextKit.Profiles

  describe "new_{:resource} with embeds" do
    test "creates struct without embeds - no crash with cast_embed" do
      profile = Profiles.new_profile()
      assert %Profile{name: nil, address: nil} = profile
    end

    test "creates struct with regular fields" do
      profile = Profiles.new_profile(%{name: "John"})
      assert %Profile{name: "John", address: nil} = profile
    end

    test "creates struct with embedded data - cast_embed is properly invoked" do
      profile =
        Profiles.new_profile(%{
          name: "John",
          address: %{street: "123 Main St", city: "NYC"}
        })

      assert %Profile{name: "John"} = profile
      assert %{street: "123 Main St", city: "NYC"} = profile.address
    end

    test "respects embedded validations" do
      # Address requires city, so this should still apply the changeset
      # but the resulting struct will have nil for street (not provided)
      profile =
        Profiles.new_profile(%{
          name: "John",
          address: %{city: "NYC"}
        })

      assert %Profile{name: "John"} = profile
      assert %{street: nil, city: "NYC"} = profile.address
    end

    test "handles invalid embed data gracefully" do
      # Even with invalid embed data (missing required city),
      # new_ should not crash - it applies the changeset and returns a struct
      profile =
        Profiles.new_profile(%{
          name: "John",
          address: %{street: "123 Main St"}
        })

      # apply_changes applies the changes even if invalid
      # The embed struct is created with nil for missing required fields
      assert %Profile{name: "John"} = profile
      assert %{street: "123 Main St", city: nil} = profile.address
    end
  end
end
