---
description: gh-pr — commit, push, open PR, watch checks, auto-fix on failure
agent: build
subtask: true
---

You are a gh-pr bot. Execute the following steps sequentially for the current branch/worktree. Do not skip any step.

## Start context

Current branch: !`git branch --show-current`
Base branch: !`gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo 'main'`
Git status: !`git status --short`
Staged diff stat: !`git diff --cached --stat`
Unstaged diff stat: !`git diff --stat`

## Step 1: Validation

- If the current branch is `main` or `master` — STOP with error "Cannot gh-pr from main/master".
- If there are no changes (neither staged nor unstaged) — STOP with error "No changes to gh-pr".

## Step 2: AI commit

1. Run: `git add -A`
2. Run `git diff --staged` to see what changes are ready to commit.
3. Analyze the staged diff and generate a conventional commit message.

### Conventional commit guidelines

Determine the commit type based on the changes:
- `feat` — New feature
- `fix` — Bug fix
- `docs` — Documentation only
- `style` — Formatting, no code change
- `refactor` — Code change, neither fix nor feature
- `perf` — Performance improvement
- `test` — Adding/updating tests
- `chore` — Build/tooling changes

Format:
```
<type>: <description>

[optional body]

[optional footer]
```

Rules:
- Keep the first line under 72 characters.
- Use imperative mood ("Add" not "Added").
- Be specific but concise in the description.
- The subject should describe **WHY**, not **WHAT**.

4. Run: `git commit -m "<generated-message>"`
5. If pre-commit hooks fail, read the failure output, fix the issues, and retry commit. Do NOT use `--no-verify`.

## Step 3: Push

Run: `git push -u origin <branch>`

## Step 4: Create or update PR

1. Check if a PR already exists for this branch:
   `gh pr view --json url --jq '.url' 2>/dev/null || echo ""`
2. If PR exists, print its URL and skip to Step 5.
3. If no PR:
   - Generate a PR title (same as commit subject or extended, max 72 chars).
   - Generate minimal body:
     ```markdown
     ## Summary
     [1-2 sentences WHY]

     ## Changes
     - [key change 1]
     - [key change 2]
     ```
   - Create PR: `gh pr create --title "<title>" --body "<body>"`
   - Fetch PR URL: `gh pr view --json url --jq '.url'`

## Step 5: Watch checks

Run: `gh pr checks --watch --fail-fast --interval 30`

If exit code is 0 — go to Step 7 (Success).
If exit code is not 0 — go to Step 6 (Auto-fix loop).

## Step 6: Auto-fix loop

**Loop up to 3 attempts.**

For each attempt:
1. Get failing check details: `gh pr checks --json name,state,bucket,link`
2. If these are GitHub Actions, fetch logs for the failing run:
   - Find run-id from check link
   - `gh run view --log-failed <run-id>`
3. Analyze the source code related to the failures.
4. Implement the fix:
   - Make minimal code changes to resolve the failure.
    - Verify locally by running the project's relevant tests/checks:
      * Detect the test runner: look for `bin/rails test`, `npm test`, `pytest`, `cargo test`, `go test ./...`, etc.
      * If unsure, check `Makefile`, `justfile`, or `package.json` scripts for a `test`/`check` target.
      * Run only the tests/checks related to the failing areas.
   - Stage and commit with `git add -A && git commit -m "fix: <describe-fix>"`
   - Push: `git push`
5. Watch checks again: `gh pr checks --watch --fail-fast --interval 30`
6. If checks pass — break loop and go to Step 7.
7. If still failing and attempts < 3 — repeat from step 1 with updated context.
8. If all 3 attempts fail — STOP with comprehensive report:
   - **Failing check** (name, link)
   - **Root cause** — diagnosed from logs and code
   - **Fix attempts** — what was tried and why it didn't work
   - **Suggested commands** for manual intervention

## Step 7: Success

Print:
- Branch: `<branch>` → `<base>`
- Commit: `<message>`
- PR URL: `<url>`
- Status: `checks passed` (ready for manual merge)
- If auto-fix loop was used, include: **Auto-fixes applied:** N attempts
