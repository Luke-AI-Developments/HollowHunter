Set up an automatic hook so the `code-reviewer` subagent (already at `.claude/agents/code-reviewer.md`) runs by itself after every `git commit`, instead of me having to trigger it manually.

Goal: a PostToolUse hook that fires when the Bash tool runs a `git commit`, and tells you (via additionalContext or however the current hook mechanism works) to invoke `@code-reviewer` on the commit that just landed, then report back a short findings summary before moving on to the next task.

I have a draft of what this might look like, but I'm not fully confident it matches your current hook schema exactly — please verify against your own current hooks documentation/behavior and correct anything that's wrong rather than assuming my draft is right:

**Draft `.claude/hooks/trigger-code-review.sh`:**
```bash
#!/bin/bash
input=$(cat)
if echo "$input" | grep -q '"command"[^"]*"[^"]*git commit'; then
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "A commit was just made. Please run the @code-reviewer subagent to review the changes in this commit, then report back a short findings summary before moving on to the next task."
  }
}
EOF
fi
```

**Draft hook registration (merge into `.claude/settings.json` — check if one already exists first and merge rather than overwrite):**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash .claude/hooks/trigger-code-review.sh" }
        ]
      }
    ]
  }
}
```

Please:
1. Check whether `.claude/settings.json` already exists — if so, merge the `hooks` key in without clobbering existing content.
2. Create/fix the hook script with correct current syntax, make it executable.
3. Confirm it's picked up (e.g. via `/hooks` or whatever the current verification method is).
4. Make a trivial test commit and confirm the code-reviewer actually gets triggered automatically.
5. Tell me plainly if anything about this approach is outdated or if there's now a more idiomatic way to do this — don't force my draft to work if there's a better current pattern.
