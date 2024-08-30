#!/bin/bash
set -ue

MARKDOWN_FILE="${1:?ERROR: Name of Markdown file to convert is required.}"
HTML_FILE="${MARKDOWN_FILE%.md}.html"
ANSWERS_FILE="${MARKDOWN_FILE%.md}-answers.md"

[ -f "$ANSWERS_FILE" ] || ANSWERS_FILE=""

[ "${MARKDOWN_FILE##*.}" == "md" ] || { echo "ERROR: Unexpected extension for the file: expected \"md\", actual: \"${MARKDOWN_FILE##*.}\" (\"$MARKDOWN_FILE\")." >&2; exit 1; }

echo "INFO: Converting \"$MARKDOWN_FILE\" to \"$HTML_FILE\"."

# Convert Markdow file to standalone HTML file
pandoc -f markdown "$MARKDOWN_FILE" ${ANSWERS_FILE:-} -o "$HTML_FILE" \
  --standalone \
  --css "answers.css" \
  --metadata title="SOS" \
  --template ./template.html \
  || { echo "ERROR: A problem with converting of \"$MARKDOWN_FILE\" to \"$HTML_FILE\"." >&2; exit 1; }
