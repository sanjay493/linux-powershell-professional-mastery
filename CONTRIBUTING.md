# Contributing

Thank you for helping improve **Linux & PowerShell Professional Mastery**.

## Ways to contribute

- **Report an error:** open an issue with the page, the section, the exact command, the OS/PowerShell version, the output you got, and an official documentation link if you have one.
- **Improve content:** clearer explanations, extra exercises, better troubleshooting entries.
- **Improve scripts:** bug fixes, portability, better error handling.

## Workflow

1. Fork the repository and create a branch (`fix/day02-copy-item`, `content/day05-extra-lab`).
2. Set up locally:

    ```bash
    python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\Activate.ps1
    pip install -r requirements.txt
    mkdocs serve
    ```

3. Follow `templates/lesson-template.md` and `templates/lab-template.md`. Every lesson keeps all required sections.
4. Validate before committing:

    ```bash
    python tools/check_course.py
    python tools/build_pdfs.py --stub && mkdocs build --strict
    npx markdownlint-cli2
    shellcheck scripts/linux/*.sh
    ```

5. Commit with a meaningful message (`fix: correct Copy-Item nesting example on Day 02`) and open a pull request. CI must pass.

## Content standards

- Explain every command: purpose, syntax, key parameters, permissions, platform/version limits.
- Label example output as an example unless it was captured from a real run.
- Labs: authorised systems only, previews before destructive commands, backups before configuration changes, never disable security controls as a workaround.
- Cite official documentation (man7.org, documentation.ubuntu.com, learn.microsoft.com, wireshark.org, nmap.org).
- Never commit credentials, tokens, private keys, real internal host names or personal data.

## Licence

By contributing you agree that your contributions are licensed under the [MIT License](LICENSE).
