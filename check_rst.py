#!/usr/bin/env python3
"""
Validate RST documentation in CMake bracket comments.

Extracts RST blocks from #[==[.rst: ... #]==] comments and validates
them using rstcheck.

Usage:
    python check_rst.py [--verbose]

Requires:
    pip install rstcheck
"""

import re
import subprocess
import sys
from pathlib import Path


RST_BLOCK_PATTERN = re.compile(r'#\[==\[\.rst:\n(.*?)#\]==\]', re.DOTALL)


def extract_rst_blocks(cmake_file: Path) -> list[tuple[str, int]]:
    """Extract RST blocks with their starting line numbers."""
    content = cmake_file.read_text()
    blocks = []
    for match in RST_BLOCK_PATTERN.finditer(content):
        # Calculate line number where block starts
        line_num = content[:match.start()].count('\n') + 1
        blocks.append((match.group(1), line_num))
    return blocks


def check_file(cmake_file: Path, verbose: bool = False) -> list[str]:
    """Check RST blocks in a single file. Returns list of error messages."""
    blocks = extract_rst_blocks(cmake_file)
    if not blocks:
        return []

    errors = []
    for rst_content, start_line in blocks:
        result = subprocess.run(
            ['rstcheck', '--config', str(cmake_file.parent / '.rstcheck.cfg'), '-'],
            input=rst_content,
            text=True,
            capture_output=True
        )

        if result.returncode != 0:
            # Parse error lines and adjust line numbers
            for line in result.stderr.split('\n'):
                if '<stdin>:' in line:
                    # Extract line number from error and adjust
                    match = re.match(r'<stdin>:(\d+):', line)
                    if match:
                        relative_line = int(match.group(1))
                        absolute_line = start_line + relative_line
                        adjusted = line.replace(
                            f'<stdin>:{relative_line}:',
                            f'{cmake_file}:{absolute_line}:'
                        )
                        errors.append(adjusted)
                elif line and 'Success!' not in line and 'Error!' not in line:
                    errors.append(f'{cmake_file}: {line}')

    if verbose and not errors:
        print(f'  {cmake_file.name}: OK')

    return errors


def main():
    verbose = '--verbose' in sys.argv or '-v' in sys.argv

    script_dir = Path(__file__).parent
    cmake_files = sorted(script_dir.glob('*.cmake'))

    if verbose:
        print(f'Checking {len(cmake_files)} CMake files for RST issues...\n')

    all_errors = []
    for cmake_file in cmake_files:
        errors = check_file(cmake_file, verbose)
        all_errors.extend(errors)

    if all_errors:
        print('\nRST validation errors:')
        for error in all_errors:
            print(f'  {error}')
        sys.exit(1)
    else:
        print('All RST documentation is valid.')
        sys.exit(0)


if __name__ == '__main__':
    main()
