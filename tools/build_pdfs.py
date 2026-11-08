#!/usr/bin/env python3
"""Build the course PDFs reproducibly from the Markdown sources.

Output: docs/downloads/pdf/<name>.pdf (copied into the site by `mkdocs build`).

Each PDF is only built when its sources exist (for example the Networking guide
appears once Days 11-15 are published). Every PDF has a cover page, a table of
contents with page numbers, running headers/footers, page numbering, PDF
bookmarks and A4 layout. After building, each PDF is validated (page count and
expected text) so empty or TOC-only PDFs are never published.

Requires WeasyPrint (Pango) — available on Ubuntu runners; see .github/workflows.

Usage:
  python tools/build_pdfs.py            # build + validate
  python tools/build_pdfs.py --stub     # LOCAL ONLY: tiny stand-ins so `mkdocs build --strict`
                                        # can resolve download links without WeasyPrint.
"""
from __future__ import annotations

import argparse
import datetime as dt
import html
import re
import sys
from pathlib import Path

import markdown
import yaml

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
OUT = DOCS / "downloads" / "pdf"
CSS = ROOT / "tools" / "pdf.css"
COURSE = "Linux & PowerShell Professional Mastery"
TAGLINE = "Master the Command Line. Understand Your Systems. Secure Your Network. Automate Your Work."


def load_plan() -> dict:
    return yaml.safe_load((ROOT / "course-plan.yml").read_text(encoding="utf-8"))


def published_days(plan: dict) -> list[dict]:
    return [d for d in plan["days"] if d.get("status") == "published"]


def lesson_path(d: dict) -> Path:
    return DOCS / "course" / d["module"] / f"day-{d['day']:02d}.md"


def lab_path(d: dict) -> Path:
    return DOCS / "labs" / f"lab-{d['day']:02d}.md"


# ---------------------------------------------------------------- definitions
def pdf_definitions(plan: dict) -> list[dict]:
    pub = published_days(plan)
    pub_nums = {d["day"] for d in pub}
    gs = [DOCS / "getting-started" / f for f in
          ("index.md", "windows-setup.md", "ubuntu-setup.md", "wsl2.md",
           "powershell-install.md", "lab-environment.md")]
    lessons = [lesson_path(d) for d in pub]
    labs = [lab_path(d) for d in pub if lab_path(d).exists()]

    def days_in(nums: range) -> list[Path]:
        return [lesson_path(d) for d in pub if d["day"] in nums]

    defs = [
        {
            "file": "Linux-PowerShell-30-Day-Complete-Handbook.pdf",
            "title": "30-Day Complete Handbook",
            "sources": [DOCS / "course" / "index.md", *gs, *lessons,
                        DOCS / "careers" / "soc-analyst.md", DOCS / "careers" / "network-analyst.md",
                        DOCS / "careers" / "sysadmin.md"],
            "ready": bool(lessons),
            "min_pages": 20,
            "must_contain": ["Day 01"],
        },
        {
            "file": "Linux-Command-Cheat-Sheet.pdf",
            "title": "Linux Command Reference & Cheat Sheet",
            "sources": [DOCS / "reference" / "linux.md", DOCS / "reference" / "comparison.md"],
            "ready": True,
            "min_pages": 4,
            "must_contain": ["mkdir"],
        },
        {
            "file": "PowerShell-Command-Cheat-Sheet.pdf",
            "title": "PowerShell Command Reference & Cheat Sheet",
            "sources": [DOCS / "reference" / "powershell.md", DOCS / "reference" / "comparison.md"],
            "ready": True,
            "min_pages": 4,
            "must_contain": ["Get-ChildItem"],
        },
        {
            "file": "Networking-Troubleshooting-Guide.pdf",
            "title": "Networking & Troubleshooting Guide",
            "sources": [*days_in(range(11, 16)), DOCS / "careers" / "network-analyst.md"],
            "ready": set(range(11, 16)) <= pub_nums,
            "min_pages": 15,
            "must_contain": ["Day 11"],
        },
        {
            "file": "Cybersecurity-Command-Reference.pdf",
            "title": "Cybersecurity Command Reference",
            "sources": [*days_in(range(16, 21)), DOCS / "careers" / "soc-analyst.md"],
            "ready": set(range(16, 21)) <= pub_nums,
            "min_pages": 15,
            "must_contain": ["Day 16"],
        },
        {
            "file": "Practical-Lab-Workbook.pdf",
            "title": "Practical Lab Workbook",
            "sources": [DOCS / "getting-started" / "lab-environment.md", *labs],
            "ready": bool(labs),
            "min_pages": 6,
            "must_contain": ["LAB-01"],
        },
        {
            "file": "Final-Assessment.pdf",
            "title": "Final Assessment & Answer Key",
            "sources": [DOCS / "assessments" / "final-exam.md",
                        DOCS / "assessments" / "final-exam-answer-key.md"],
            "ready": (DOCS / "assessments" / "final-exam.md").exists(),
            "min_pages": 6,
            "must_contain": ["Final"],
        },
    ]
    return defs


