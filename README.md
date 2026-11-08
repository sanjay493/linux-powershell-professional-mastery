# Linux & PowerShell Professional Mastery

**30 Days: From Beginner to Advanced IT Professional**

*Master the Command Line. Understand Your Systems. Secure Your Network. Automate Your Work.*

A complete, free, 30-day practical training programme for **Linux Bash** and **Windows PowerShell**, covering system administration, cybersecurity, network analysis and automation. Every lesson teaches both platforms side by side, with labs, quizzes, homework and official documentation links.

- **Website:** <https://learn.agentweekly.in/> (GitHub Pages custom domain, deployed by GitHub Actions; the github.io address redirects here)
- **Platforms:** Ubuntu 24.04 LTS · Windows 11 · Windows PowerShell 5.1 · PowerShell 7.4+
- **Licence:** MIT

## Course structure

| Module | Days | Topics |
|---|---|---|
| 1. Command-Line Fundamentals | 1–5 | Shells, files, reading/searching text, help, pipelines |
| 2. System Administration | 6–10 | Users, permissions, processes, services, storage, packages |
| 3. Networking & Troubleshooting | 11–15 | IP, connectivity, DNS, ports, interfaces, packet capture |
| 4. Security, Logs & Monitoring | 16–20 | Logs, authentication, firewalls, auditing, network security |
| 5. Scripting & Automation | 21–25 | Variables, logic, functions, data processing, scheduling |
| 6. Professional Operations & Projects | 26–30 | Remote admin, investigations, troubleshooting, capstone |

Lessons are released **two days per night at 22:00 IST**. See `course-plan.yml` and the website's *Release Schedule* page.

## Repository layout

```text
docs/                 Website content (MkDocs Material)
  course/module-N/    Daily lessons
  labs/               One lab per day, with solutions
  reference/          Searchable Linux / PowerShell command reference
  careers/            SOC Analyst, Network Analyst, System Administrator pathways
  projects/           Final projects and script library
  assessments/        Quizzes, module tests, final exam
  downloads/          PDF downloads (generated in CI)
scripts/linux/        Bash scripts
scripts/powershell/   PowerShell scripts
tools/                check_course.py (completeness), build_pdfs.py (PDF builder)
templates/            Lesson and lab templates
automation/           Nightly release procedure
course-plan.yml       Curriculum and release schedule (single source of truth)
.github/workflows/    CI/CD: validate → build PDFs + site → deploy to GitHub Pages
```

## Run the website locally

```bash
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
mkdocs serve                       # http://127.0.0.1:8000
```

PDFs need WeasyPrint's Pango libraries (preinstalled on Ubuntu runners: `sudo apt install libpango-1.0-0 libpangoft2-1.0-0`). Build them with:

```bash
python tools/build_pdfs.py
```

## Validation

```bash
python tools/check_course.py         # every published lesson has all required sections
mkdocs build --strict                 # broken links / nav problems fail the build
npx markdownlint-cli2                 # Markdown lint
shellcheck scripts/linux/*.sh         # Bash static analysis
```

CI additionally runs every script on Ubuntu 24.04, Windows PowerShell 5.1 and PowerShell 7, runs PSScriptAnalyzer, and validates every PDF (page count and content) before deploying.

## Hosting (free)

| Service | Free tier | Used for |
|---|---|---|
| **GitHub Pages** (primary) | Free for public repositories | Static site hosting with HTTPS |
| **GitHub Actions** | Free for public repositories | Validation, PDF build, deployment |

Alternatives with free static hosting and GitHub integration: Cloudflare Pages, Netlify, Vercel. None are needed.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Corrections backed by official documentation are especially welcome.

## Licence

[MIT](LICENSE) © 2026 Linux & PowerShell Professional Mastery contributors.
