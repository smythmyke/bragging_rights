#!/usr/bin/env python
"""
Run the create_products_oauth.py script with option 1 (create products)
"""

import subprocess
import sys

# Run the script with option 1
process = subprocess.Popen(
    [sys.executable, 'create_products_oauth.py'],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True
)

# Send option 1 to create products
output, _ = process.communicate(input='1\n')
print(output)