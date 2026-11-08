# Development Status

**Last updated:** 2026-11-08 · **Last release:** launch (Days 01–02) · **Next release:** 2026-11-08 22:00 IST (Days 03–04)

## Phase tracker

| Phase | Status | Notes |
|---|---|---|
| 1. Inspection & planning | Done | Tools checked; `course-plan.yml` is the curriculum and schedule |
| 2. Course content | In progress | Days 01–02 published; two days per night at 22:00 IST |
| 3. Scripts | In progress | `system-info` (Bash + PowerShell) done; others ship with their days |
| 4. Website | Done | MkDocs Material, nav markers for appending, search, dark/light theme |
| 5. Handbooks (PDF) | Done (pipeline) | Rebuilt every release; topic PDFs appear when their modules are complete |
| 6. Testing | Done (pipeline) | check_course, markdownlint, ShellCheck, PSScriptAnalyzer, script execution, PDF validation, strict build |
| 7. GitHub setup | See below | |
| 8. Deployment | See below | |

## Content progress

| Day | Title | Lesson | Lab | Extras |
|---|---|---|---|---|
| 01 | Introduction to Linux and PowerShell | Published | Published | system-info.sh, System-Info.ps1 |
| 02 | File and Directory Management | Published | Published | — |
| 03–30 | See `course-plan.yml` | Planned | Planned | Per plan |

## Validation record

| Item | Tested | Static analysis | Not tested |
|---|---|---|---|
| `System-Info.ps1` | Executed on Windows 11 / Windows PowerShell 5.1 (Text, Csv, Json, invalid input) | PowerShell parser; PSScriptAnalyzer in CI | — |
| `system-info.sh` | Ran under Git Bash on Windows (degraded mode, `n/a` fields); full run in CI on Ubuntu 24.04 | `bash -n` passed; ShellCheck in CI | Not run on a physical Ubuntu machine |
| Day 01 PowerShell demo output | Captured on Windows 11 / PS 5.1 (host and user renamed) | — | — |
| Day 01–02 Linux demo output | — | Reviewed against GNU coreutils / Ubuntu 24.04 documentation | Labelled as examples |
| PDFs | Built and validated in CI (WeasyPrint needs Pango, which this Windows host lacks) | — | Not built locally |

## Curriculum topics (reference for nightly releases)

The full topic list for each day is in `docs/course/index.md` (key commands) and in the original specification:

- **Day 03** Reading and managing files: `cat`, `less`, `more`, `head`, `tail` (`-f`, `-n`), `wc`; `Get-Content` (`-TotalCount`, `-Tail`, `-Wait`), `Select-Object`, `Measure-Object`; reading logs; large files; redirection (`>`, `>>`, `2>`, `2>&1`, `&>`, `Out-File`, `Tee-Object`, PowerShell streams 1–6).
- **Day 04** Searching: `find`, `grep` (`-r -i -n -v -E -c -l`), `locate`/`plocate`, `which`; `Get-ChildItem -Recurse -Filter`, `Select-String`, `Where-Object`; wildcards vs regular expressions; multi-file search; practical log searching.
- **Day 05** Help, history, pipelines: `man`, `--help`, `history`, `type`, `command -v`; `Get-Help`, `Get-Command`, `Get-History`, `Get-Alias`; text vs object pipelines; `;` `&&` `||`; exit codes `$?`, `$LASTEXITCODE`, `$?` in PowerShell; basic error handling.
- **Days 06–30:** as listed in `docs/course/index.md` and the course specification sections for Modules 2–6.

## Hosting decision

| Option | Cost | Why chosen / not |
|---|---|---|
| **GitHub Pages + GitHub Actions** | Free (public repo) | **Chosen.** Native to the repo, HTTPS, OIDC deploy with no secrets |
| Cloudflare Pages | Free tier | Good alternative; extra account not needed |
| Netlify / Vercel | Free tiers with build-minute limits | Not needed |

## GitHub / deployment status

- Repository: pending GitHub CLI authentication on the maintainer machine.
- Pages: will be enabled with build type "GitHub Actions" after the first push.
- Nightly release automation: scheduled agent at 16:30 UTC (22:00 IST), following `automation/NIGHTLY-RELEASE.md`.
