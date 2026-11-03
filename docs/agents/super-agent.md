# Super-agent operations for RunLet

This page records how the `dsh-super-agent` deployment is wired to this repository and how to start the queue. It is for the owner and for an agent helping with setup; workers should read `AGENTS.md`.

## What is configured

| Setting | Value |
|---|---|
| Profile | `superagent` (DSH Web profile template), panel at `http://127.0.0.1:3082` |
| State directory | `/Users/mohammadramezanian/.dsh/state/superagent` |
| GitHub Source | `kalahroudi/runlet` |
| Agent CLI | `/Users/mohammadramezanian/.local/bin/gh-agent` |
| Agent account | `kalahroudi-agent` once the switch is complete; the trial wrapper uses `@kalahroudi` until then |
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

## One-command setup

`scripts/setup-agent-account.sh` walks the whole sequence and pauses at the two browser gates (signup, collaborator invite). After those, it:

- signs the CLI in under `~/.config/gh-agent`;
- checks that it acts as `kalahroudi-agent` and can push to `kalahroudi/runlet`;
- replaces the trial wrapper, keeping the old one as `gh-agent.trial.bak`;
- with `--activate`, saves the GitHub Source, waits for setup to resolve the agent account, runs `scripts/dsh-superagent status`, and posts the first trigger on issue #36.

```sh
./scripts/setup-agent-account.sh --activate
```

Use `--check` to report the current wrapper, dedicated login and Source account without changing anything. Without `--activate`, the script stops after the wrapper and leaves the Source save and trigger to the agent.

The manual steps below are the same sequence, for when something needs to be done by hand.

## The one rule that blocks trial mode

The GitHub Source drops every message authored by the agent account. If the agent CLI is signed in as the same account that triggers it, the trigger never becomes a ticket.

This deployment currently uses a trial wrapper that runs the owner's own `gh`, signed in as `@kalahroudi`. That is enough for the setup checks and for opening PRs, but a comment from `@kalahroudi` mentioning `@kalahroudi` is dropped.

**Minimum to start:** a GitHub account that is not the agent account must send the trigger. The agent may still act as `@kalahroudi`, but every PR and comment is then attributed to the owner.

**Recommended:** a dedicated agent account, so the agent's work is visibly its own. The steps are below.

### Trial-mode workaround

1. Use or create a second GitHub account. The repository is public, so it needs no collaborator access to open an issue or comment; it only needs to be on the Policy's GitHub allowed list.
2. Add its login under **Settings → Policy → GitHub → allowed**.
3. From that account, comment on the chosen issue mentioning the agent: `@kalahroudi deliver this issue`.
4. The agent acts as `@kalahroudi`: its commits, PRs and comments appear under the owner's name. Use this only to try the flow; switch to a dedicated agent account before relying on attribution.

## Switch to a dedicated agent account

Recommended account: **`kalahroudi-agent`** (available on GitHub, not tied to one repository, so it can serve other projects later). The operator does the account steps; an agent can prepare the wrapper and update the Source afterwards.

1. Create the GitHub user `kalahroudi-agent` at <https://github.com/signup> with an email you control. Verify the email and enable 2FA. It is a normal user account, not a GitHub App; super-agent reads its notifications.
2. Invite `kalahroudi-agent` to `kalahroudi/runlet` with **Write** access (repo → Settings → Collaborators → Add people). Accept the invitation while signed in as the agent.
3. Sign the CLI in under a separate config directory *before* replacing the trial wrapper, so the running service keeps working until the new account is ready:

   ```sh
   mkdir -p ~/.config/gh-agent
   chmod 700 ~/.config/gh-agent
   GH_CONFIG_DIR="$HOME/.config/gh-agent" gh auth login
   GH_CONFIG_DIR="$HOME/.config/gh-agent" gh api user --jq .login
   ```

   The last command must print `kalahroudi-agent`, not `kalahroudi`.
4. Replace the trial wrapper with one that uses that config directory:

   ```sh
   mkdir -p ~/.local/bin
   cat > ~/.local/bin/gh-agent <<'EOF'
   #!/bin/sh
   GH_CONFIG_DIR="$HOME/.config/gh-agent" exec gh "$@"
   EOF
   chmod +x ~/.local/bin/gh-agent
   gh-agent api user --jq .login
   ```

5. In the Superagent panel, open **Settings → Sources → GitHub** and save the card (or choose **Check again**). Setup checks that the account can push to `kalahroudi/runlet` and restarts the service. `scripts/dsh-superagent status` must exit 0.
6. Confirm no other part reports an error, then follow the trigger protocol below.

Keep `kalahroudi` as the only entry under **Settings → Policy → GitHub → allowed**. The agent account is the one doing the work, not a person who may ask for it; adding it to the allowed list would let it authorize itself.

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
