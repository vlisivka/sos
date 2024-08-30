#!/bin/bash
set -ue

find . -type f -name "*.md" -exec ./md_to_html.sh {} \;
