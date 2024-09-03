#!/bin/bash
. import.sh strict log arguments

DEBUG_REASONING="no" # Set to yes to turn step-by-step reasoning
LANGUAGE="English"
CUSTOM_PROMPT=""

NL=$'\n' # New line

main() {
  if [ $# -lt 1 ]; then
    echo "Usage: $0 input_file unit_file..."
    exit 1
  fi

  local input_file="$1" # File with data
  shift 1

  local answers_file="${input_file%.md}-critique.md" # File to store answers into

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
          echo "Below is question enclosed in <question></question> tag, which must be answered."
          echo "Then additional instructions follow in <instruction></instruction> tag."
          echo "Then document, for which question must be answered, in <document></document> tag."
          echo "<document>"
          cat $input_file
          echo "</document>"
          echo "<question>$question</question>"
          echo
          echo "<instruction>Repeat the question, in $LANGUAGE language, in <question>the qeustion</question>."
          echo "Respond in $LANGUAGE language."
          echo "Carefuly understand startup documentation, then answer to question."
          echo "Write comments helpful for founder or investor in <comment></comment> tag."
          echo "Write hints or insights for founder <hints></hints> tag."
          echo "If you uncertain or need additional data to answer the question, write them in <needs-answers>request</need-answers>."
          echo "The order of tags is:"
          echo "<question>question</question>"
          [ "$DEBUG_REASONING" == "no" ] || echo "<steps>step-by-step reasning of 3 diffirent experts in startap and business development</steps>"
          echo "<answer>Anwser for question as summary of answers of 3 experts</answer>"
          echo "<comments>comments</comments>"
          echo "<hints>Hints from 3 different experts in startups how to address mentioned issues.</hints>"
          echo "<needs-answers>request for additional information, if necessary to anwer the question</need-answers>"

          echo "${CUSTOM_PROMPT:-}"
          [ "$DEBUG_REASONING" == "no" ] || echo "Before writing the answer, write, in $LANGUAGE language, step-by-step reasoning in a <steps>steps performed to make conclusiion</steps> tag first."
          echo "</instruction>"
          echo "Respond to the question in <question></question> tag and follow instructions in <instruction></instruction> tag."
        } | aichat -r startup-critic
        question=""
        echo "</reply>$NL"
      fi
    done < "$unit_file" | tee "$answers_file"

  done

}

arguments::parse \
   "-d|--debug-reasoning)DEBUG_REASONING;Yes" \
   "-l|--language)LANGUAGE;String" \
   "-c|--custom-prompt)CUSTOM_PROMPT;String" \
   "-m|--repace-tags-by-markdown)REPLACE_TAGS_BY_MARKDOWN;Yes" \
   -- \
   "${@:+$@}"

main "${ARGUMENTS[@]}" || panic "Command failed with arguments \"${ARGUMENTS[*]}\"." || exit $?

exit 0

#>> Critique the document in markdown format using ollama and set of questions.
#>>
#>> Usage: critique.sh [OPTIONS] DOCUMENT_MD CRITIC_QUESTIONS_MD[...]
#>>
#>> Options:
#>>   -h | --help  show this help text.
#>>   --man        show documentation.
#>>   -d | --debug-reasoning        Turn on step-by-step reasoning in comments.
#>>   -l | --lang LANGUAGE          Ask AI to respond in given language. Default value: English.
#>>   -c | --custom-prompt TEXT     Add this text to the prompt.