# ---------------------------------------------------------------- markdown prep
FRONT_MATTER = re.compile(r"\A---\n.*?\n---\n", re.S)
TAB = re.compile(r'^(\s*)=== "([^"]+)"\s*$')
DETAILS = re.compile(r'^(\s*)\?\?\?\+?\s+(\w+)(\s+"[^"]*")?\s*$')
KEYS = re.compile(r"\+\+([a-z0-9+]+)\+\+", re.I)
ICON = re.compile(r":(material|fontawesome|octicons|simple)-[a-z0-9-]+:(\{[^}]*\})?")
ATTR = re.compile(r"\{\s*\.md-button[^}]*\}")
MDLINK = re.compile(r"\[([^\]]+)\]\((?!https?://)([^)]+)\)")


def prep_markdown(text: str) -> str:
    """Make Material-specific syntax print-friendly."""
    text = FRONT_MATTER.sub("", text)
    out: list[str] = []
    for line in text.splitlines():
        m = TAB.match(line)
        if m:
            # Tabs become a bold label; following content stays indented (rendered as a block below).
            out.append(f'{m.group(1)}!!! tab "{m.group(2)}"')
            continue
        m = DETAILS.match(line)
        if m:
            # Collapsible blocks are always expanded in print.
            out.append(f"{m.group(1)}!!! {m.group(2)}{m.group(3) or ''}")
            continue
        out.append(line)
    text = "\n".join(out)
    # Mermaid diagrams cannot render in WeasyPrint: print their (readable) source, labelled.
    text = re.sub(r"^(\s*)```mermaid\s*$",
                  r"\1*Diagram — shown rendered on the website; text form:*\n\n\1```text", text, flags=re.M)
    text = KEYS.sub(lambda k: "+".join(p.capitalize() for p in k.group(1).split("+")), text)
    text = ICON.sub("", text)
    text = ATTR.sub("", text)
    # Internal links become plain text in print (external links stay clickable).
    text = MDLINK.sub(lambda m: m.group(1), text)
    # Drop hero/grid HTML wrappers but keep inner Markdown.
    text = re.sub(r'<div class="(lpm-hero|grid cards)" markdown>|</div>', "", text)
    return text


MD_EXTENSIONS = [
    "abbr", "admonition", "attr_list", "def_list", "footnotes", "md_in_html", "tables", "toc",
    "pymdownx.superfences", "pymdownx.tasklist", "pymdownx.mark", "pymdownx.inlinehilite",
    "pymdownx.highlight",
]
MD_CONFIG = {
    "toc": {"permalink": False},
    "pymdownx.highlight": {"use_pygments": True, "noclasses": True, "pygments_style": "friendly"},
    "pymdownx.tasklist": {"custom_checkbox": False},
}


def md_to_html(text: str, prefix: str) -> str:
    md = markdown.Markdown(extensions=MD_EXTENSIONS, extension_configs=MD_CONFIG)
    body = md.convert(prep_markdown(text))
    # Make heading ids unique across the whole PDF.
    body = re.sub(r'id="([^"]+)"', lambda m: f'id="{prefix}-{m.group(1)}"', body)
    return body


