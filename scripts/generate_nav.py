#!/usr/bin/env python3
"""
Generate navigation structure for mkdocs.yml from ebook directory structure.
This script automatically discovers all markdown files and generates the nav section.
"""

import os
import re
from pathlib import Path

def extract_title_from_markdown(file_path):
    """Extract the first H1 title from a markdown file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            first_line = f.readline().strip()
            # Remove # and clean up
            if first_line.startswith('#'):
                title = first_line[1:].strip()
                return title
    except Exception:
        pass
    # Fallback: use filename
    return Path(file_path).stem.replace('_', ' ').title()

def get_chapter_number(filename):
    """Extract chapter number from filename for sorting."""
    match = re.search(r'(\d+)', filename)
    return int(match.group(1)) if match else 999

def generate_nav():
    """Generate navigation structure from ebook directory."""
    ebook_dir = Path('ebook')

    nav = []

    # Home page
    if (ebook_dir / 'index.md').exists():
        nav.append('  - Home: index.md')

    # About page
    if (ebook_dir / 'about.md').exists():
        nav.append('  - About: about.md')

    # Part I – Bash Fundamentals
    part1_dir = ebook_dir / 'part1_bash_fundamentals'
    if part1_dir.exists():
        nav.append('  - "Part I – Bash Fundamentals":')
        files = sorted(part1_dir.glob('*.md'), key=lambda x: get_chapter_number(x.name))
        for file in files:
            rel_path = f"part1_bash_fundamentals/{file.name}"
            title = extract_title_from_markdown(file)
            # Quote titles with colons
            if ':' in title:
                nav.append(f'    - "{title}": {rel_path}')
            else:
                nav.append(f'    - {title}: {rel_path}')

    # Part II – Advanced Security Scripting
    part2_dir = ebook_dir / 'part2_advanced_security'
    if part2_dir.exists():
        nav.append('  - "Part II – Advanced Security Scripting":')
        files = sorted(part2_dir.glob('*.md'), key=lambda x: get_chapter_number(x.name))
        for file in files:
            rel_path = f"part2_advanced_security/{file.name}"
            title = extract_title_from_markdown(file)
            if ':' in title:
                nav.append(f'    - "{title}": {rel_path}')
            else:
                nav.append(f'    - {title}: {rel_path}')

    # Part III – Real-World Projects
    part3_dir = ebook_dir / 'part3_real_world_projects'
    if part3_dir.exists():
        nav.append('  - "Part III – Real-World Projects":')
        files = sorted(part3_dir.glob('*.md'), key=lambda x: get_chapter_number(x.name))
        for file in files:
            rel_path = f"part3_real_world_projects/{file.name}"
            title = extract_title_from_markdown(file)
            if ':' in title:
                nav.append(f'    - "{title}": {rel_path}')
            else:
                nav.append(f'    - {title}: {rel_path}')

    # Appendices
    appendices_dir = ebook_dir / 'appendices'
    if appendices_dir.exists():
        nav.append('  - Appendices:')
        files = sorted(appendices_dir.glob('*.md'), key=lambda x: get_chapter_number(x.name))
        for file in files:
            rel_path = f"appendices/{file.name}"
            title = extract_title_from_markdown(file)
            if ':' in title:
                nav.append(f'    - "{title}": {rel_path}')
            else:
                nav.append(f'    - {title}: {rel_path}')

    return '\n'.join(nav)

if __name__ == '__main__':
    print(generate_nav())
