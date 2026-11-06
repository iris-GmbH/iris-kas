#!/usr/bin/env python3

# SPDX-License-Identifier: MIT
# Copyright (C) 2026 iris-GmbH infrared & intelligent sensors

"""Append skipped and failed Robot Framework test cases to a systemtest summary."""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path


content_dir = Path(sys.argv[1])
skipped_lines = ['', '## Skipped Robot Framework test cases']
failed_lines = ['', '## Failed Robot Framework test cases']

for report in sorted(content_dir.glob('*/results/output_xunit.xml')):
  skipped = []
  failed = []
  for testcase in ET.parse(report).iter('testcase'):
    for result_type, cases in (('skipped', skipped), ('failure', failed)):
      result = testcase.find(result_type)
      if result is not None:
        reason = result.get('message') or ' '.join(result.itertext()).strip() or 'No reason provided'
        cases.append((testcase.get('name', '<unnamed>'), reason))
  if skipped:
    skipped_lines.extend(['', f'### {report.parent.parent.name}'])
    skipped_lines.extend(f'- {name}: {reason}' for name, reason in skipped)
  if failed:
    failed_lines.extend(['', f'### {report.parent.parent.name}'])
    failed_lines.extend(f'- {name}: {reason}' for name, reason in failed)

if len(skipped_lines) == 2:
  skipped_lines.extend(['', 'No skipped Robot Framework test cases.'])
if len(failed_lines) == 2:
  failed_lines.extend(['', 'No failed Robot Framework test cases.'])

with (content_dir / 'systemtest-summary.md').open('a') as summary:
  summary.write('\n'.join(skipped_lines + failed_lines) + '\n')
