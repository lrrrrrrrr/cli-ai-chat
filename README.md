# NerdChat CLI

NerdChat CLI is a command-line chat tool for interacting with AI chat providers like **DeepSeek** and **OpenAI**. 
This script supports dynamic provider selection, model fetching, and chat conversation history management—all in a colorful and easy-to-use interface.

---

## Features

- **Provider Support**: Choose between DeepSeek and OpenAI.
- **Dynamic API Key Handling**: Enter your API keys only if needed.
- **Model Selection**: Fetch and select models dynamically from OpenAI or predefined DeepSeek models.
- **Conversation History**: Saves your chat history to a local JSON file for reference.
- **Colorful Output**: Differentiate between user, assistant, and system messages with colors.

---

## Requirements

- **Bash**: Version 4.0 or higher.
- **Utilities**:
  - [jq](https://stedolan.github.io/jq/) (for JSON processing)
  - curl (for making API requests)

---

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/lrrrrrrrr/cli-ai-chat.git
   cd cli-ai-chat
   ```

2. Ensure the script has execution permissions:

   ```bash
   chmod +x chat.sh
   ```

3. Install dependencies if not already installed:

   - For Ubuntu/Debian:
     ```bash
     sudo apt update
     sudo apt install -y jq curl
     ```

   - For macOS (using Homebrew):
     ```bash
     brew install jq curl
     ```

4. Run the script:
   ```bash
   ./chat.sh
   ```

---

## Usage

1. **Provider Selection**: On startup, choose your AI provider:
   - `DeepSeek` or `OpenAI`.

2. **API Key Setup**: If an API key is missing, the script prompts you to enter it.

3. **Model Selection**: For OpenAI, dynamically fetch and select models. For DeepSeek, predefined models are available.

4. **Chat**: Type messages to interact with the assistant. Use the following commands:

   - `/openai`: Switch to OpenAI.
   - `/deepseek`: Switch to DeepSeek.
   - `/models`: Re-select the model.
   - `/quit`: Exit the script.

5. **Conversation History**: Chat history is automatically saved in `chat_history.json`.

---

## Example

```bash
$ ./chat.sh

=== NerdChat CLI (Provider: OPENAI, Model: gpt-3.5-turbo). Warning: For nerds only! ===

USER: Hi there!
ASSISTANT: Hello! How can I help you today?
(Type your message, or use commands: /openai, /deepseek, /models, /quit)

Message> What's the weather today?
ASSISTANT: I can't fetch the weather, but I can tell you how to retrieve it using an API!
```

---

## Customization

1. **Disable Colors**: Set the color variables in the script to empty strings (`""`) for plain text output.
2. **Use a Specific Provider by Default**: Modify the script to set `provider` initially (e.g., `provider="openai"`).

---

## Contributing

Contributions are welcome! Feel free to submit a pull request or open an issue to discuss features or improvements.

---

## License

This project is licensed under the MIT License. 
