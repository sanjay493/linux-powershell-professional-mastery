---
description: "Course objectives, version information, licensing and repository."
---

# About this Course

**Linux & PowerShell Professional Mastery** is a free, open-source, 30-day practical training programme for Linux Bash and Windows PowerShell. It covers system administration, cybersecurity, network analysis and automation.

## Objectives

1. Teach the command line on **both** major platforms, side by side, so learners can work in mixed environments.
2. Explain every command (purpose, syntax, parameters, output and pitfalls) instead of listing them.
3. Ground everything in realistic IT, security and networking scenarios with safe, reproducible labs.
4. Produce job-ready skills and portfolio projects for three career pathways.

## Technical baseline

| Component | Version |
|---|---|
| Linux | Ubuntu 24.04 LTS, Bash 5.2, GNU coreutils 9.4 |
| Windows | Windows 11 |
| PowerShell | Windows PowerShell 5.1 and PowerShell 7.4+ |

## Validation policy

Commands and scripts are validated as follows, and each script's documentation states which level applies:

- **Tested:** executed in CI on GitHub-hosted `ubuntu-24.04` and `windows-latest` runners, or on a documented lab machine.
- **Static analysis passed:** ShellCheck, PSScriptAnalyzer or parser checks with no errors.
- **Not tested:** requires hardware, privileges or environments that are not available in CI (for example packet capture on a physical NIC). These are reviewed against official documentation.

Example outputs in lessons are labelled as examples. Your values will differ.

## Version

| | |
|---|---|
| Version | 0.1.0 (Days 01–02 published; nightly releases in progress) |
| Licence | MIT |
| Source | The **repository link** in the site header |

See the [Changelog](changelog.md) and [Contributing](contributing.md).
