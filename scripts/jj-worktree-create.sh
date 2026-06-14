#!/usr/bin/env bash
# WorktreeCreate hook — jj-safe subagent isolation (development-advanced-team).
#
# Why this exists. Claude Code's default `isolation: worktree` creates a git
# worktree and later tears it down with `git worktree remove` + `git branch -D`
# + a `jj git import`. On a jj-colocated repo that import re-bases the anonymous
# sprint chain onto the trunk seed and drops the founding docs commits (the
# PF-4 corruption; ADR-013). Replacing *creation* with a jj WORKSPACE means
# there is no git worktree and no scratch git branch — so the corrupting
# teardown sequence has nothing to act on, and `jj workspace forget` leaves the
# chain tip commit untouched.
#
#   jj repo  -> `jj workspace add` parented on the chain tip (@-), under
#               .claude/worktrees/<name>. The session keeps @ as an empty commit
#               on the tip at dispatch, so @- is the last finished commit.
#   non-jj   -> reproduce Claude Code's default `git worktree add`, so installing
#               this plugin on a non-jj repo is a behavioural no-op. (non-jj is an
#               explicit non-goal; fidelity here is best-effort.)
#
# Both paths copy .worktreeinclude matches into the new tree: a jj workspace (like
# a git worktree) only checks out *tracked* files, so gitignored build config
# (.env, secrets) needed by provision/Verify must be copied in — Claude Code does
# not do this when a WorktreeCreate hook is defined.
#
# I/O contract (Claude Code):
#   stdin  : JSON, e.g. { "name": "<worktree-name>", "cwd": "<repo-path>", ... }
#   stdout : the created directory's absolute path — AND NOTHING ELSE. Claude Code
#            reads stdout as the worktree path; a stray stdout line wedges
#            creation (cf. claude-code#27467). All diagnostics go to stderr.
#   exit   : 0 = success (stdout is the path); non-zero aborts creation.
set -euo pipefail

# Copy .worktreeinclude matches from $1 (repo root) into $2 (new tree). Best-effort,
# literal paths only — gitignore-style globs (e.g. *.env, secrets/) are NOT expanded.
copy_worktreeinclude() {
  local src="$1" dst="$2" pattern
  [ -f "$src/.worktreeinclude" ] || return 0
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    case "$pattern" in \#*) continue ;; esac
    if [ -e "$src/$pattern" ]; then
      mkdir -p "$dst/$(dirname "$pattern")"
      cp -R "$src/$pattern" "$dst/$pattern"
    fi
  done < "$src/.worktreeinclude" || true
}

input=$(cat)
name=$(printf '%s' "$input" | jq -r '.name // empty' 2>/dev/null || true)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
repo_dir=${cwd:-$PWD}
[ -n "$name" ] || name="wt-$(date +%s)-$$"

# --- jj path: a workspace parented on the chain tip (@-) ---
if ( cd "$repo_dir" 2>/dev/null && jj root >/dev/null 2>&1 ); then
  repo_root=$(cd "$repo_dir" && jj root)
  dest="$repo_root/.claude/worktrees/$name"
  mkdir -p "$(dirname "$dest")"
  echo "[jj-worktree] jj repo: jj workspace add '$name' based on @- at $dest" >&2
  ( cd "$repo_root" && jj workspace add --name "$name" --revision '@-' "$dest" ) >&2
  copy_worktreeinclude "$repo_root" "$dest" >&2
  printf '%s\n' "$dest"
  exit 0
fi

# --- non-jj fall-through: behave like Claude Code's default git worktree create ---
if ( cd "$repo_dir" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1 ); then
  git_root=$(cd "$repo_dir" && git rev-parse --show-toplevel)
  dest="$git_root/.claude/worktrees/$name"
  # baseRef: read project .claude/settings.json only (Claude Code's full
  # enterprise/user/project/local precedence is not replicated here);
  # head -> local HEAD, fresh -> origin/HEAD; default head.
  base_ref=$(jq -r '.worktree.baseRef // "head"' "$git_root/.claude/settings.json" 2>/dev/null || echo head)
  case "$base_ref" in fresh) start="origin/HEAD" ;; *) start="HEAD" ;; esac
  mkdir -p "$(dirname "$dest")"
  echo "[jj-worktree] non-jj repo: git worktree add '$name' off $start" >&2
  ( cd "$git_root" && git worktree add --quiet -b "$name" "$dest" "$start" ) >&2
  copy_worktreeinclude "$git_root" "$dest" >&2
  printf '%s\n' "$dest"
  exit 0
fi

echo "[jj-worktree] '$repo_dir' is neither a jj nor a git repository; cannot create a worktree" >&2
exit 1
