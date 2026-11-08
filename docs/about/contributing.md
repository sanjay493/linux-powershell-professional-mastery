---
description: "How to report errors, propose improvements and submit pull requests."
---

# Contributing

Contributions are welcome: corrections, clearer explanations, extra exercises and better scripts.

## Report a problem

Open a GitHub issue with:

- The page or file and section.
- What is wrong. Include the exact command, OS and version, and the actual output you got.
- The official documentation that supports the correction, if you have it.

## Submit a change

1. Fork the repository and create a branch: `git checkout -b fix/day02-copy-item`.
2. Set up locally:

    ```bash
    python -m venv .venv
    source .venv/bin/activate        # Windows: .venv\Scripts\Activate.ps1
    pip install -r requirements.txt
    mkdocs serve                     # http://127.0.0.1:8000
    ```

3. Follow the lesson template in `templates/lesson-template.md`. Every lesson must keep **all required sections**.
4. Run the checks before committing:

    ```bash
    python tools/check_course.py
    mkdocs build --strict
    ```

5. Open a pull request describing what changed and how you verified it.

## Content rules

- Every command must be **explained**, with its OS/version limitations stated.
- Example output must be realistic and labelled as an example unless it was captured in CI.
- Labs must be safe: authorised systems only, previews before destructive commands, backups before configuration changes, and no disabling of security controls.
- Never include real credentials, tokens, internal host names or personal data.

## Code of conduct

Be respectful and constructive. Assume good intent. Harassment of any kind is not tolerated.
