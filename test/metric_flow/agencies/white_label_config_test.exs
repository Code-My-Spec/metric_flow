defmodule MetricFlow.Agencies.WhiteLabelConfigTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.AgenciesFixtures

  alias MetricFlow.Agencies.WhiteLabelConfig
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_attrs(agency_id) do
    %{
      agency_id: agency_id,
      subdomain: "my-agency",
      logo_url: "https://example.com/logo.png",
      primary_color: "#FF5733",
      secondary_color: "#3498DB",
      custom_css: ".header { color: red; }"
    }
  end

  defp new_white_label_config do
    struct!(WhiteLabelConfig, [])
  end

  defp insert_white_label_config!(attrs) do
    new_white_label_config()
    |> WhiteLabelConfig.changeset(attrs)
    |> Repo.insert!()
  end

  defp long_string(length) do
    String.duplicate("a", length)
  end

  defp long_url(length) do
    base = "https://example.com/"
    suffix_length = max(0, length - String.length(base))
    base <> String.duplicate("a", suffix_length)
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      account = account_fixture()
      attrs = valid_attrs(account.id)

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert changeset.valid?
    end

    test "casts agency_id correctly" do
      account = account_fixture()
      attrs = valid_attrs(account.id)

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert get_change(changeset, :agency_id) == account.id
    end

    test "casts subdomain correctly" do
      account = account_fixture()
      attrs = valid_attrs(account.id)

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert get_change(changeset, :subdomain) == "my-agency"
    end

    test "casts logo_url correctly" do
      account = account_fixture()
      attrs = valid_attrs(account.id)

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert get_change(changeset, :logo_url) == "https://example.com/logo.png"
    end

    test "casts primary_color correctly" do
      account = account_fixture()
      attrs = valid_attrs(account.id)

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert get_change(changeset, :primary_color) == "#FF5733"
    end

    test "casts secondary_color correctly" do
      account = account_fixture()
      attrs = valid_attrs(account.id)

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert get_change(changeset, :secondary_color) == "#3498DB"
    end

    test "casts custom_css correctly" do
      account = account_fixture()
      attrs = valid_attrs(account.id)

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert get_change(changeset, :custom_css) == ".header { color: red; }"
    end

    test "validates agency_id is required" do
      account = account_fixture()
      attrs = Map.delete(valid_attrs(account.id), :agency_id)

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{agency_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates subdomain is required" do
      account = account_fixture()
      attrs = Map.delete(valid_attrs(account.id), :subdomain)

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{subdomain: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates subdomain format accepts lowercase letters" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | subdomain: "myagency"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert changeset.valid?
    end

    test "validates subdomain format accepts numbers" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | subdomain: "agency123"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert changeset.valid?
    end

    test "validates subdomain format accepts hyphens" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | subdomain: "my-agency-name"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert changeset.valid?
    end

    test "rejects subdomain with uppercase letters" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | subdomain: "MyAgency"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{subdomain: [_]} = errors_on(changeset)
    end

    test "rejects subdomain with special characters other than hyphens" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | subdomain: "my_agency"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{subdomain: [_]} = errors_on(changeset)
    end

    test "rejects subdomain with spaces" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | subdomain: "my agency"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{subdomain: [_]} = errors_on(changeset)
    end

    test "validates subdomain minimum length of 3 characters" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | subdomain: "ab"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{subdomain: [_]} = errors_on(changeset)
    end

    test "validates subdomain maximum length of 63 characters" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | subdomain: long_string(64)}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{subdomain: [_]} = errors_on(changeset)
    end

    test "validates primary_color is valid hex format (#RRGGBB)" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | primary_color: "#A1B2C3"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert changeset.valid?
    end

    test "rejects primary_color without hash prefix" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | primary_color: "FF5733"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{primary_color: [_]} = errors_on(changeset)
    end

    test "rejects primary_color with invalid length" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | primary_color: "#FFF"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{primary_color: [_]} = errors_on(changeset)
    end

    test "rejects primary_color with non-hex characters" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | primary_color: "#GGHHII"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{primary_color: [_]} = errors_on(changeset)
    end

    test "allows nil primary_color as optional" do
      account = account_fixture()
      attrs = Map.put(valid_attrs(account.id), :primary_color, nil)

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert changeset.valid?
    end

    test "validates secondary_color is valid hex format (#RRGGBB)" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | secondary_color: "#D4E5F6"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert changeset.valid?
    end

    test "rejects secondary_color without hash prefix" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | secondary_color: "3498DB"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{secondary_color: [_]} = errors_on(changeset)
    end

    test "rejects secondary_color with invalid length" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | secondary_color: "#3DB"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{secondary_color: [_]} = errors_on(changeset)
    end

    test "rejects secondary_color with non-hex characters" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | secondary_color: "#XXYYZZ"}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{secondary_color: [_]} = errors_on(changeset)
    end

    test "allows nil secondary_color as optional" do
      account = account_fixture()
      attrs = Map.put(valid_attrs(account.id), :secondary_color, nil)

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert changeset.valid?
    end

    test "validates logo_url maximum length of 500 characters" do
      account = account_fixture()
      attrs = %{valid_attrs(account.id) | logo_url: long_url(501)}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      refute changeset.valid?
      assert %{logo_url: [_]} = errors_on(changeset)
    end

    test "allows nil logo_url as optional" do
      account = account_fixture()
      attrs = Map.put(valid_attrs(account.id), :logo_url, nil)

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert changeset.valid?
    end

    test "allows nil custom_css as optional" do
      account = account_fixture()
      attrs = Map.put(valid_attrs(account.id), :custom_css, nil)

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), attrs)

      assert changeset.valid?
    end

    test "validates agency association exists (assoc_constraint triggers on insert)" do
      attrs = valid_attrs(-1)

      {:error, changeset} =
        new_white_label_config()
        |> WhiteLabelConfig.changeset(attrs)
        |> Repo.insert()

      assert %{agency: ["does not exist"]} = errors_on(changeset)
    end

    test "enforces unique constraint on subdomain" do
      account = account_fixture()
      attrs = valid_attrs(account.id)

      _first = insert_white_label_config!(attrs)

      {:error, changeset} =
        new_white_label_config()
        |> WhiteLabelConfig.changeset(attrs)
        |> Repo.insert()

      assert %{subdomain: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows same subdomain if previous config is deleted" do
      account = account_fixture()
      attrs = valid_attrs(account.id)

      config = insert_white_label_config!(attrs)
      Repo.delete!(config)

      second_account = account_fixture()
      new_attrs = %{attrs | agency_id: second_account.id}

      changeset = WhiteLabelConfig.changeset(new_white_label_config(), new_attrs)

      {:ok, _inserted} =
        new_white_label_config()
        |> WhiteLabelConfig.changeset(new_attrs)
        |> Repo.insert()

      assert changeset.valid?
    end

    test "creates valid changeset for updating existing config" do
      account = account_fixture()
      config = insert_white_label_config!(valid_attrs(account.id))

      new_color = "#123456"
      update_attrs = %{primary_color: new_color}

      changeset = WhiteLabelConfig.changeset(config, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :primary_color) == new_color
    end

    test "preserves existing fields when updating subset of attributes" do
      account = account_fixture()
      config = insert_white_label_config!(valid_attrs(account.id))

      update_attrs = %{primary_color: "#AABBCC"}
      changeset = WhiteLabelConfig.changeset(config, update_attrs)

      assert changeset.data.subdomain == "my-agency"
      assert changeset.data.agency_id == account.id
    end

    test "handles empty attributes map gracefully" do
      account = account_fixture()
      config = insert_white_label_config!(valid_attrs(account.id))

      changeset = WhiteLabelConfig.changeset(config, %{})

      assert changeset.valid?
    end
  end
end
