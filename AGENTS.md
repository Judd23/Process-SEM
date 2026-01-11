# Agent Working Agreement (Repo-Wide)

## Primary rule: minimal-diff edits
- Make the smallest possible change that satisfies the request.
- Do not change styling, spacing, typography, colors, animations, layout, or design tokens unless explicitly requested.
- Do not refactor, rename, reorder, or clean up unrelated code.
- Do not reformat files or apply automated formatting unless explicitly requested.
- Do not modify files not explicitly allowed in the prompt unless required. If required, STOP and ask before proceeding.

## Scope control
- Touch at most 3 files per task by default.
- If more than 3 files are required, STOP and ask for approval with a file list.

## Process requirements
1) Before editing, list the exact files to be changed and why.
2) Wait for explicit approval before editing.
3) After editing, summarize changes file-by-file and confirm no extra visual diffs were introduced.

## UI change safety
- Prefer local, narrowly scoped changes over global CSS or tokens.
- Any CSS or design change must be justified as necessary for the requested behavior.
