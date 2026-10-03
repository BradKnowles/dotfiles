# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal Windows dotfiles managed by [chezmoi](https://www.chezmoi.io/). It configures PowerShell, Git, Starship, Windows Terminal, VS Code (scoop install), and related tools.

## Layout

- `.chezmoiroot` pins the chezmoi source to `src/` — **chezmoi only sees files under `src/`**. Everything at the repo root (`lib/`, `scripts/`, `.editorconfig`, `.vscode/`, this file) is repo tooling, not a managed dotfile.
- `src/.chezmoi.yaml.tmpl` — the init-time config template. Prompts for `roles` (multi-choice of `Personal`, `Work`, `Client`, `Author`), `git.email`, and `git.gpgSigningKey`. Selects age identities based on roles: each of Personal/Work/Client gets only its own key; `Author` is the maintainer role and gets all keys and all role files (deployed but not dot-sourced) so changes can be made across roles. Work/Client machines must never get Author.
- `src/.chezmoiignore` — excludes role-specific files when the user did not select that role (e.g. `Profile/Roles/Work.ps1` is skipped if `Work` is not in `.roles`).
- `src/.chezmoidata/Modules.yaml` — static data merged into template context (currently an empty `modules` list).
- `src/.chezmoitemplates/Header.tmpl` — shared "auto-generated" banner included via `{{ template "Header.tmpl" . }}` at the top of generated files.
- `src/Documents/PowerShell/` — the PowerShell 7 profile. `Microsoft.PowerShell_profile.ps1.tmpl` dot-sources files from `Profile/` conditionally (`lookPath "git"`, `lookPath "aws"`, etc.) and then loops over `.roles` to load `Profile/Roles/<role>.ps1`.
- `src/dot_config/`, `src/AppData/`, `src/scoop/persist/` — target-path-mapped config (chezmoi maps `dot_` → `.`, etc.).
- `scripts/Install-CommitMonoFonts.ps1` + `lib/fonts/commit-mono/*.zip` — manual one-off to install bundled Commit Mono fonts per-user; not invoked by chezmoi.

## Conventions

### File naming (chezmoi)
- `*.tmpl` — Go-template file. Rendered with context including `.roles`, `.git.email`, `.git.gpgSigningKey`, and chezmoi built-ins.
- `encrypted_*.tmpl.age` — age-encrypted template. Decrypted using the identities listed in `.chezmoi.yaml.tmpl` for the active roles. Role-gated files live under `Profile/Roles/`.
- `dot_` prefix → `.` in the target path. `modify_` prefix → modify script.

### Role gating
When adding a file that only applies to one role, both:
1. Place it in a role-scoped path (e.g. `Documents/PowerShell/Profile/Roles/Work.ps1.tmpl`), and
2. Add the matching exclusion to `src/.chezmoiignore` so users without that role don't receive it.

### PowerShell profile
New profile features go in a dedicated `Profile/*.ps1.tmpl` file and are dot-sourced from `Microsoft.PowerShell_profile.ps1.tmpl`. Gate optional integrations on `lookPath` so the profile still loads when the tool is absent.

### .gitignore is an allow-list
`.gitignore` ignores `**/*` by default and whitelists specific patterns (`*.tmpl`, `*.tmpl.age`, `*.png`, `*.ico`, etc.). New file types must be added to the allow-list or `git status` will not see them.

### EditorConfig
Default is **tabs, size 2, LF** (enforced by `.gitattributes` `* text=auto eol=lf`). Exceptions: YAML uses spaces, Windows Terminal `settings.json.tmpl` uses 4-space indent + no trailing-whitespace trim + no final newline.

### Commit messages
Conventional Commits with a gitmoji after the type+scope, e.g. `feat(AWS): ✨ Sort Get-AwsEc2Instances by name`. Scopes in use are listed in `.vscode/settings.json` under `conventionalCommits.scopes` (`Aliases`, `AWS`, `Chezmoi`, `.NET`, `Git`, `PowerShell`, `Starship`, `VSCode`, `WindowsTerminal`, `Roles`).

## Common commands

All chezmoi commands operate on `src/` automatically thanks to `.chezmoiroot`.

- `chezmoi diff` — preview what `apply` would change on this machine.
- `chezmoi apply -v` — render templates and write to target paths.
- `chezmoi execute-template < file.tmpl` — render a single template against current data for debugging.
- `chezmoi data` — dump the template context (useful for checking `.roles` / `.git.*`).
- `chezmoi edit-config-template` — edit `.chezmoi.yaml.tmpl` and re-prompt on next `init`.
- `chezmoi cd` — drop into a pwsh shell at the source dir (configured in `.chezmoi.yaml.tmpl`).
- `chezmoi re-add` — pull current target-file contents back into the source (for non-template files).

Diff tool is `difft` (difftastic); merge tool is Beyond Compare 5. Editor is `notepad++` (chezmoi and git).
