#!/usr/bin/env bash

set -euo pipefail

# --------------------------------------------------------------------------- #
# Color settings (change or set to "" to disable)
# --------------------------------------------------------------------------- #
COLOR_RESET="\033[0m"
COLOR_USER="\033[1;34m"       # Blue for user input
COLOR_ASSISTANT="\033[1;32m"  # Green for assistant responses
COLOR_SYSTEM="\033[1;33m"     # Yellow for system messages

# --------------------------------------------------------------------------- #
# Initial variables
# --------------------------------------------------------------------------- #
provider=""
DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
selected_model=""

history_file="chat_history.json"

# --------------------------------------------------------------------------- #
# Load conversation history if it exists
# --------------------------------------------------------------------------- #
if [[ -f "$history_file" ]]; then
  messages=$(<"$history_file")
else
  messages='[]'
fi

# --------------------------------------------------------------------------- #
# Function: Provider selection
# --------------------------------------------------------------------------- #
select_provider() {
  echo -e "${COLOR_SYSTEM}Select a provider:${COLOR_RESET}"
  echo " [0] DeepSeek"
  echo " [1] OpenAI"
  while true; do
    read -rp "Enter the number of your choice: " choice
    case "$choice" in
      0) provider="deepseek"; break ;;
      1) provider="openai";   break ;;
      *) echo -e "${COLOR_SYSTEM}Invalid choice. Please enter 0 or 1.${COLOR_RESET}" ;;
    esac
  done
}

# --------------------------------------------------------------------------- #
# Function: Ensure the provider's API key is set
# --------------------------------------------------------------------------- #
ensure_api_key() {
  case "$provider" in
    deepseek)
      if [[ -z "$DEEPSEEK_API_KEY" ]]; then
        read -rp "DEEPSEEK_API_KEY is not set. Enter your DeepSeek API key: " input_key
        export DEEPSEEK_API_KEY="$input_key"
      fi
      ;;
    openai)
      if [[ -z "$OPENAI_API_KEY" ]]; then
        read -rp "OPENAI_API_KEY is not set. Enter your OpenAI API key: " input_key
        export OPENAI_API_KEY="$input_key"
      fi
      ;;
    *)
      echo -e "${COLOR_SYSTEM}Unknown provider: $provider${COLOR_RESET}"
      exit 1
      ;;
  esac
}

