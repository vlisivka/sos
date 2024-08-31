#!/bin/bash
. import.sh strict log arguments

DEBUG_REASONING="no" # Set to yes to turn step-by-step reasoning
LANGUAGE="English"
CUSTOM_PROMPT=""
FAIL_IF_NO="no" # Fail if one of questions answered with "no" with exit code "42"
NEGATIVE_QUESTIONS="no" # Expect "no"s as proper answer
TRANSLATE_TO_LANGUAGE="" # Translate file with answers to given language
REPLACE_TAGS_BY_MARKDOWN="no" # Replace tags, such as <answer>, with corresponding Markdown, to render them properly by Pandoc
POSTPROCESS_ONLY="no" # Set to yes to perform postprocessing of answers file (only for development)

NL=$'\n' # New line

# Postprocess file with answers
postprocess() {
  local answers_file="$1"

  ## Replace <answer>yes/no</answer> by <answer data-answer="yes/no">yes/no</answer> for CSS color selector to work
  perl -pi -e 's/<answer>yes<\/answer>/<answer data-answer="yes">yes<\/answer>/; s/<answer>no<\/answer>/<answer data-answer="no">no<\/answer>/;' "$answers_file"

  [ -z "$TRANSLATE_TO_LANGUAGE" ] || {
    todo "Translate file with answers to \"$TRANSLATE_TO_LANGUAGE\" language."
  }

  [[ "$FAIL_IF_NO" == "no" ]] || {
    if [[ "$NEGATIVE_QUESTIONS" == "no" ]]
    then
      #todo "Exit with code 42 if answers file contains <answer data-answer=\"no\">."
      [ -z "$(grep --fixed-strings "<answer data-answer=\"no\">" "$answers_file")" ] || { error "One of questions is answered with \"no\"."; exit 42; }
    else
      #todo "Exit with code 42 if answers file contains <answer data-answer=\"yes\"> and negative questions flag set."
      [ -z "$(grep --fixed-strings "<answer data-answer=\"yes\">" "$answers_file")" ] || { error "One of questions is answered with \"no\"."; exit 42; }
    fi
  }

  [[ "$REPLACE_TAGS_BY_MARKDOWN" == "no" ]] || {
    todo "Translate tags to Markdown."
    #perl -pi -e '' "$answers_file"
  }

}

main() {
  if [ $# -lt 1 ]; then
    echo "Usage: $0 input_file unit_file..."
    exit 1
  fi

  local input_file="$1" # File with data
  shift 1

  local answers_file="${input_file%.md}-answers.md" # File to store answers into

  question="" # A single question from questions file

  # For all files with questions
  for unit_file in "$@"
  do
    echo "$NL---$NL## Questions and answers$NL"

    # Read questions separated by empty line one by one
    while IFS= read -r line; do
      # TODO: check first line for tags, like [ai:model]
      question="$question$line$NL"

      if (( ${#line} == 0 ))
      then
        # Ask AI to answer the question using data
        echo "<reply>"
        {
          echo "Below is question enclosed in <question></question> tag, which must be answered. Then additional instructions follow in <instruction></instruction> tag. Then document, for which question must be answered, in <document></document> tag."
          echo "<document>"
          cat $input_file
          echo "</document>"
          echo "<question>$question</question>"
          echo
          echo "<instruction>Repeat the question, in $LANGUAGE language, in <question>the qeustion</question>. Answer question with <answer>yes</answer> or <answer>no</answer>."
          echo "Respond in $LANGUAGE language."
          echo "Carefuly understand startup documentation, then answer to question with <answer>yes</answer> or <answer>no</answer>"
          echo "Write comments helpful for founder or investor in <comment></comment> tag."
          echo "If you uncertain or need additional data to answer the question, write them in <needs-answers>request</need-answers>."
          echo "The order of tags is:"
          echo "<question>question</question>"
          echo "<steps>reasoning steps, if asked</steps>"
          echo "<answer>yes/no</answer>"
          echo "<comments>comments</comments>"
          echo "<needs-answers>request for additional information</need-answers>"

          echo "${CUSTOM_PROMPT:-}"
          [ "$DEBUG_REASONING" == "no" ] || echo "Before writing the answer, write, in $LANGUAGE language, step-by-step reasoning in a <steps>steps performed to make conclusiion</steps> tag first."
          echo "</instruction>"
          echo "Respond to the question in <question></question> tag and follow instructions <instruction></instruction> tag."
        } | aichat -r unit-test
        question=""
        echo "</reply>$NL"
      fi
    done < "$unit_file" | tee "$answers_file"

    postprocess "$answers_file" || { error "Cannot postprocess answers in \"$answers_file\" file." ; return 1; }

  done

}

arguments::parse \
   "-d|--debug-reasoning)DEBUG_REASONING;Yes" \
   "-l|--language)LANGUAGE;String" \
   "-t|--translate-to)TRANSLATE_TO_LANGUAGE;String" \
   "-c|--custom-prompt)CUSTOM_PROMPT;String" \
   "-f|--fail-if-no)FAIL_IF_NO;Yes" \
   "-n|--negative-questions)NEGATIVE_QUESTIONS;Yes" \
   "-m|--repace-tags-by-markdown)REPLACE_TAGS_BY_MARKDOWN;Yes" \
   "-P|--postprocess-only)POSTPROCESS_ONLY;Yes" \
   -- \
   "${@:+$@}"

if [[ "$POSTPROCESS_ONLY" == "no" ]]
then
  main "${ARGUMENTS[@]}" || panic "Command failed with arguments \"${ARGUMENTS[*]}\"."
else
  postprocess "${ARGUMENTS[@]}" || { error "Cannot postprocess answers in \"${ARGUMENTS[@]}\" file." ; return 1; }
fi

exit 0

#>> Perform unit tests for documents in markdown format using ollama.
#>>
#>> Usage: unit-test.sh [OPTIONS] DOCUMENT_MD UNIT_TESTS_MD[...]
#>>
#>> Options:
#>>   -h | --help  show this help text.
#>>   --man        show documentation.
#>>   -d | --debug-reasoning        Turn on step-by-step reasoning in comments.
#>>   -l | --lang LANGUAGE          Ask AI to respond in given language. Default value: English.
#>>   -t | --translate-to LANGUAGE  Use AI to translate answers to given language. Default value: no translation.
#>>   -c | --custom-prompt TEXT     Add this text to the prompt.
#>>   -f | --fail-if-no             Fail when one of questions answered with "no" with exit code 42.
#>>   -n | --negative-questions     Expected answers are "no" instead of "yes", so "no" will be in green, while "yes" will be in red.
#>>   -m | --repace-tags-by-markdown Replace tags, such as <answer>, with Markdown formatting. Incompatible with --fail-if-no option.
