#!/usr/bin/env bash
# Codewhale message_submit hook: on the first message of each session,
# prepend `engram context` for the workspace project. Later messages pass through.
set -uo pipefail

payload="$(cat)"
session_id="$(jq -r '.session_id // empty' <<<"$payload")"
truncated="$(jq -r '.text_truncated // false' <<<"$payload")"
[[ -z "$session_id" || "$truncated" == "true" ]] && exit 0

state_dir="$HOME/.codewhale/hooks/state"
mkdir -p "$state_dir"
find "$state_dir" -name 'engram-*' -mtime +7 -delete 2>/dev/null
marker="$state_dir/engram-${session_id//[^A-Za-z0-9_-]/_}"
[[ -e "$marker" ]] && exit 0
touch "$marker"

workspace="$(jq -r '.workspace // empty' <<<"$payload")"
[[ -n "$workspace" ]] && cd "$workspace" 2>/dev/null

context="$(timeout 10 engram context 2>/dev/null | head -c 12000)"
[[ -z "$context" || "$context" == "No previous session memories found."* ]] && exit 0

jq -n --arg ctx "$context" --arg text "$(jq -r '.text' <<<"$payload")" \
  '{text: ("<engram_memory>\n" + $ctx + "\n</engram_memory>\n\n" + $text)}'
