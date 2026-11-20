#!/usr/bin/env bash
# Usage: scripts/factory.sh <count> [delay_seconds]
# Each run: branch -> co-authored commit -> PR -> self-merge.
set -euo pipefail
count=${1:?count}; delay=${2:-3}
cd "$(dirname "$0")/.."
trailer=$'\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
body=$'Automated PR from the achievements factory.\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)'
mkdir -p log
for i in $(seq 1 "$count"); do
  git checkout -q main && git pull -q --ff-only
  id=$(date +%Y%m%d-%H%M%S)-$i
  br="factory/$id"
  git checkout -q -b "$br"
  echo "$id" >> log/factory.log
  git add log/factory.log
  git commit -q -m "Factory run $id$trailer"
  git push -q -u origin "$br" 2>/dev/null
  url=$(gh pr create --base main --head "$br" --title "Factory run $id" --body "$body")
  gh pr merge "$url" --merge --delete-branch >/dev/null 2>&1 || gh pr merge "$url" --merge
  git checkout -q main && git branch -q -D "$br" 2>/dev/null || true
  echo "[$i/$count] merged $url"
  sleep "$delay"
done
git checkout -q main && git pull -q --ff-only
