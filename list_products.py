#!/usr/bin/env python
"""
List existing in-app products to verify they were created
"""

import subprocess
import sys

# Run the script with option 2 (list products)
process = subprocess.Popen(
    [sys.executable, 'create_products_oauth.py'],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True
)

# Send option 2 to list products
output, _ = process.communicate(input='2\n')
print(output)