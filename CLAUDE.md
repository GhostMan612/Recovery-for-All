# Sovereign Mantle - Claude Code Guidelines

You are working on the Sovereign Mantle infrastructure. Absolute precision and architectural perfection are required. Because we are dealing with a massive codebase, deep graph structures, and large data files, **token conservation and context management are your top operational priorities.** 

Follow these workflow rules strictly to prevent context window overloads:

## 1. CLI Execution & Testing
*   **Filter All Terminal Output:** Never read massive CLI outputs, full test logs, or raw JSON payloads directly into the main context window. 
*   **Pipe for Failures:** Always pipe test commands and broad searches through filters. For example, use `bash run_tests.sh 2>&1 | grep -A5 -E "FAIL|ERROR|Error|Expected|Received" | head -100`. Only ingest the actual failures, never the passing checks.
*   **Stop Reactive Auto-Testing:** Do NOT run the full test suite after every minor file edit. Run targeted tests for the specific module you are editing. Only run the full `run_tests.sh` suite when a commit is fully staged and ready for final verification.

## 2. Context Window & Token Management
*   **Use Native Subagents:** For deep file exploration, large file analysis, or complex stack-trace debugging, you MUST spawn a built-in subagent. Let the subagent isolate the heavy reading and return only a concise, synthesized summary to the main thread.
*   **Proactive Compacting:** Do not wait to be asked. Automatically execute `/compact` to clear dead context after successfully verifying and committing a distinct phase of work, before starting the next commit.
*   **Model Tiering:** Default to the fastest appropriate model (e.g., Sonnet) for routine file edits, standard coding tasks, and CLI commands. Reserve Opus strictly for high-level architectural reasoning and complex refactoring.

## 3. Data Handling
*   **No Massive File Reads:** Do not `cat` or `read` large JSON files (like the legacy master trunk) directly into context. Write and execute short Python scripts to probe, count, and survey data shapes instead.
*   **Synthetic Data Only:** Never include real operator family names or personal data in committed source code or tests. Use synthetic names (e.g., `SAMPLE ANCESTOR A`).

## 4. Git Workflow
*   **Explicit Commits:** Only commit by explicit path (e.g., `git add core/engine/edge_store.py`). Never use `git add .` or `git add -A` to avoid pulling in unrelated tagger work.
*   **Approval:** Wait for explicit approval before running `git commit` and `git push`, unless executing a strictly pre-approved sequential plan.