#!/usr/bin/env bash
# Usage: scripts/factory.sh <count> [delay_seconds]
# Each run: branch -> co-authored commit -> PR -> self-merge.
# Retries with backoff when GitHub rate-limits.
set -uo pipefail
count=${1:?count}; delay=${2:-3}
cd "$(dirname "$0")/.."
nl=$'\n'
coauthor=${COAUTHOR:-"dfsdfsgsdfg <87164211+dfsdfsgsdfg@users.noreply.github.com>"}
trailer="${nl}${nl}Co-authored-by: ${coauthor}${nl}Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
body=$'Automated PR from the achievements factory.\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)'
mkdir -p log

retry() { # retry <cmd...>; prints stdout of the successful attempt
  local n=0 wait=30 out
  until out=$("$@" 2>&1); do
    n=$((n+1))
    if [ "$n" -ge 8 ]; then echo "$out" >&2; return 1; fi
    echo "  retry $n in ${wait}s: $(echo "$out" | tail -1)" >&2
    sleep "$wait"; wait=$((wait*2 > 600 ? 600 : wait*2))
  done
  printf '%s' "$out"
}

done_count=0
for i in $(seq 1 "$count"); do
  git checkout -q main && retry git pull -q --ff-only >/dev/null || exit 1
  id=$(date +%Y%m%d-%H%M%S)-$i
  br="factory/$id"
  git checkout -q -b "$br"
  echo "$id" >> log/factory.log
  git add log/factory.log
  git commit -q -m "Factory run $id$trailer"
  retry git push -q -u origin "$br" >/dev/null || exit 1
  url=$(retry gh pr create --base main --head "$br" --title "Factory run $id" --body "$body" | grep -o 'https://github.com/[^ ]*/pull/[0-9]*' | tail -1) || exit 1
  retry gh pr merge "$url" --merge --delete-branch >/dev/null || exit 1
  git checkout -q main && git branch -q -D "$br" 2>/dev/null || true
  done_count=$((done_count+1))
  echo "[$i/$count] merged $url"
  sleep "$delay"
done
git checkout -q main && git pull -q --ff-only
echo "done: $done_count merged"
