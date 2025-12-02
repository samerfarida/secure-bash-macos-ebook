# Contributing to Secure Bash for macOS

Thank you for your interest in contributing to this project! This document provides guidelines and instructions for contributing.

## How to Contribute

### Star the Repository

Show your support by starring this repo—it helps others discover the book.

### Report Issues

Found a typo, bug, or have a suggestion? Open an issue on GitHub with:

- A clear description of the issue
- Steps to reproduce (if applicable)
- Expected vs. actual behavior
- Any relevant screenshots or examples

### Suggest Improvements

Have ideas for new examples, chapters, or features? We'd love to hear them! Open an issue with the `enhancement` label.

### Contribute Content

Want to add examples, fix errors, or improve chapters?

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/your-improvement`)
3. **Make your changes**
4. **Run linting locally** (see below)
5. **Submit a pull request** with a clear description

All contributors will be recognized in future releases!

## Development Setup

### Prerequisites

- Node.js 18+ and npm 9+
- Python 3.11+ (for YAML linting)
- Git

### Installation

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/secure-bash-macos-ebook.git
cd secure-bash-macos-ebook

# Install linting dependencies
npm install
```

## Linting

All markdown files must pass linting checks before your pull request can be merged. The linting process checks:

- **Markdown formatting** - Consistent style, proper headings, spacing
- **Spelling** - Correct spelling with custom dictionary for technical terms
- **Links** - All internal and external links must be valid
- **YAML syntax** - All YAML files (workflows, configs) must be valid

### Running Linting Locally

Before submitting a pull request, run the linting checks locally:

```bash
# Run all linting checks
npm run lint

# Run individual checks
npm run lint:markdown      # Check markdown formatting
npm run spell-check        # Check spelling
npm run link-check         # Check all links
npm run lint:yaml          # Check YAML files

# Auto-fix markdown formatting issues (when possible)
npm run lint:markdown:fix
```

**Note**: Pre-commit hooks will automatically run linting checks when you commit. You can also test them manually:

```bash
# Test pre-commit hooks on all files
pre-commit run --all-files

# Test on staged files only
pre-commit run
```

### Linting Configuration

- **Markdown**: `.markdownlint.json` - Configured for ebook formatting
- **Spelling**: `cspell.json` - Includes technical terms and macOS-specific vocabulary
- **YAML**: `.yamllint.yml` - Standard YAML linting rules
- **Ignore patterns**: `.markdownlintignore` - Excludes generated files

### Common Linting Issues and Fixes

#### Markdown Formatting

**Issue**: Line too long

- **Fix**: Break long lines at 120 characters (code blocks and tables are exempt)

**Issue**: Missing blank line after heading

- **Fix**: Add a blank line after all headings

**Issue**: Inconsistent list markers

- **Fix**: Use dashes (`-`) for unordered lists consistently

**Issue**: Trailing spaces

- **Fix**: Remove trailing whitespace from lines

**Auto-fix available**: Run `npm run lint:markdown:fix` to automatically fix many formatting issues.

#### Spelling

**Issue**: Unknown word

- **Fix**: Add the word to `cspell.json` in the `words` array if it's a valid technical term
- Common additions: tool names, macOS-specific terms, project-specific terminology

**Example**:

```json
{
  "words": [
    "your-new-term",
    "another-term"
  ]
}
```

#### Links

**Issue**: Broken link

- **Fix**: Update the URL or remove the link if the resource no longer exists
- For internal links, ensure the file path is correct relative to the repository root

**Issue**: Link to non-existent file

- **Fix**: Create the file or update the link to point to an existing file

#### YAML

**Issue**: Incorrect indentation

- **Fix**: Use 2 spaces for indentation (no tabs)

**Issue**: Missing quotes

- **Fix**: Quote string values that contain special characters

### Pre-Commit Checklist

Before submitting your pull request, ensure:

- [ ] All linting checks pass (`npm run lint`)
- [ ] No spelling errors
- [ ] All links are valid
- [ ] YAML files are properly formatted
- [ ] Your changes follow the existing code style
- [ ] You've tested your changes (if applicable)
- [ ] Your commit messages are clear and descriptive

## Review Process

1. **Automated Checks**: When you open a pull request, GitHub Actions will automatically run all linting checks
2. **Review**: Your PR will be reviewed by maintainers
3. **Feedback**: Any requested changes will be communicated in the PR comments
4. **Merge**: Once approved and all checks pass, your PR will be merged
5. **Recognition**: Contributors are acknowledged in future releases

## Code of Conduct

- Be respectful and constructive in all interactions
- Focus on the content and ideas, not the person
- Help others learn and improve
- Follow the project's coding and documentation standards

## Questions?

If you have questions about contributing, feel free to:

- Open an issue with the `question` label
- Check existing issues and discussions
- Review the project documentation

Thank you for contributing to Secure Bash for macOS! 🎉
