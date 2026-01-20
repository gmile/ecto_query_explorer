defmodule Mix.Tasks.Bump do
  @moduledoc """
  Prepares a new release by bumping version, updating changelog, and creating a git tag.

  ## Usage

      mix bump         # 0.1.4 -> 0.1.5 (patch by default)
      mix bump patch   # 0.1.4 -> 0.1.5
      mix bump minor   # 0.1.4 -> 0.2.0
      mix bump major   # 0.1.4 -> 1.0.0

  This task will:
  1. Bump the version in VERSION file
  2. Add a new section to CHANGELOG.md
  3. Commit the changes
  4. Create a git tag

  After running this task, push with tags to trigger the release workflow:

      git push origin main --tags
  """

  use Mix.Task

  @shortdoc "Bump version, update changelog, commit and tag"

  @impl Mix.Task
  def run(args) do
    bump_type = parse_args(args)
    current_version = read_version()
    new_version = bump_version(current_version, bump_type)

    Mix.shell().info("Bumping version: #{current_version} -> #{new_version}")

    write_version(new_version)
    update_changelog(new_version)

    Mix.shell().info("Committing changes...")
    System.cmd("git", ["add", "VERSION", "CHANGELOG.md"])
    System.cmd("git", ["commit", "-m", "Release v#{new_version}"])

    Mix.shell().info("Creating tag v#{new_version}...")
    System.cmd("git", ["tag", "v#{new_version}"])

    Mix.shell().info("""

    Release v#{new_version} prepared!

    Next steps:
      git push origin main --tags
    """)
  end

  defp parse_args([]), do: :patch
  defp parse_args(["patch"]), do: :patch
  defp parse_args(["minor"]), do: :minor
  defp parse_args(["major"]), do: :major

  defp parse_args(_) do
    Mix.raise("Usage: mix bump [patch|minor|major]")
  end

  defp read_version do
    "VERSION"
    |> File.read!()
    |> String.trim()
  end

  defp write_version(version) do
    File.write!("VERSION", version <> "\n")
  end

  defp bump_version(version, bump_type) do
    [major, minor, patch] =
      version
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)

    case bump_type do
      :patch -> "#{major}.#{minor}.#{patch + 1}"
      :minor -> "#{major}.#{minor + 1}.0"
      :major -> "#{major + 1}.0.0"
    end
  end

  defp update_changelog(new_version) do
    changelog = File.read!("CHANGELOG.md")
    today = Date.utc_today() |> Date.to_iso8601()

    new_section = """
    ## [v#{new_version}] - #{today}

    ### Added

    -

    ### Changed

    -

    ### Fixed

    -

    """

    # Insert after the header (first ## line marks the start of versions)
    updated =
      case String.split(changelog, ~r/^## \[v/m, parts: 2) do
        [header, rest] ->
          header <> new_section <> "## [v" <> rest

        [_only_header] ->
          changelog <> "\n" <> new_section
      end

    File.write!("CHANGELOG.md", updated)
  end
end
