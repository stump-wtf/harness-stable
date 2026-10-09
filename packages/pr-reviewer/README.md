# pr-reviewer

A one-shot code reviewer. Each run finds open pull requests that request a
review from the account your forge CLI is logged in as, and leaves one
evidence-backed review on each: request changes, approve, or comment. It
reviews at most 5 per run, oldest request first, on GitHub (`gh`) and Gitea
(`tea`).

It never merges, closes, rebases or pushes, never changes labels or
settings, and never approves a pull request its own account opened. Every
review it writes ends with a line saying an automated reviewer wrote it. The
full instruction is [`prompts/review.md`](prompts/review.md). Read it before
you run this.

## What you need

| Requirement | Why |
|---|---|
| An agent CLI | The package selects `claude-code`. Any prompt adapter works if you override `harness` (see below). |
| `gh` logged in, for GitHub | It finds review requests with `gh search prs --review-requested=@me` and posts with `gh pr review`. |
| `tea` logged in, for Gitea | It walks every login in `tea login list`. |
| `git`, `jq` | It clones the change to run its tests. |

A forge with no logged-in CLI is skipped, and the run's summary says so.

### The account it reviews as

**It reviews as whoever `gh` and `tea` are logged in as**, and "requests your
review" means a review request to that account. Give it its own account (a
bot user, or your agent identity) and request reviews from that account.
Running it as yourself makes it review everything assigned to you, and the
"never approve your own pull request" limit then covers your own pull requests.

### Credentials

| Variable | Read by | Scope |
|---|---|---|
| `GH_TOKEN` | `gh` | Fine-grained PAT on the repositories it reviews: **Pull requests: read & write**, **Contents: read**, **Commit statuses: read**, **Checks: read**. Unneeded if `gh auth login` already ran for the harness's user. |
| *(none)* | `tea` | `tea` takes no token from the environment. Run `tea login add` once **as the user the Harness daemon runs as**, with a token that has `read:repository` and `write:repository` (posting a review is a repository write). |
| `ANTHROPIC_API_KEY` | `claude` | Only if `claude` is not already logged in for that user. |

Put them in an `env_file`, never in `harness.toml`:

```sh
# ~/.config/harness/pr-reviewer.env  (chmod 600)
GH_TOKEN=github_pat_...
```

The prompt itself reads no environment variables.

## Install and wire it up

```sh
harness agent stable add stump-wtf https://github.com/stump-wtf/harness-stable.git
harness agent info stump-wtf/pr-reviewer      # read the manifest and the scan
harness agent install stump-wtf/pr-reviewer
```

Install writes a `[harness.pr-reviewer]` table with a `source` line. A
package cannot schedule itself, so add the firing and the environment to that
table:

```toml
[harness.pr-reviewer]
source   = "stump-wtf/pr-reviewer@<sha>"          # written by install
schedule = "CRON_TZ=UTC 30 9 * * *"               # daily at 09:30 UTC
workdir  = "~/sweeps/pr-reviewer"                 # scratch space for clones
env_file = "~/.config/harness/pr-reviewer.env"
timeout  = "45m"                                  # default 1h
# Optional: another adapter or model than the package's.
# harness = "crush"
# model   = "litellm/Qwen3.8-27B"
```

Use `triggers` instead of `schedule` to fire on a review-request webhook. A
review request needs a reviewer within the hour, not the next day, so a
trigger suits it better.

## Check it works

```sh
harness reload
harness describe pr-reviewer        # values from the package are marked (package)
harness trigger pr-reviewer --wait  # one run now; exits with its exit code
harness logs pr-reviewer            # what it reviewed, skipped and flagged
```

## Know before you run it

- **It runs code from the pull requests it reviews.** With `auto_accept`, it
  checks out the head commit and runs the project's documented test and lint
  commands without asking. It reads a script the diff changes before running
  it, and skips anything that pipes a download into a shell, but that is a
  prompt, not a sandbox. Run it as a user, or on a machine, that holds
  nothing beyond this harness's own tokens.
- **Untrusted content.** The prompt treats every title, body, diff, comment
  and log it reads as data. A pull request that tries to steer it gets
  changes requested and is flagged in the summary.
- **Changing its behavior.** The budget (5 per run), the verdict rules and
  the disclosure line live in the prompt. To change them, copy
  `prompts/review.md`, edit it, and set `prompt_file` on your table. A table
  that sets any prompt key replaces the package's prompt whole.
