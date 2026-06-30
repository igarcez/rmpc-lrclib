# CLAUDE.md

Index of project instructions. Read referenced file when topic matches.

## How to use this index

1. **Scan first, every task.** Before starting work, read the bullets below and match the task against
   each `If <trigger>` clause. If a trigger fires, read the linked `intelligence/*.md` file in full before
   touching code. If that file is itself an index (a `## Index` of
   `If <sub-trigger> → read intelligence/<topic>/<sub>.md` bullets), don't read it all — match the
   sub-triggers the same way and read only the matching sub-file(s).
2. **Match liberally.** When unsure whether a trigger applies, read the file anyway — the cost of reading
   one short doc is lower than missing a project rule.
3. **Multiple triggers are normal.** A change can touch tests + migrations + API surface at once;
   read every matching file and apply all of them.
4. **Apply the rules during work, not after.** The intelligence files describe required practices
   (commands to run, files to update in lockstep, conventions to follow), not optional reading.
5. **Keep the intelligence up to date.** If you change behaviour that an intelligence file documents
   (e.g. a command name changes, a folder moves, a convention is dropped or added), update the matching
   `intelligence/*.md` file in the same change so the next reader doesn't get stale guidance. If a new
   recurring practice emerges that isn't covered yet, add a new `intelligence/<topic>.md` and link it
   from the index below.
6. **Fix mistakes on sight.** If, while working with an intelligence file, you find anything wrong —
   wrong path, wrong command, outdated rule, contradicts the current code, typo that changes meaning —
   fix it in the file as part of the current change. Don't leave a broken instruction in place for the
   next reader to trip over.
7. **Propagate to subagents.** When dispatching a subagent, include in its prompt: "Scan the
   CLAUDE.md index and read every matching intelligence/*.md file before starting." A subagent
   sees CLAUDE.md but won't reliably follow the index on its own — the explicit instruction
   travels with the task.
8. **Check the system-wide layer for local-app configs.** When the task touches configuration of
   local apps / dotfiles under `~/.config/`, also read `~/.config/intelligence/CLAUDE.md` and scan
   its own index — it carries cross-config hooks and machine-wide intel that span configs beyond
   this repo.

## Index

- If working on the lyrics fetch behavior, the rmpc `on_song_change` wiring, the LRCLIB API calls, the miss cache, or keeping `scripts/lyrics-fetch.sh` / `examples/config.ron` / `README.md` in sync → read [intelligence/lyrics-hook.md](intelligence/lyrics-hook.md)
- If editing any `*.sh` script in this repo (POSIX `sh` conventions, quoting, `set -u`, syntax-checking) → read [intelligence/shell-style.md](intelligence/shell-style.md)
