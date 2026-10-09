# issue-triager

A one-shot issue triager. Each run takes up to 10 open issues in the
repositories you name, untriaged ones first, checks each against the code on
the default branch, and gives it exactly one verdict:

| Verdict | What it does |
|---|---|
| **Duplicate** | comments with a link to the original, then closes it |
| **Already fixed** | comments with the evidence from the code (file and line, or commit), then closes it |
| **Needs information** | comments with the specific questions, and adds `needs-info` if the repository has it |
| **Valid** | adds one size label and a type label, using only labels the repository already has |

It never closes for age or inactivity, never closes without a comment
carrying the evidence, never edits an issue's text, never assigns anyone,
and never touches a pull request. It works on GitHub (`gh`) and Gitea
(`tea`). The full instruction is [`prompts/triage.md`](prompts/triage.md).
Read it before you run this.

## What you need

| Requirement | Why |
|---|---|
| An agent CLI | The package selects `claude-code`. Any prompt adapter works if you override `harness` (see below). |
| `gh` logged in, for GitHub repositories | It lists labels and issues and comments, labels and closes through `gh`. |
| `tea` logged in, for Gitea repositories | It picks the login whose URL matches each repository's host. |
| `git` | It reads the default branch from a fresh clone. |
| **A size label ladder** in each repository | `size/S` to `size/XL`, `size: small`, or similar. Without one, it triages but does not size, and the summary says so. It never creates labels. |

### Which repositories: `TRIAGE_REPOS`

The one variable the prompt reads. A space-separated list of
`<host>/<owner>/<repo>`:

```sh
TRIAGE_REPOS="github.com/acme/api gitea.example.com/acme/web"
```

A `github.com` host goes through `gh`. Any other host goes through `tea`,
using the login whose URL has that host. When `TRIAGE_REPOS` is unset, it
triages the repository the `workdir` is a clone of (its `origin` remote).

### Credentials

| Variable | Read by | Scope |
|---|---|---|
| `TRIAGE_REPOS` | the prompt | not a secret; see above |
| `GH_TOKEN` | `gh` | Fine-grained PAT on those repositories: **Issues: read & write**, **Contents: read**, **Metadata: read**. Unneeded if `gh auth login` already ran for the harness's user. |
| *(none)* | `tea` | `tea` takes no token from the environment. Run `tea login add` once **as the user the Harness daemon runs as**, with a token that has `read:repository` and `write:issue`. |
| `ANTHROPIC_API_KEY` | `claude` | Only if `claude` is not already logged in for that user. |

Put them in an `env_file`, never in `harness.toml`:

```sh
# ~/.config/harness/issue-triager.env  (chmod 600)
TRIAGE_REPOS=github.com/acme/api gitea.example.com/acme/web
GH_TOKEN=github_pat_...
```

## Install and wire it up

```sh
harness agent stable add stump-wtf https://github.com/stump-wtf/harness-stable.git
harness agent info stump-wtf/issue-triager    # read the manifest and the scan
harness agent install stump-wtf/issue-triager
```

Install writes an `[harness.issue-triager]` table with a `source` line. A
package cannot schedule itself, so add the firing and the environment to that
table:

```toml
[harness.issue-triager]
source   = "stump-wtf/issue-triager@<sha>"        # written by install
schedule = "CRON_TZ=UTC 0 7 * * 1"                # Mondays at 07:00 UTC
workdir  = "~/sweeps/issue-triager"               # scratch space for clones
env_file = "~/.config/harness/issue-triager.env"
timeout  = "45m"                                  # default 1h
# Optional: another adapter or model than the package's.
# harness = "crush"
# model   = "litellm/Qwen3.8-27B"
```

Weekly suits most repositories. Its 10-issue budget means a large backlog
takes several runs, untriaged issues first.

## Check it works

```sh
harness reload
harness describe issue-triager        # values from the package are marked (package)
harness trigger issue-triager --wait  # one run now; exits with its exit code
harness logs issue-triager            # verdicts, labels added, skips, flags
```

## Know before you run it

- **It closes issues.** Only as duplicates or already fixed, and only after a
  comment with the evidence. A merged pull request that says it fixed the
  issue is not enough; it confirms the fix in the code. Point it at one
  repository first and read what it did.
- **It runs no code from issues.** It reads the default branch and does not
  run code, commands or scripts an issue supplies.
- **Untrusted content.** The prompt treats issue text, comments and linked
  pages as data. An issue that tries to steer it is triaged on its merits and
  flagged in the summary.
- **Changing its behavior.** The budget (10 per run), the verdicts and the
  sizing guide live in the prompt. To change them, copy `prompts/triage.md`,
  edit it, and set `prompt_file` on your table. A table that sets any prompt
  key replaces the package's prompt whole.
