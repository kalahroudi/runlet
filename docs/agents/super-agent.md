# Super-agent operations for RunLet

This page records how the `dsh-super-agent` deployment is wired to this repository and how to start the queue. It is for the owner and for an agent helping with setup; workers should read `AGENTS.md`.

## What is configured

| Setting | Value |
|---|---|
| Profile | `superagent` (DSH Web profile template), panel at `http://127.0.0.1:3082` |
| State directory | `/Users/mohammadramezanian/.dsh/state/superagent` |
| GitHub Source | `kalahroudi/runlet` |
| Agent CLI | `/Users/mohammadramezanian/.local/bin/gh-agent` |
| Base clone for worktrees | `/Users/mohammadramezanian/src/runlet` |
| Executor workers | `maxWorkers: 1` |
| Accept mode | `observe`; only explicit requests from the allowed list start work |
| Allowed askers | `kalahroudi` |
| Queue | GitHub issue #51 |

The prepare command in the panel creates one worktree per ticket:

```sh
git -C /Users/mohammadramezanian/src/runlet fetch --no-tags \
  "https://github.com/$DSH_SUPERAGENT_GITHUB_REPOSITORY.git" \
  "${DSH_SUPERAGENT_GITHUB_PR_HEAD:-HEAD}:refs/dsh-superagent/$DSH_SUPERAGENT_TICKET" &&
git -C /Users/mohammadramezanian/src/runlet worktree add \
  -b "agent/$DSH_SUPERAGENT_NAME" "$DSH_SUPERAGENT_DIR" \
  "refs/dsh-superagent/$DSH_SUPERAGENT_TICKET"
```

The prompts add a RunLet section: one spec per PR, the spec-only phase stops before code, the build PR updates the spec status and criteria and the roadmap row, `swift test` and `./scripts/build.sh` run, and a person merges every PR.

## The one rule that blocks trial mode

The GitHub Source drops every message authored by the agent account. If the agent CLI is signed in as the same account that triggers it, the trigger never becomes a ticket.

This deployment currently uses a trial wrapper that runs the owner's own `gh`, signed in as `@kalahroudi`. That is enough for the setup checks and for opening PRs, but a comment from `@kalahroudi` mentioning `@kalahroudi` is dropped. **A dedicated agent account is required before the queue can start.**

## Switch to a dedicated agent account

The operator does these steps; an agent can prepare the wrapper and update the Source afterwards.

1. Create a GitHub user for the agent (for example `runlet-agent`) and invite it as a collaborator with write access to `kalahroudi/runlet`. Accept the invitation as the agent.
2. Replace the trial wrapper with one that uses a separate config directory:

   ```sh
   mkdir -p ~/.local/bin
   cat > ~/.local/bin/gh-agent <<'EOF'
   #!/bin/sh
   GH_CONFIG_DIR="$HOME/.config/gh-agent" exec gh "$@"
   EOF
   chmod +x ~/.local/bin/gh-agent
   gh-agent auth login
   gh-agent api user --jq .login
   ```

   The last command must print the agent login, not `kalahroudi`.
3. In the Superagent panel, open **Settings → Sources → GitHub** and save the card (or choose **Check again**). Setup checks that the account can push to `kalahroudi/runlet` and restarts the service. `scripts/dsh-superagent status` must exit 0.
4. Confirm no other part reports an error, then follow the trigger protocol below.

## Trigger protocol

1. On the chosen issue, comment from an allowed account and mention the agent:
   `@<agent-login> deliver this issue`.
2. The agent opens a **spec-only PR** and stops. Review it; merge it when the spec is approved.
3. Comment again on the same issue: `@<agent-login> spec NNN is approved, build it`. The agent opens the **build PR**.
4. Merge the build PR, then trigger the next issue from the queue in #51.

Trigger one item at a time. The deployment's `maxWorkers: 1` prevents concurrent Executors, but the spec PR must merge before its build starts, and the previous build should merge before the next spec starts.

## Owner-only items

- #52 tracks the manual checks that close out specs 002, 020, 023 and 029.
- #50 (spec 021) needs the owner's Developer ID, notarization credentials and release secrets. Do not trigger it until spec 020 is Done and those exist.

## Troubleshooting

- `scripts/dsh-superagent status` exits 1: the service is down; restart it with `scripts/dsh-superagent restart`.
- Exit 2: a Source or sync is unhealthy; read `errors` before restarting.
- Exit 3: setup needs something; read `setup` and fix the account or repository field.
- A ticket fails with `The prepare command failed`: check that `/Users/mohammadramezanian/src/runlet` is a clone of the repository and the ref is fetchable.
- For more, see `docs/006-deployment.md` in the dsh-superagent checkout.
