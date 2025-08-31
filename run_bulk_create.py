#!/usr/bin/env python
"""
Run the bulk product creation script
"""

import subprocess
import sys

# Run the script with option 1
process = subprocess.Popen(
    [sys.executable, 'create_all_products.py'],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True
)

# Send option 1 to create products
output, _ = process.communicate(input='1\n')
print(output)