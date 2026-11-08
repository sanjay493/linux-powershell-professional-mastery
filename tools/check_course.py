#!/usr/bin/env python3
"""Validate course content completeness against course-plan.yml.

Checks, for every day whose status is "published":
  * the lesson file exists and contains every required section heading,
  * difficulty, estimated time and at least one "Expected output" block are present,
  * at least 10 numbered practice questions and at least 5 quiz answers exist,
  * the matching lab exists and contains the required lab sections,
  * both appear in mkdocs.yml navigation,
  * every listed extra (script / assessment file) exists,
  * no placeholder text ("coming soon", "TODO", "lorem ipsum") is present.

Exit code 0 = all checks passed, 1 = at least one failure.
Usage: python tools/check_course.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"

LESSON_SECTIONS = [
    "Learning Objectives", "Prerequisites", "Introduction and Concepts",
    "Linux Command Reference", "PowerShell Command Reference",
    "Detailed Command Explanations", "Syntax and Parameters", "Practical Demonstrations",
    "Linux vs PowerShell Comparison", "Real-World IT Scenarios", "Cybersecurity Application",
    "Network Analyst Application", "System Administrator Application", "Common Mistakes",
    "Troubleshooting Guide", "Hands-on Lab", "Practice Questions", "Quiz", "Homework",
    "Professional Tips", "Command Cheat Sheet", "Completion Checklist", "Further Reading",
]
LAB_SECTIONS = [
    "Objective", "Required Environment", "Initial Conditions", "Step-by-Step Instructions",
    "Expected Results", "Verification Steps", "Troubleshooting", "Questions", "Solution",
]
PLACEHOLDERS = re.compile(r"coming soon|lorem ipsum|\bTODO\b|\bTBD\b|placeholder text", re.I)
MIN_LESSON_WORDS = 3500


def h2_headings(text: str) -> set[str]:
    return {m.group(1).strip() for m in re.finditer(r"^##\s+(.+?)\s*$", text, re.M)}


def section_body(text: str, heading: str) -> str:
    m = re.search(rf"^##\s+{re.escape(heading)}\s*$(.*?)(?=^##\s|\Z)", text, re.M | re.S)
    return m.group(1) if m else ""


def check_lesson(day: dict, nav: str, errors: list[str]) -> None:
    num = f"{day['day']:02d}"
    rel = f"course/{day['module']}/day-{num}.md"
    path = DOCS / rel
    if not path.exists():
        errors.append(f"Day {num}: lesson file missing ({rel})")
        return
    text = path.read_text(encoding="utf-8")
    heads = h2_headings(text)
    for sec in LESSON_SECTIONS:
        if sec not in heads:
            errors.append(f"Day {num}: missing section '## {sec}'")
    if not re.search(r"^#\s+Day\s+" + num, text, re.M):
        errors.append(f"Day {num}: H1 title must start with 'Day {num}'")
    for token in ("Difficulty", "Estimated time"):
        if token not in text:
            errors.append(f"Day {num}: overview must state '{token}'")
    if "Expected output" not in text:
        errors.append(f"Day {num}: no 'Expected output' blocks found")
    questions = re.findall(r"^\d+\.\s", section_body(text, "Practice Questions"), re.M)
    if len(questions) < 10:
        errors.append(f"Day {num}: only {len(questions)} practice questions (need >= 10)")
    if "Practice answers" not in section_body(text, "Practice Questions"):
        errors.append(f"Day {num}: practice questions have no answer block")
    quiz_answers = section_body(text, "Quiz").count("Answer and explanation")
    if quiz_answers < 5:
        errors.append(f"Day {num}: quiz has {quiz_answers} answers (need >= 5)")
    words = len(re.findall(r"\w+", text))
    if words < MIN_LESSON_WORDS:
        errors.append(f"Day {num}: lesson too short ({words} words, need >= {MIN_LESSON_WORDS})")
    if PLACEHOLDERS.search(text):
        errors.append(f"Day {num}: placeholder text found")
    if rel not in nav:
        errors.append(f"Day {num}: {rel} is not in mkdocs.yml nav")

    lab_rel = f"labs/lab-{num}.md"
    lab = DOCS / lab_rel
    if not lab.exists():
        errors.append(f"Day {num}: lab file missing ({lab_rel})")
    else:
        lab_text = lab.read_text(encoding="utf-8")
        lab_heads = h2_headings(lab_text)
        for sec in LAB_SECTIONS:
            if sec not in lab_heads:
                errors.append(f"Lab {num}: missing section '## {sec}'")
        if f"LAB-{num}" not in lab_text:
            errors.append(f"Lab {num}: Lab ID 'LAB-{num}' not stated")
        if PLACEHOLDERS.search(lab_text):
            errors.append(f"Lab {num}: placeholder text found")
        if lab_rel not in nav:
            errors.append(f"Lab {num}: {lab_rel} is not in mkdocs.yml nav")

    for extra in day.get("extras", []) or []:
        if extra.startswith("pdf:"):
            continue  # PDFs are generated in CI
        if not (ROOT / extra).exists():
            errors.append(f"Day {num}: listed extra missing ({extra})")


def main() -> int:
    plan = yaml.safe_load((ROOT / "course-plan.yml").read_text(encoding="utf-8"))
    nav = (ROOT / "mkdocs.yml").read_text(encoding="utf-8")
    errors: list[str] = []
    published = [d for d in plan["days"] if d.get("status") == "published"]

    days = [d["day"] for d in plan["days"]]
    if days != list(range(1, 31)):
        errors.append("course-plan.yml must list days 1..30 in order")
    # Published days must be a contiguous prefix (no gaps).
    pub_nums = [d["day"] for d in published]
    if pub_nums != list(range(1, len(pub_nums) + 1)):
        errors.append(f"published days are not contiguous from Day 01: {pub_nums}")

    for day in published:
        check_lesson(day, nav, errors)

    for script in list((ROOT / "scripts").rglob("*.sh")) + list((ROOT / "scripts").rglob("*.ps1")):
        if PLACEHOLDERS.search(script.read_text(encoding="utf-8")):
            errors.append(f"{script.relative_to(ROOT)}: placeholder text found")

    print(f"Published days: {len(published)}/30")
    if errors:
        print(f"FAILED: {len(errors)} problem(s)")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("All course content checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
