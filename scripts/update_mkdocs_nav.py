#!/usr/bin/env python3
"""
Update the nav section in mkdocs.yml with auto-generated navigation.
This script reads the current mkdocs.yml, replaces the nav section with
auto-generated navigation from the file structure.
"""

import os
import re
import sys
from pathlib import Path

# Add scripts directory to path for imports
script_dir = Path(__file__).parent
sys.path.insert(0, str(script_dir))

from generate_nav import generate_nav

def update_mkdocs_nav():
    """Update nav section in mkdocs.yml."""
    mkdocs_file = Path('mkdocs.yml')
    
    if not mkdocs_file.exists():
        print("Error: mkdocs.yml not found", file=sys.stderr)
        sys.exit(1)
    
    # Read current mkdocs.yml
    with open(mkdocs_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Generate new nav section
    new_nav = generate_nav()
    
    # Find and replace nav section
    # Pattern matches from "nav:" to the next top-level key (or end of file)
    pattern = r'(nav:\s*\n)(.*?)(\n(?:plugins|copyright|extra|theme|site_|repo_|docs_dir|site_dir|markdown_extensions):|\n\Z)'
    
    replacement = f'\\1{new_nav}\\n\\3'
    
    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    
    # Write back
    with open(mkdocs_file, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print("✓ Updated nav section in mkdocs.yml")
    # Count navigation items (lines in the generated nav)
    nav_lines = [line for line in new_nav.split('\n') if line.strip()]
    print(f"  Generated {len(nav_lines)} navigation items")

if __name__ == '__main__':
    # Change to repo root (parent of scripts directory)
    repo_root = Path(__file__).parent.parent
    os.chdir(repo_root)
    
    update_mkdocs_nav()

