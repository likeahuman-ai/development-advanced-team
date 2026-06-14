#!/usr/bin/env bash
# WorktreeRemove hook — jj-safe teardown (development-advanced-team).
#
#   jj repo  -> `jj workspace forget` (drops tracking; the chain tip commit is
#               left untouched, so nothing is orphaned) then remove the directory.
#   non-jj   -> `git worktree remove` + `git branch -D` (mirror the default).
#
# Belt-and-braces, not the sole cleanup. Claude Code may skip this hook entirely
# (claude-code#37611), so the Build skill ALSO runs an explicit forget + sweep at
# step 3.2.6; both paths are idempotent. This hook deliberately does NOT
# `jj abandon` the worker's leftover working-copy commit — the session owns that at
# 3.2.6, after it has folded each worker's commit into the chain.
#
# I/O contract (Claude Code):
#   stdin  : JSON, e.g. { "worktree_path": "<abs-path>", "cwd": "<repo-path>", ... }
#   exit   : 0 always — output is not consumed; failures are logged in --debug only.
set -euo pipefail

input=$(cat)
wt=$(printf '%s' "$input" | jq -r '.worktree_path // empty' 2>/dev/null || true)
repo=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -n "$wt" ] || { echo "[jj-worktree] no worktree_path; nothing to do" >&2; exit 0; }
# Workspace/branch name. create.sh names both the dir and the scratch branch from
# the same JSON .name, so basename(worktree_path) matches both; kept in sync there.
name=$(basename "$wt")

# Locate the repo root from cwd if given (robust even when the worktree dir was
# already deleted before this hook ran), else from the worktree dir itself.
jj_root=""
for cand in "$repo" "$wt"; do
  [ -n "$cand" ] || continue
  if r=$( cd "$cand" 2>/dev/null && jj root 2>/dev/null ); then jj_root="$r"; break; fi
done

if [ -n "$jj_root" ]; then
  echo "[jj-worktree] forgetting jj workspace '$name'" >&2
  ( cd "$jj_root" && jj workspace forget "$name" ) >&2 || true
else
  # non-jj: mirror Claude Code's default git worktree teardown.
  git_main=""
  for cand in "$repo" "$wt"; do
    [ -n "$cand" ] || continue
    m=$( git -C "$cand" worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p' )
    if [ -n "$m" ]; then git_main="$m"; break; fi
  done
  if [ -n "$git_main" ]; then
    echo "[jj-worktree] removing git worktree '$name'" >&2
    git -C "$git_main" worktree remove --force "$wt" >&2 || true
    git -C "$git_main" branch -D "$name" >&2 || true
  fi
fi

[ -d "$wt" ] && rm -rf "$wt" || true
exit 0
