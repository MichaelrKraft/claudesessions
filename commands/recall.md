Show the user the full coder1-mem briefing for their current project (or search past sessions if a query was provided).

The user invoked `/recall` with arguments: `$ARGUMENTS`

If `$ARGUMENTS` is empty:
  Run the full briefing script and show the user its output verbatim in a code block:
  ```bash
  ~/.claudesessions/bin/inject-context.sh --full
  ```
  Then briefly summarize what stood out (1–2 sentences max) and ask if they want to dig into anything specific.

If `$ARGUMENTS` is non-empty:
  Treat the arguments as a full-text search query across all past sessions across all projects:
  ```bash
  sessions search "$ARGUMENTS"
  ```
  Show the user the table of results verbatim. If results exist, ask which session they'd like to view in detail (offer to run `sessions view <archive_name>`). If no results, suggest broader search terms.

Style:
- Don't summarize the briefing itself; print the script output verbatim so the user sees what their customers will see.
- Keep your follow-up commentary terse — one short paragraph max.
- Don't run other tools (no Read, no Grep, no Bash exploration). This command is a thin shell over the coder1-mem CLI.
