defmodule Mix.Tasks.Bump do
  @moduledoc """
  Prepares a new release by bumping version, updating changelog, and creating a git tag.

  ## Usage

      mix bump              # 0.1.4 -> 0.1.5 (patch by default)
      mix bump patch        # 0.1.4 -> 0.1.5
      mix bump minor        # 0.1.4 -> 0.2.0
      mix bump major        # 0.1.4 -> 1.0.0
      mix bump --dry-run    # preview changelog without making changes

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
    {opts, args} = parse_args(args)
    bump_type = parse_bump_type(args)
    current_version = read_version()
    new_version = bump_version(current_version, bump_type)

    changelog_section = build_changelog_section(new_version)

    if opts[:dry_run] do
      Mix.shell().info("Dry run - changelog preview for #{current_version} -> #{new_version}:\n")
      Mix.shell().info(changelog_section)
    else
      Mix.shell().info("Bumping version: #{current_version} -> #{new_version}")

      write_version(new_version)
      update_changelog(changelog_section)

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
  end

  defp parse_args(args) do
    {opts, rest, _} = OptionParser.parse(args, switches: [dry_run: :boolean])
    {opts, rest}
  end

  defp parse_bump_type([]), do: :patch
  defp parse_bump_type(["patch"]), do: :patch
  defp parse_bump_type(["minor"]), do: :minor
  defp parse_bump_type(["major"]), do: :major

  defp parse_bump_type(_) do
    Mix.raise("Usage: mix bump [patch|minor|major] [--dry-run]")
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

  defp build_changelog_section(new_version) do
    today = Date.utc_today() |> Date.to_iso8601()
    {prs, direct_commits} = get_changes_since_last_tag()

    entries =
      case {prs, direct_commits} do
        {[], []} ->
          "- No changes\n"

        _ ->
          pr_entries = Enum.map(prs, fn {number, title} -> "- #{title} (##{number})" end)

          commit_entries =
            Enum.map(direct_commits, fn {sha, message} -> "- #{message} (#{sha})" end)

          Enum.join(pr_entries ++ commit_entries, "\n") <> "\n"
      end

    """
    ## [v#{new_version}] - #{today}

    #{entries}
    """
  end

  defp update_changelog(new_section) do
    changelog = File.read!("CHANGELOG.md")

    updated =
      case String.split(changelog, ~r/^## \[v/m, parts: 2) do
        [header, rest] ->
          header <> new_section <> "## [v" <> rest

        [_only_header] ->
          changelog <> "\n" <> new_section
      end

    File.write!("CHANGELOG.md", updated)
  end

  defp get_changes_since_last_tag do
    range =
      case System.cmd("git", ["describe", "--tags", "--abbrev=0"], stderr_to_stdout: true) do
        {tag, 0} -> "#{String.trim(tag)}..HEAD"
        _ -> "HEAD"
      end

    # Get first-parent commits (commits directly on main)
    {output, 0} = System.cmd("git", ["log", range, "--first-parent", "--format=%H %s"])

    commits = String.split(output, "\n", trim: true)

    {merge_commits, direct_commits} =
      Enum.split_with(commits, &String.contains?(&1, "Merge pull request"))

    prs =
      merge_commits
      |> Enum.map(&parse_pr_number/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&fetch_pr_title/1)

    direct =
      direct_commits
      |> Enum.map(&parse_direct_commit/1)
      |> Enum.reject(&is_nil/1)

    {prs, direct}
  end

  defp parse_pr_number(line) do
    case Regex.run(~r/Merge pull request #(\d+)/, line) do
      [_, number] -> number
      _ -> nil
    end
  end

  defp parse_direct_commit(line) do
    case String.split(line, " ", parts: 2) do
      [sha, message] when byte_size(sha) == 40 ->
        short_sha = String.slice(sha, 0, 7)
        {short_sha, message}

      _ ->
        nil
    end
  end

  defp fetch_pr_title(number) do
    {title, 0} = System.cmd("gh", ["pr", "view", number, "--json", "title", "--jq", ".title"])
    {number, String.trim(title)}
  end
end
