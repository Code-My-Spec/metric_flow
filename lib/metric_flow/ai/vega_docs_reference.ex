defmodule MetricFlow.Ai.VegaDocsReference do
  @moduledoc """
  Provides browsable Vega-Lite v5 documentation for the visualization chat agent.

  Docs are stored as markdown files under `priv/knowledge/vega_lite/` mirroring
  the official Vega-Lite docs structure. The agent can:

  - `list/0` or `list/1` — browse the file tree
  - `read/1` — read a specific doc page

  This gives the model progressive disclosure: it can discover what's available,
  then drill into the specific topic it needs.
  """

  @docs_root "priv/knowledge/vega_lite"

  @doc """
  Lists the doc tree at the given path. Returns a formatted string showing
  directories and files, like a file tree.

  ## Examples

      VegaDocsReference.list("")
      # => "📁 mark/ (18 files)\\n📁 encoding/ (12 files)\\n📄 data.md\\n..."

      VegaDocsReference.list("mark")
      # => "📄 bar.md\\n📄 line.md\\n📄 area.md\\n..."
  """
  @spec list(String.t()) :: String.t()
  def list(path \\ "") do
    full_path = Path.join(docs_root(), path)

    if File.dir?(full_path) do
      case File.ls(full_path) do
        {:ok, entries} ->
          entries
          |> Enum.sort()
          |> Enum.map_join("\n", &describe_entry(&1, full_path))

        {:error, _} ->
          "Error: cannot read directory '#{path}'"
      end
    else
      "Error: '#{path}' is not a directory. Use read(\"#{path}\") to read a file."
    end
  end

  @doc """
  Reads a specific doc file and returns its content. Strips YAML frontmatter
  for cleaner output.

  ## Examples

      VegaDocsReference.read("data.md")
      VegaDocsReference.read("mark/bar.md")
  """
  @spec read(String.t()) :: String.t()
  def read(path) do
    full_path = Path.join(docs_root(), path)

    case File.read(full_path) do
      {:ok, content} ->
        content
        |> strip_frontmatter()
        |> String.trim()

      {:error, :enoent} ->
        # Try with .md extension
        md_path = full_path <> ".md"

        case File.read(md_path) do
          {:ok, content} ->
            content |> strip_frontmatter() |> String.trim()

          {:error, _} ->
            "Error: file '#{path}' not found. Use list() to see available files."
        end

      {:error, reason} ->
        "Error reading '#{path}': #{reason}"
    end
  end

  @doc """
  Searches doc files for a keyword. Returns matching file paths and the first
  matching line from each file. Useful for finding the right doc to read.
  """
  @spec search(String.t()) :: String.t()
  def search(query) do
    query_lower = String.downcase(query)

    docs_root()
    |> find_all_md_files()
    |> Enum.flat_map(&search_file(&1, query_lower))
    |> case do
      [] -> "No results for '#{query}'."
      results -> Enum.take(results, 10) |> Enum.join("\n\n")
    end
  end

  defp search_file(path, query_lower) do
    case File.read(path) do
      {:ok, content} -> matching_lines(content, query_lower) |> format_file_matches(path)
      _ -> []
    end
  end

  defp matching_lines(content, query_lower) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> String.contains?(String.downcase(line), query_lower) end)
    |> Enum.take(2)
  end

  defp format_file_matches([], _path), do: []

  defp format_file_matches(lines, path) do
    relative = Path.relative_to(path, docs_root())
    matches = Enum.map_join(lines, "\n", &format_match/1)
    ["#{relative}\n#{matches}"]
  end

  defp describe_entry(entry, full_path) do
    entry_path = Path.join(full_path, entry)

    if File.dir?(entry_path) do
      count = count_files(entry_path)
      "dir: #{entry}/ (#{count} files)"
    else
      "file: #{entry}"
    end
  end

  defp format_match({line, num}) do
    "  L#{num}: #{String.trim(line) |> String.slice(0, 120)}"
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp docs_root do
    Application.app_dir(:metric_flow, @docs_root)
  end

  defp strip_frontmatter(content) do
    case Regex.run(~r/\A---\n.*?\n---\n(.*)/s, content) do
      [_, rest] -> rest
      nil -> content
    end
  end

  defp count_files(dir) do
    case File.ls(dir) do
      {:ok, entries} -> length(entries)
      _ -> 0
    end
  end

  defp find_all_md_files(dir) do
    Path.wildcard(Path.join(dir, "**/*.md"))
  end
end