# ---------------------------------------------------------------- document assembly
def build_html(defn: dict, version: str) -> str:
    chapters, toc = [], []
    for i, src in enumerate(p for p in defn["sources"] if p.exists()):
        raw = src.read_text(encoding="utf-8")
        body = md_to_html(raw, f"c{i}")
        h1 = re.search(r"<h1[^>]*>(.*?)</h1>", body, re.S)
        title = re.sub("<[^>]+>", "", h1.group(1)).strip() if h1 else src.stem
        anchor = f"chapter-{i}"
        body = re.sub(r"<h1([^>]*)>", f'<h1 id="{anchor}" class="chapter-title"\\1>', body, count=1) \
            if h1 else f'<h1 id="{anchor}" class="chapter-title">{html.escape(title)}</h1>' + body
        # Remove the now-duplicate id attribute produced by toc on the H1.
        body = re.sub(rf'<h1 id="{anchor}" class="chapter-title" id="[^"]+"', f'<h1 id="{anchor}" class="chapter-title"', body)
        chapters.append(f'<section class="chapter">{body}</section>')
        toc.append(f'<li><a href="#{anchor}">{html.escape(title)}</a></li>')

    today = dt.date.today().isoformat()
    cover = f"""
    <section class="cover">
      <div class="cover-logo">&gt;_</div>
      <p class="cover-course">{html.escape(COURSE)}</p>
      <h1 class="cover-title">{html.escape(defn['title'])}</h1>
      <p class="cover-tagline">{html.escape(TAGLINE)}</p>
      <p class="cover-meta">30 Days: From Beginner to Advanced IT Professional<br/>
         Ubuntu 24.04 LTS · Windows 11 · Windows PowerShell 5.1 · PowerShell 7.x</p>
      <p class="cover-version">{html.escape(version)} · Built {today}</p>
      <p class="cover-copy">Copyright © 2026 Linux &amp; PowerShell Professional Mastery contributors.
         Released under the MIT License.</p>
    </section>"""
    toc_html = f'<section class="toc"><h1 class="toc-title">Contents</h1><ol>{"".join(toc)}</ol></section>'
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
    <title>{html.escape(COURSE)} — {html.escape(defn['title'])}</title>
    <meta name="author" content="{html.escape(COURSE)} contributors">
    </head><body data-doc-title="{html.escape(defn['title'])}">
    {cover}{toc_html}{''.join(chapters)}</body></html>"""


def validate(pdf: Path, defn: dict) -> list[str]:
    from pypdf import PdfReader

    problems = []
    reader = PdfReader(str(pdf))
    pages = len(reader.pages)
    if pages < defn["min_pages"]:
        problems.append(f"{pdf.name}: only {pages} pages (expected >= {defn['min_pages']})")
    text = "".join((reader.pages[i].extract_text() or "") for i in range(min(pages, 60)))
    for needle in [COURSE.split(" & ")[0], *defn["must_contain"]]:
        if needle not in text:
            problems.append(f"{pdf.name}: expected text '{needle}' not found")
    if len(text.strip()) < 2000:
        problems.append(f"{pdf.name}: suspiciously little text ({len(text.strip())} chars)")
    print(f"  validated {pdf.name}: {pages} pages, {pdf.stat().st_size // 1024} KiB")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--stub", action="store_true", help="local only: write stand-in files for link checks")
    args = ap.parse_args()

    plan = load_plan()
    pub = published_days(plan)
    version = f"Edition {dt.date.today():%Y.%m.%d} · Days 01–{len(pub):02d} of 30"
    OUT.mkdir(parents=True, exist_ok=True)
    defs = pdf_definitions(plan)

    if args.stub:
        for d in defs:
            if d["ready"]:
                (OUT / d["file"]).write_bytes(b"%PDF-1.4\n% local stub - not for publishing\n")
        print("Wrote local stubs (do NOT publish).")
        return 0

    from weasyprint import CSS as WCSS, HTML  # imported late so --stub works without Pango

    stylesheet = WCSS(filename=str(CSS))
    problems: list[str] = []
    built = 0
    for d in defs:
        target = OUT / d["file"]
        if not d["ready"]:
            print(f"- skip {d['file']} (sources not yet published)")
            target.unlink(missing_ok=True)
            continue
        print(f"- building {d['file']}")
        HTML(string=build_html(d, version), base_url=str(DOCS)).write_pdf(str(target), stylesheets=[stylesheet])
        problems += validate(target, d)
        built += 1

    print(f"Built {built} PDF(s).")
    if problems:
        print("PDF VALIDATION FAILED:")
        for p in problems:
            print(f"  - {p}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
