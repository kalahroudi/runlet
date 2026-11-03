#!/usr/bin/env bash
# Set up the dedicated GitHub account used by dsh-super-agent for RunLet.
#
# It automates everything after GitHub signup. The two browser gates stay
# manual: creating/verifying the account and accepting the collaborator
# invitation. Everything else, including the source save and the first
# trigger with --activate, runs here.
#
# Usage:
#   ./scripts/setup-agent-account.sh            # account, CLI, wrapper
#   ./scripts/setup-agent-account.sh --activate # also save the Source and trigger #36
#   ./scripts/setup-agent-account.sh --check    # report current state, change nothing

set -euo pipefail

AGENT_LOGIN="${AGENT_LOGIN:-kalahroudi-agent}"
REPO="${REPO:-kalahroudi/runlet}"
AGENT_GH_HOME="${AGENT_GH_HOME:-$HOME/.config/gh-agent}"
WRAPPER="${WRAPPER:-$HOME/.local/bin/gh-agent}"
SUPERAGENT_URL="${SUPERAGENT_URL:-http://127.0.0.1:3082}"
DSH_SUPERAGENT_CHECKOUT="${DSH_SUPERAGENT_CHECKOUT:-$HOME/Documents/testdrive/dsh-superagent}"
TRIGGER_ISSUE="${TRIGGER_ISSUE:-36}"
ACTIVATE=0
CHECK_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --activate) ACTIVATE=1 ;;
    --check) CHECK_ONLY=1 ;;
    *) echo "Unknown argument: $arg (use --activate or --check)" >&2; exit 2 ;;
  esac
done

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

if [[ $CHECK_ONLY -eq 1 ]]; then
  say "Agent wrapper"
  if [[ -x "$WRAPPER" ]]; then
    "$WRAPPER" api user --jq .login || true
  else
    echo "missing: $WRAPPER"
  fi
  say "Dedicated config"
  if [[ -f "$AGENT_GH_HOME/hosts.yml" ]]; then
    GH_CONFIG_DIR="$AGENT_GH_HOME" gh api user --jq .login || true
  else
    echo "not signed in under $AGENT_GH_HOME"
  fi
  say "Superagent"
  curl -fsS -H 'x-orchestrator-request: 1' "$SUPERAGENT_URL/orchestrator/api/state" |
    python3 -c "import json,sys; d=json.load(sys.stdin); a=d['setup']['accounts']; print('repository', a.get('repository')); print('agent', a.get('agent')); print('problem', d['setup']['problem'])" || true
  exit 0
fi

command -v gh >/dev/null || die "gh is not installed"
command -v curl >/dev/null || die "curl is not installed"
command -v open >/dev/null || die "open is not available; this script is for macOS"

say "Step 1 of 5: create @$AGENT_LOGIN"
cat <<EOF
Create the account in the browser, verify its email and enable 2FA.
The signup page will open. Return here when it is done.
EOF
open https://github.com/signup || true
read -r -p "Press Enter when @$AGENT_LOGIN exists and its email is verified... " _

say "Step 2 of 5: give @$AGENT_LOGIN write access to $REPO"
cat <<EOF
Invite it under Settings -> Collaborators -> Add people, with Write access.
Accept the invitation while signed in as @$AGENT_LOGIN.
The collaborators page will open.
EOF
open "https://github.com/$REPO/settings/access" || true
read -r -p "Press Enter when the invitation is accepted... " _

say "Step 3 of 5: sign the CLI in"
mkdir -p "$AGENT_GH_HOME"
chmod 700 "$AGENT_GH_HOME"
if GH_CONFIG_DIR="$AGENT_GH_HOME" gh api user --jq .login >/dev/null 2>&1; then
  echo "Already signed in."
else
  GH_CONFIG_DIR="$AGENT_GH_HOME" gh auth login
fi
login="$(GH_CONFIG_DIR="$AGENT_GH_HOME" gh api user --jq .login)"
[[ "$login" == "$AGENT_LOGIN" ]] || die "Signed in as '$login', expected '$AGENT_LOGIN'."