# --------------------------------------------------------------------------- #
# Function: Model selection
# --------------------------------------------------------------------------- #
select_model() {
  local uppercase_provider
  uppercase_provider=$(echo "$provider" | tr '[:lower:]' '[:upper:]')

  echo -e "${COLOR_SYSTEM}Fetching available models for provider: $uppercase_provider...${COLOR_RESET}"

  case "$provider" in
    deepseek)
      # Static list
      available_models=("deepseek-chat" "deepseek-reasoner")
      echo -e "${COLOR_SYSTEM}Available DeepSeek Models:${COLOR_RESET}"
      ;;
    openai)
      ensure_api_key
      local response
      response=$(curl -sS https://api.openai.com/v1/models \
        -H "Authorization: Bearer $OPENAI_API_KEY")
      local error
      error=$(echo "$response" | jq -r '.error.message? // empty')
      if [[ -n "$error" ]]; then
        echo -e "${COLOR_SYSTEM}OpenAI Error: $error${COLOR_RESET}"
        return 1
      fi

      # Collect model IDs (without using mapfile)
      available_models=()
      while IFS= read -r line; do
        available_models+=("$line")
      done < <(echo "$response" | jq -r '.data[] | .id' | sort)

      echo -e "${COLOR_SYSTEM}Available OpenAI Models:${COLOR_RESET}"
      ;;
    *)
      echo -e "${COLOR_SYSTEM}Unknown provider: $provider${COLOR_RESET}"
      return 1
      ;;
  esac

  # Show models
  for i in "${!available_models[@]}"; do
    echo "[$i] ${available_models[$i]}"
  done

  # Prompt user
  while true; do
    read -rp "Select a model (enter the number): " model_choice
    if [[ "$model_choice" =~ ^[0-9]+$ ]] && (( model_choice >= 0 && model_choice < ${#available_models[@]} )); then
      selected_model="${available_models[$model_choice]}"
      echo -e "${COLOR_SYSTEM}Selected model: ${selected_model}${COLOR_RESET}"
      break
    else
      echo -e "${COLOR_SYSTEM}Invalid choice. Please enter a valid number.${COLOR_RESET}"
    fi
  done
}

# --------------------------------------------------------------------------- #
# Function: Remove any literal "\033..." or "\x1B..." sequences in text
# --------------------------------------------------------------------------- #
sanitize_ansi() {
  sed -E 's/\\033\[[0-9;]*m//g; s/\x1B\[[0-9;]*m//g'
}

# --------------------------------------------------------------------------- #
# Function: Pretty-print the entire conversation
# --------------------------------------------------------------------------- #
print_conversation() {
  clear
  local uppercase_provider
  uppercase_provider=$(echo "$provider" | tr '[:lower:]' '[:upper:]')

  echo -e "${COLOR_SYSTEM}=== NerdChat CLI (Provider: ${uppercase_provider}, Model: ${selected_model}). Warning: For nerds only! ===${COLOR_RESET}"

  # Extract lines from JSON, remove any leftover ANSI codes, reapply our own.
  echo "$messages" | jq -r '
    .[] |
    if .role == "user" then
      "USER: " + .content
    elif .role == "assistant" then
      "ASSISTANT: " + .content
    else
      (.role|ascii_upcase) + ": " + .content
    end
  ' | sanitize_ansi | while IFS= read -r line; do
    if [[ "$line" =~ ^USER:\  ]]; then
      # User lines in blue
      echo -e "${COLOR_USER}${line}${COLOR_RESET}"
    elif [[ "$line" =~ ^ASSISTANT:\  ]]; then
      # Assistant lines in green
      echo -e "${COLOR_ASSISTANT}${line}${COLOR_RESET}"
    else
      # System or other roles in yellow
      echo -e "${COLOR_SYSTEM}${line}${COLOR_RESET}"
    fi
  done
  echo ""
  echo -e "${COLOR_SYSTEM}(Type your message, or use commands: /openai, /deepseek, /models, /clear, /quit)${COLOR_RESET}"
}

# --------------------------------------------------------------------------- #
# Function: Call DeepSeek Chat API
# --------------------------------------------------------------------------- #
call_deepseek() {
  local conversation="$1"
  ensure_api_key

  local request_body
  request_body=$(jq -n --argjson conv "$conversation" --arg model "$selected_model" '
    {
      model: $model,
      messages: $conv
    }')

  local response
  response=$(curl -sS https://api.deepseek.com/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
    -d "$request_body")

  local error
  error=$(echo "$response" | jq -r '.error.message? // empty')
  if [[ -n "$error" ]]; then
    echo -e "${COLOR_SYSTEM}DeepSeek Error: $error${COLOR_RESET}"
    return 1
  fi

  local content
  content=$(echo "$response" | jq -r '.choices[0].message.content // empty')
  if [[ -z "$content" ]]; then
    content="(No response from DeepSeek.)"
  fi
  echo "$content"
}

# --------------------------------------------------------------------------- #
# Function: Call OpenAI Chat Completion API
# --------------------------------------------------------------------------- #
call_openai() {
  local conversation="$1"
  ensure_api_key

  local request_body
  request_body=$(jq -n \
    --argjson conv "$conversation" \
    --arg model "$selected_model" '
    {
      model: $model,
      messages: $conv
    }'
  )

  local response
  response=$(curl -sS https://api.openai.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$request_body")

  local error
  error=$(echo "$response" | jq -r '.error.message? // empty')
  if [[ -n "$error" ]]; then
    echo -e "${COLOR_SYSTEM}OpenAI Error: $error${COLOR_RESET}"
    return 1
  fi

  local content
  content=$(echo "$response" | jq -r '.choices[0].message.content // empty')
  if [[ -z "$content" ]]; then
    content="(No response from OpenAI.)"
  fi
  echo "$content"
}

# --------------------------------------------------------------------------- #
# MAIN PROGRAM
# --------------------------------------------------------------------------- #

# 1. If no provider chosen, ask user
if [[ -z "$provider" ]]; then
  select_provider
fi

# 2. Ensure that provider's API key is set
ensure_api_key

# 3. If no model selected, prompt user
if [[ -z "$selected_model" ]]; then
  select_model
fi

# 4. Main loop
while true; do
  print_conversation

  read -rp "Message> " user_input

  # Slash commands
  if [[ "$user_input" =~ ^/ ]]; then
    case "$user_input" in
      /quit)
        echo -e "${COLOR_SYSTEM}Goodbye!${COLOR_RESET}"
        exit 0
        ;;
      /deepseek)
        provider="deepseek"
        selected_model=""
        ensure_api_key
        echo -e "${COLOR_SYSTEM}Switched to DeepSeek. Now select a model.${COLOR_RESET}"
        ;;
      /openai)
        provider="openai"
        selected_model=""
        ensure_api_key
        echo -e "${COLOR_SYSTEM}Switched to OpenAI. Now select a model.${COLOR_RESET}"
        ;;
      /models)
        select_model
        ;;
      /clear)
        messages='[]'
        rm -f "$history_file"
        echo -e "${COLOR_SYSTEM}Conversation history cleared.${COLOR_RESET}"
        ;;
      *)
        echo -e "${COLOR_SYSTEM}Unknown command: $user_input${COLOR_RESET}"
        ;;
    esac
    continue
  fi

  # Append user message
  messages=$(echo "$messages" | jq --arg content "$user_input" '. + [{"role":"user","content":$content}]')

  # Call the right API
  case "$provider" in
    deepseek) assistant_resp="$(call_deepseek "$messages" || true)" ;;
    openai)   assistant_resp="$(call_openai "$messages" || true)"   ;;
    *)        assistant_resp="(No valid provider selected.)"        ;;
  esac

  # Append assistant response
  messages=$(echo "$messages" | jq --arg content "$assistant_resp" '. + [{"role":"assistant","content":$content}]')

  # Save
  echo "$messages" > "$history_file"
done