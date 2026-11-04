# Engram in Codewhale

The shared engram rule lives in ~/.claude/CLAUDE.md. Codewhale has no engram plugin, so follow this protocol with the `mcp_engram_*` tools:

- The first message of a session starts with an `<engram_memory>` block injected by a hook. If it is missing, call `mem_context`; use `mem_search` when past decisions may be relevant.
- Proactively call `mem_save` after important decisions, bug root causes, configuration changes, or facts about the user's setup. Use `mem_suggest_topic_key` first when the memory may update an existing topic.
- Before ending a substantial session, call `mem_session_summary` with what was done and what is pending.