say "Step 4 of 5: check push access"
push="$(GH_CONFIG_DIR="$AGENT_GH_HOME" gh api "repos/$REPO" --jq '.permissions.push' 2>/dev/null || echo false)"
[[ "$push" == "true" ]] || die "@$AGENT_LOGIN cannot push to $REPO. Accept the Write invitation first."
echo "Write access confirmed."

say "Step 5 of 5: install the agent wrapper"
mkdir -p "$(dirname "$WRAPPER")"
if [[ -f "$WRAPPER" ]] && ! grep -q 'GH_CONFIG_DIR=' "$WRAPPER"; then
  cp "$WRAPPER" "$WRAPPER.trial.bak"
  echo "Saved the old trial wrapper to $WRAPPER.trial.bak"
fi
tmp="$(mktemp)"
cat > "$tmp" <<EOF
#!/bin/sh
GH_CONFIG_DIR="$AGENT_GH_HOME" exec gh "\$@"
EOF
chmod 755 "$tmp"
mv "$tmp" "$WRAPPER"
[[ "$("$WRAPPER" api user --jq .login)" == "$AGENT_LOGIN" ]] || die "Wrapper verification failed."
echo "gh-agent now acts as @$AGENT_LOGIN."

if [[ $ACTIVATE -eq 0 ]]; then
  say "Account ready"
  cat <<EOF
The CLI and wrapper are set. Re-run with --activate to save the GitHub Source
and trigger issue #$TRIGGER_ISSUE, or let the agent do those two steps.
EOF
  exit 0
fi

say "Re-saving the GitHub Source"
curl -fsS -H 'x-orchestrator-request: 1' "$SUPERAGENT_URL/orchestrator/api/settings" > /tmp/sa-settings.json
python3 - "$SUPERAGENT_URL" <<'PY'
import json, sys, urllib.request
base = sys.argv[1].rstrip('/') + '/orchestrator/api'
d = json.load(open('/tmp/sa-settings.json'))
source = next(x for x in d['sources'] if x['id'] == 'github')
body = json.dumps({'value': source['value'], 'revision': source['revision']}).encode()
request = urllib.request.Request(
    base + '/settings/source:github',
    data=body,
    method='PUT',
    headers={'x-orchestrator-request': '1', 'content-type': 'application/json'},
)
print(urllib.request.urlopen(request).read().decode())
PY

say "Waiting for setup to resolve @$AGENT_LOGIN"
ok=0
for _ in $(seq 1 60); do
  if curl -fsS -H 'x-orchestrator-request: 1' "$SUPERAGENT_URL/orchestrator/api/state" > /tmp/sa-state.json 2>/dev/null; then
    if AGENT_LOGIN_ENV="$AGENT_LOGIN" python3 -c "import json,os,sys; d=json.load(open('/tmp/sa-state.json')); a=d['setup']['accounts']; sys.exit(0 if d['setup']['problem'] is None and a and a.get('agent')==os.environ['AGENT_LOGIN_ENV'] else 1)" 2>/dev/null; then
      ok=1
      break
    fi
  fi
  sleep 2
done
[[ $ok -eq 1 ]] || die "Setup did not report @$AGENT_LOGIN as the agent. Check scripts/dsh-superagent status."
echo "Setup resolved the agent account."

if [[ -x "$DSH_SUPERAGENT_CHECKOUT/scripts/dsh-superagent" ]]; then
  "$DSH_SUPERAGENT_CHECKOUT/scripts/dsh-superagent" --profile superagent status || die "Superagent status did not exit 0."
fi

say "Triggering issue #$TRIGGER_ISSUE"
me="$(gh api user --jq .login)"
[[ "$me" != "$AGENT_LOGIN" ]] || die "The trigger must come from a different account than @$AGENT_LOGIN."
gh issue comment "$TRIGGER_ISSUE" --repo "$REPO" --body "@$AGENT_LOGIN deliver this issue"
echo "Trigger posted. The agent polls about once a minute."
