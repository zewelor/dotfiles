# Maintaining agent skills

The tracked files in `prv/.agents/skills/` are the approved consumer copies for
desktop and explicitly configured servers;
`prv/.agents/.skill-lock.json` records their upstream sources and last recorded
folder hashes. They are part of the private Git repository and may contain local
changes. The upstream authoring repository is a separate source of truth: make
changes there first when maintaining a skill owned there. Third-party skills may
also have local adaptations that need to survive an upstream update.

`update-all` does not update these files. The skills CLI's global updater can
replace an installed skill when its upstream hash changes, including local
edits; its lock is not a Git merge or a guarantee that the installed content is
unmodified. A lock `ref` can name a moving branch rather than a pinned commit.

For an intentional update, work on one skill at a time:

1. Inspect the private repository's status and diff, the skill and its lock entry.
   Preserve any existing work. Identify its upstream URL, path and ref. Record
   the exact upstream commit used for the proposed update; a branch name or
   folder hash alone does not pin that commit.
2. Use a disposable directory and a separate `HOME`, cache and temporary
   directory. Copy the selected skill and global lock into the disposable
   `HOME/.agents/`, dereferencing links so the copy cannot write through to the
   live home or repository. Keep a second, untouched copy of the selected skill
   outside that disposable home. Do not point the updater at live files.
3. Run the updater only for the selected name in the disposable home, with a
   deliberately pinned CLI version, for example `npx --yes skills@1.8.1 update
   <skill-name> --global -y`. The version is the one tested for this workflow;
   review CLI changes before choosing another version. Check the command output,
   exit status, resulting skill and lock entry. A successful exit alone does not
   prove that the source was fetched or a skill updated.
4. Compare the untouched copy with the candidate, including supporting files and
   deletions. Identify local adaptations against the previous upstream revision
   where available. Manually reconcile them with the new upstream revision; if
   their intent or a conflict is unclear, stop and resolve it explicitly. Never
   blindly copy the updater's output over the tracked skill.
5. Apply only the reviewed changes and relevant lock entry to the private Git
   checkout. Inspect the complete scoped Git diff and validate the skill before
   any separately authorized commit or deployment. An update to a source
   repository, the private consumer, and its parent gitlink are separate steps.
