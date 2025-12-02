# Navigation Generation Scripts

These scripts automatically generate the navigation structure for `mkdocs.yml` based on the file structure in the `ebook/` directory.

## Scripts

### `generate_nav.py`

Generates the navigation YAML structure from markdown files. Outputs to stdout.

**Usage:**

```bash
python3 scripts/generate_nav.py
```

### `update_mkdocs_nav.py`

Automatically updates the `nav` section in `mkdocs.yml` with the generated navigation.

**Usage:**

```bash
python3 scripts/update_mkdocs_nav.py
# Or use the Makefile target:
make update-nav
```

## When to Use

Run `update_mkdocs_nav.py` (or `make update-nav`) when you:

- Add a new chapter file
- Add a new appendix
- Reorganize chapters
- Want to ensure navigation matches the file structure

## How It Works

1. Scans the `ebook/` directory structure
2. Finds all `.md` files in each part directory
3. Extracts titles from the first H1 heading in each file
4. Sorts files by chapter number (extracted from filename)
5. Generates the navigation structure matching the current `mkdocs.yml` format

## Notes

- The script preserves the structure: Home → About → Part I → Part II → Part III → Appendices
- Titles are extracted from the first `# Heading` in each markdown file
- Files are sorted numerically by chapter number in the filename
- Titles with colons are automatically quoted in YAML

## Integration

The navigation is automatically kept in sync with the file structure, just like the GitHub Actions workflow that builds PDF/EPUB/HTML formats.
