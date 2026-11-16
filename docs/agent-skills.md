# Maintaining agent skills

Desktop refreshes upstream skills on each `update-all` through
`npx --yes skills update --global`, when npx is available for the target user.
The saved profile of that user controls this stage, including when invoked
through sudo. Server skips the updater and does not need Node/npx to link skills.
There is no separate timer: updates run when the operator runs `update-all`.
An updater failure is reported and makes `update-all` return a failure.

The desktop skill links point into `prv/.agents/skills/`; the global lock is
`prv/.agents/.skill-lock.json`. Upstream refreshes may overwrite local changes
and leave the private checkout dirty. This is intentional: preserving local
skill adaptations during a refresh is not required. The lock records upstream
sources and folder hashes; a `ref` may name a moving branch.

To distribute a desktop refresh to servers:

1. Inspect the private repository's status and scoped diff, including skill
   files, supporting files, deletions and the global lock. Preserve unrelated
   work and validate the changed skills.
2. Commit and publish the selected changes in the private repository, then
   update and publish the parent dotfiles gitlink as a separate step. Neither
   the updater nor `update-all` commits or pushes changes automatically.
3. Update the server's dotfiles and private checkout to the approved revision,
   then run the required agent installation section if links need updating.
   Deployment is a separately authorized action; desktop updates alone do not
   change a server.

The installer refuses locally changed, untracked or ignored `.agents` sources.
Reconcile and commit a refresh before re-running the agent installation sections.

For skills maintained in a separate authoring repository, make deliberate source
changes there first, then refresh the consumer copy through the usual updater.
