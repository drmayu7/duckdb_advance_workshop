#!/usr/bin/env bash
# worktree_ref <repo>: a git tree id for the working tree as it is now, tracked
# and untracked files alike (.gitignore respected), written through a scratch
# index so the real index is untouched. Tests build Content releases from it
# (CONTENT_REF), so they check the work in progress, not the last commit.
worktree_ref() {
  local idx
  idx="$(mktemp)"
  cp "$(git -C "$1" rev-parse --git-path index)" "$idx" 2>/dev/null || : >"$idx"
  GIT_INDEX_FILE="$idx" git -C "$1" add -A >/dev/null
  GIT_INDEX_FILE="$idx" git -C "$1" write-tree
  rm -f "$idx"
}
