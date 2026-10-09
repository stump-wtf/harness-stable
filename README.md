# harness-stable

A [Harness](https://github.com/stump-wtf/harness) **stable**: a git repository
of agent packages you can install the way `brew tap` and `brew install` work.
A package is a narrowed, declarative `package.toml` plus its prompt. It picks
an adapter and supplies values. It never carries secrets, a schedule, or
triggers, so installing one never makes anything run on its own.

| Package | What it does |
|---|---|
| [`pr-reviewer`](packages/pr-reviewer/README.md) | Reviews open pull requests that request your review, on GitHub (`gh`) and Gitea (`tea`). One review per PR, backed by evidence. It requests changes, approves or comments, and never merges or pushes. |
| [`issue-triager`](packages/issue-triager/README.md) | Triages open issues: checks each against the code, applies the repository's own size and type labels, and closes only duplicates and already-fixed issues, with the evidence in a comment. |

Both are one-shots. They need a Harness release newer than v0.11.0, the first
to let a package ship its prompt (`prompt_file` in `package.toml`); v0.11.0
refuses that key at install.

Each package's README covers its setup: the forge logins and token scopes it
needs, the environment variables it reads, the account it acts as, and the
harness table to add after install. Read it, and the prompt it points to,
before you install.

## Install

```bash
harness agent stable add stump-wtf https://github.com/stump-wtf/harness-stable.git
harness agent info stump-wtf/pr-reviewer
harness agent install stump-wtf/pr-reviewer
```

`install` scans the package, shows the manifest and asks before it writes a
`source = "stump-wtf/pr-reviewer@<sha>"` line onto a `[harness.pr-reviewer]`
table in your global `harness.toml`.

## Wire it up

The package ships the instruction; your table decides when it runs and as
whom. Add a schedule (or `triggers`) and a working directory next to the
`source` line. Any key you set yourself overrides the package's.

```toml
[harness.pr-reviewer]
source   = "stump-wtf/pr-reviewer@<sha>"
schedule = "CRON_TZ=UTC 30 9 * * *"
workdir  = "~/sweeps/pr-reviewer"
# Optional overrides: run it on another adapter or model.
# harness = "crush"
# model   = "litellm/Qwen3.8-27B"

[harness.issue-triager]
source   = "stump-wtf/issue-triager@<sha>"
schedule = "CRON_TZ=UTC 0 7 * * 1"
workdir  = "~/sweeps/issue-triager"
env_file = "~/.config/harness/issue-triager.env"   # TRIAGE_REPOS=github.com/acme/api …
```

- **Forge access.** Both packages use whichever forge CLIs are logged in on
  the machine: `gh` for GitHub, `tea` for Gitea.
- **Repositories.** `issue-triager` reads its repository list from
  `TRIAGE_REPOS` (space-separated `<host>/<owner>/<repo>`). When that is
  unset, it uses the working directory's `origin`.
- **Prompt overrides.** A prompt you set on the table (`prompt`,
  `prompt_file`, `prompt_template` or `prompt_template_file`) replaces the
  package's prompt.

Upgrade with `harness agent stable update stump-wtf` and then
`harness agent upgrade pr-reviewer`, which shows a diff and rescans before
it moves the pin.

## Contributing a package

Add `packages/<name>/package.toml`, its `prompts/`, and a `README.md` that
documents its setup (credentials, environment variables, and the harness
table to add), then run `make check`.
`stable_test.go` applies Harness's manifest rules and its high-severity
content scan, so a package Harness would refuse fails CI here first.
Issues and pull requests are welcome on the
[GitHub mirror](https://github.com/stump-wtf/harness-stable).

## License

MIT. See [LICENSE](LICENSE).
