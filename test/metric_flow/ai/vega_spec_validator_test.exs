defmodule MetricFlow.Ai.VegaSpecValidatorTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Ai.VegaSpecValidator

  describe "validate/1" do
    test "accepts a valid simple spec" do
      spec = %{
        "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
        "data" => %{"name" => "impressions"},
        "mark" => "line",
        "encoding" => %{
          "x" => %{"field" => "date", "type" => "temporal"},
          "y" => %{"field" => "value", "type" => "quantitative"}
        }
      }

      assert {:ok, ^spec} = VegaSpecValidator.validate(spec)
    end

    test "accepts a layered spec" do
      spec = %{
        "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
        "layer" => [
          %{
            "data" => %{"name" => "impressions"},
            "mark" => "line",
            "encoding" => %{
              "x" => %{"field" => "date", "type" => "temporal"},
              "y" => %{"field" => "value", "type" => "quantitative"}
            }
          },
          %{
            "data" => %{"name" => "clicks"},
            "mark" => "line",
            "encoding" => %{
              "x" => %{"field" => "date", "type" => "temporal"},
              "y" => %{"field" => "value", "type" => "quantitative"}
            }
          }
        ]
      }

      assert {:ok, ^spec} = VegaSpecValidator.validate(spec)
    end

    test "rejects a spec with no valid structure" do
      assert {:error, errors} = VegaSpecValidator.validate(%{"foo" => "bar"})
      assert is_list(errors)
      assert length(errors) > 0
    end

    test "rejects non-map input" do
      assert {:error, ["Spec must be a JSON object"]} = VegaSpecValidator.validate("not a map")
    end

    test "accepts a spec with named data source" do
      spec = %{
        "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
        "data" => %{"name" => "metrics"},
        "mark" => %{"type" => "bar"},
        "encoding" => %{
          "x" => %{"field" => "category", "type" => "nominal"},
          "y" => %{"field" => "value", "type" => "quantitative"}
        }
      }

      assert {:ok, _} = VegaSpecValidator.validate(spec)
    end
  end

  describe "valid?/1" do
    test "returns true for valid spec" do
      spec = %{
        "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
        "data" => %{"name" => "test"},
        "mark" => "point",
        "encoding" => %{
          "x" => %{"field" => "x", "type" => "quantitative"},
          "y" => %{"field" => "y", "type" => "quantitative"}
        }
      }

      assert VegaSpecValidator.valid?(spec)
    end

    test "returns false for invalid spec" do
      refute VegaSpecValidator.valid?(%{"garbage" => true})
    end
  end
end
