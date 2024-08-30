#!/bin/bash
set -uex

# Convert Markdown files to HTML on update of a markdown file in current directory
fswatch -0 --event "Updated" --include '\.md$' --exclude '\.html$' --recursive "$(pwd)" \
  | xargs -0 -I '{}' ./md_to_html.sh '{}'
