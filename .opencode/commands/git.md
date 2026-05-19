---
description: git - commit, push via PR or default branch, watch checks, auto-fix on failure
agent: build
subtask: true
---

You are a git delivery bot. Execute the following steps sequentially for the current branch/worktree. Do not skip any step.

## Invocation

Arguments: `$ARGUMENTS`

Supported forms:
- `/git pr`
- `/git pr --no-wait`
- `/git push`
- `/git push --no-wait`

Interpretation:
- `$1` is the delivery mode and MUST be either `pr` or `push`.
- `--no-wait` is optional and means skip remote check watching and skip the auto-fix loop.
- No other arguments are supported.

If the arguments are missing or unsupported, STOP with:
`Usage: /git pr [--no-wait] | /git push [--no-wait]`

## Start context

Mode: `$1`
All arguments: `$ARGUMENTS`
Current branch: !`git branch --show-current`
Default branch: !`gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`
Git status: !`git status --short`
Staged diff stat: !`git diff --cached --stat`
Unstaged diff stat: !`git diff --stat`

## Step 1: Validation

- If mode is `pr` and the current branch is the default branch - STOP with error "Cannot create PR from default branch".
- If mode is `push` and the current branch is not the default branch - STOP with error "Direct push mode must run on the default branch".
- If there are no changes (neither staged nor unstaged) - STOP with error "No changes to deliver".
- If `--no-wait` is present, remember `wait_for_checks=false`; otherwise remember `wait_for_checks=true`.

## Step 2: AI commit

1. Run: `git add -A`
2. Run `git diff --staged` to see what changes are ready to commit.
3. Analyze the staged diff and generate a conventional commit message.

### Conventional commit guidelines

Determine the commit type based on the changes:
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation only
- `style` - Formatting, no code change
- `refactor` - Code change, neither fix nor feature
- `perf` - Performance improvement
- `test` - Adding/updating tests
- `chore` - Build/tooling changes

Format:
```text
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

- If mode is `pr`, run: `git push -u origin <branch>`
- If mode is `push`, run: `git push origin <branch>`
- After a successful push, record the pushed commit SHA with: `git rev-parse HEAD`

## Step 4: Delivery target

### PR mode

1. Check if a PR already exists for this branch:
   `gh pr view --json url --jq '.url' 2>/dev/null || echo ""`
2. If PR exists, print its URL and continue to Step 5.
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

### Direct push mode

There is no PR URL. The delivery target is `origin/<default-branch>`.

## Step 5: Watch checks

If `wait_for_checks=false`, skip to Step 7 (Success) with status `checks not watched (--no-wait)`.

Never wait indefinitely:
- If no GitHub Actions checks/runs are discovered after the explicit retry window below, treat that as a successful delivery with status `no GitHub Actions runs found`.
- If checks/runs exist but remain pending for more than 30 minutes, STOP with a report that includes the pending check/run names and links.

### PR mode

1. Check whether this PR has any checks:
   `gh pr checks --json name,state,bucket,link`
2. If the command reports no checks or exits only because checks are pending/not yet created, wait 30 seconds and retry. Repeat for up to 2 minutes.
3. If no checks are found after waiting, go to Step 7 (Success) with status `no GitHub Actions runs found for PR`.
4. If checks exist, run with a 30 minute cap:
   `timeout 30m gh pr checks --watch --fail-fast --interval 30`

If exit code is 0 - go to Step 7 (Success).
If exit code is 124 - STOP with a timeout report listing pending checks and links.
If exit code is not 0 - go to Step 6 (Auto-fix loop).

### Direct push mode

1. Find workflow runs for the pushed commit:
   `gh run list --commit <sha> --json databaseId,status,conclusion,name,url --limit 20`
2. If no runs are found immediately, wait 30 seconds and retry. Repeat for up to 2 minutes.
3. If no runs are found after waiting, go to Step 7 (Success) with status `no GitHub Actions runs found for pushed commit`.
4. For each run found for the pushed commit, run:
   `timeout 30m gh run watch <run-id> --exit-status --interval 30`

If all watched runs exit with code 0 - go to Step 7 (Success).
If any watched run exits with code 124 - STOP with a timeout report listing pending runs and links.
If any watched run exits with non-zero status - go to Step 6 (Auto-fix loop).

## Step 6: Auto-fix loop

**Loop up to 3 attempts.**

For each attempt:
1. Get failing check details:
   - PR mode: `gh pr checks --json name,state,bucket,link`
   - Direct push mode: `gh run list --commit <sha> --status failure --json databaseId,name,conclusion,url --limit 20`
2. Fetch logs for failing GitHub Actions:
   - PR mode: find run-id from the failing check link, then run `gh run view --log-failed <run-id>`
   - Direct push mode: run `gh run view --log-failed <run-id>` for each failing run
3. Analyze the source code related to the failures.
4. Implement the fix:
   - Make minimal code changes to resolve the failure.
   - Verify locally by running the project's relevant tests/checks:
     * Detect the test runner: look for `bin/rails test`, `npm test`, `pytest`, `cargo test`, `go test ./...`, etc.
     * If unsure, check `Makefile`, `justfile`, or `package.json` scripts for a `test`/`check` target.
     * Run only the tests/checks related to the failing areas.
   - Stage and commit with `git add -A && git commit -m "fix: <describe-fix>"`
   - Push:
     * PR mode: `git push`
     * Direct push mode: `git push origin <branch>`
   - Record the new pushed commit SHA with: `git rev-parse HEAD`
5. Watch checks again:
   - PR mode: repeat Step 5 PR-mode discovery first; if checks exist, run `timeout 30m gh pr checks --watch --fail-fast --interval 30`
   - Direct push mode: repeat Step 5 direct-push discovery first; if runs exist, watch them with `timeout 30m gh run watch <run-id> --exit-status --interval 30`
6. If checks pass - break loop and go to Step 7.
7. If still failing and attempts < 3 - repeat from step 1 with updated context.
8. If all 3 attempts fail - STOP with comprehensive report:
   - **Failing check** (name, link)
   - **Root cause** - diagnosed from logs and code
   - **Fix attempts** - what was tried and why it did not work
   - **Suggested commands** for manual intervention

## Step 7: Success

Print:
- Mode: `<pr|push>`
- Branch: `<branch>` -> `<default-branch>`
- Commit: `<message>`
- Target:
  * PR mode: `<pr-url>`
  * Direct push mode: `origin/<default-branch>`
- Status: `checks passed`, `checks not watched (--no-wait)`, `no GitHub Actions runs found for PR`, or `no GitHub Actions runs found for pushed commit`
- If auto-fix loop was used, include: **Auto-fixes applied:** N attempts
