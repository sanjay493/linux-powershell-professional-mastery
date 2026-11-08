# Nightly Release Procedure (22:00 IST / 16:30 UTC)

This file is the **complete instruction set** for the scheduled agent that publishes two new days of the course every night. A human maintainer can follow the same steps by hand.

## 0. Ground rules

- Work only in this repository. Never commit credentials, tokens, real host names or personal data.
- Never delete or rewrite published lessons, except to fix a verified technical error (note it in the changelog).
- Do **not** push anything that fails validation. If validation cannot be made to pass, push nothing, and record the failure in `DEVELOPMENT-STATUS.md` on a separate branch `release-failure/<date>`.
- Quality bar: each new lesson must be **at least as detailed as Day 01 and Day 02**. Use them as the reference examples, along with `templates/lesson-template.md` and `templates/lab-template.md`.
- Technical accuracy matters more than speed. Check every command, option and parameter against official documentation (man7.org, documentation.ubuntu.com, learn.microsoft.com, wireshark.org/docs, nmap.org/book). Mark distribution-specific Linux commands and version-specific PowerShell commands (5.1-only, 7-only, Windows-only).
- **Pipes in tables:** never put `|` inside a backtick code span in a Markdown table (it renders wrongly as `\|` on the site and breaks the table in linters). Write such cells as `<code>cmd1 &#124; cmd2</code>`, escaping `<`, `>` and `&` as HTML entities.
- Label example output as "Expected output (example)". Never present invented output as captured or tested.
- Safety: labs use localhost, WSL2, VMs or `scanme.nmap.org` only; preview before destructive commands; back up before permission, firewall or config changes; never disable security controls as a workaround.

## 1. Select what to publish

1. Read `course-plan.yml`.
2. Take the **first two** days with `status: planned`, in order. If none remain, stop: the course is complete.
3. Read the curriculum topics for those days in `docs/course/index.md` (the "Key commands" column) and the full topic list in `DEVELOPMENT-STATUS.md` → *Curriculum topics*.

## 2. Write the content (for each of the two days)

| File | Requirement |
|---|---|
| `docs/course/<module>/day-NN.md` | All 23 `##` sections of the lesson template (the validator checks them), ≥ 3,500 words, ≥ 10 practice questions + answers, ≥ 5 quiz questions with explanations, homework (+ answer key where applicable), Mermaid diagram where helpful, Bash/PowerShell tabs, "Previous/Next" links at the bottom |
| `docs/labs/lab-NN.md` | All lab-template sections, Lab ID `LAB-NN`, realistic professional scenario, Bash **and** PowerShell solutions |
| Extras listed for the day in `course-plan.yml` | Scripts (see §3), module tests (≥ 20 questions with answer key, collapsible answers), final exam and answer key, certificate template |

## 3. Scripts (when listed as extras)

- Bash: `#!/usr/bin/env bash`, header comment block (purpose, target OS, dependencies, usage, exit codes), `set -o nounset -o pipefail`, `getopts` parsing with `-h` and `-o DIR`, input validation, read-only by default, graceful `n/a` handling when a tool or permission is missing, and exit codes 0/1/2/3 (3 = threshold breached).
- PowerShell: comment-based help, `[CmdletBinding()]`, validated `param()` with `-OutputPath`, `Set-StrictMode -Version Latest`, try/catch, compatible with **both 5.1 and 7**, and the same exit codes. Avoid `Write-Host`; use `Write-Information`/`Write-Verbose`.
- Both must run **without arguments** safely (CI executes them that way and with `-o`/`-OutputPath`).
- Add a section for each script to `docs/projects/scripts.md`: prerequisites, run instructions, sample output (labelled), troubleshooting and validation status.

## 4. Update the site (append, never reset)

1. `mkdocs.yml`: add each lesson between the `# >>> DAYS <module>` / `# <<< DAYS <module>` markers, and each lab between `# >>> LABS` / `# <<< LABS`, in day order. Use the format `- "Day NN: <Short Title>": course/<module>/day-NN.md`.
2. `docs/course/index.md`: turn the day's title into a link.
3. `docs/course/<module>/index.md`: link the lesson and lab and set the status to `Published`.
4. `docs/labs/index.md`: link the lab and set it to `Published` (split the grouped rows LAB-11 – LAB-15 etc. into single rows as they are released).
5. `docs/course/schedule.md`: mark the release row as `:material-check-circle: Published`.
6. Previous day's lesson: replace the plain-text "Next" with a link to the new day.
7. `docs/reference/linux.md`, `docs/reference/powershell.md`, `docs/reference/comparison.md`: **append** entries for every new command (all fields: OS/version, description, syntax, parameters, example, expected output, equivalent, common errors, use case, docs). Add new category headings as needed (Users, Permissions, Processes, Services, Storage, Networking, DNS, Firewall, Security, Logs, Scripting, Automation). Update the coverage table in `docs/reference/index.md`.
8. `docs/assessments/index.md`: add the day's quiz link; link module tests and the final exam when released.
9. `docs/downloads/index.md`: when the Networking guide (Day 15), Cybersecurity reference (Day 20) or Final Assessment (Day 30) becomes available, turn its row into a link to `pdf/<file>.pdf` and set the status to Available.
10. `docs/about/changelog.md`: add a dated entry at the top. `docs/about/index.md`: bump the version (0.1.0 → 0.2.0 for each nightly release) and the "Days published" text.
11. `course-plan.yml`: set `status: published` for the two days.
12. `DEVELOPMENT-STATUS.md`: update the progress table and the "last release" line.

## 5. Validate (all must pass before committing)

```bash
python -m pip install -r requirements.txt
python tools/check_course.py                 # structure, completeness, nav, extras
python tools/build_pdfs.py --stub            # local stand-ins so links resolve (NOT committed)
mkdocs build --strict                        # no broken links or nav problems
npx --yes markdownlint-cli2@0.18.1           # Markdown lint
bash -n scripts/linux/*.sh                   # Bash syntax
shellcheck -S warning scripts/linux/*.sh     # if available
pwsh -NoProfile -Command "Invoke-ScriptAnalyzer -Path scripts/powershell -Recurse -Severity Error"  # if available
```

Remove the stub PDFs afterwards (`docs/downloads/pdf/` is git-ignored, but delete it anyway).

## 6. Commit and push

```bash
git checkout main && git pull --ff-only
git add -A
git commit -m "content: publish Day NN and Day MM (<titles>)"
git push origin main
```

The push triggers `.github/workflows/deploy.yml`, which re-validates, runs every script on Ubuntu 24.04 and Windows (5.1 and 7), builds and validates the PDFs, builds the site in strict mode and deploys it to GitHub Pages.

## 7. Verify the deployment

- Wait for the workflow run to finish (`gh run watch` or `gh run list --limit 1`).
- If it fails, read the logs (`gh run view --log-failed`), fix the cause, and push again.
- Fetch the two new lesson URLs and the downloads page from the live site and confirm they return HTTP 200 and contain the lesson titles.
