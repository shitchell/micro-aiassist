# micro-aiassist

An AI-assisted coding plugin for the micro editor that provides GitHub Copilot-like functionality.

## Features

- **Real-time Code Suggestions**: Get intelligent code completions as you type
- **Multiple Display Options**:
  - Ghost text (inline suggestions)
  - Popup window (for multi-line suggestions)
  - Dedicated pane (persistent view)
- **Code Explanation**: Get AI explanations of selected code
- **Flexible Provider Support**: Works with OpenAI or Anthropic APIs
- **Fully Configurable**: Customize to your preferences

## Installation

From within micro:

```
> plugin install aiassist
```

Manual installation:

```bash
git clone https://github.com/yourusername/micro-aiassist ~/.config/micro/plug/aiassist
```

## Setup

After installation, you'll need to set up your API key:

```
> aiConfig api_key YOUR_API_KEY
```

## Usage

### Code Completion

Just type in any file, and AI Assist will suggest completions automatically (if auto-suggest is enabled). 

- Trigger completion manually: Press `Alt-]`
- Accept suggestion: Press `Tab`
- Dismiss suggestion: Press `Esc` or continue typing

### Code Explanation

1. Select code you want to understand
2. Press `Alt-e`
3. View the explanation in a new pane

### Configure Display Mode

Choose how suggestions appear:

```
> aiDisplayMode ghost   # Inline suggestions
> aiDisplayMode popup   # Multi-line popup window
> aiDisplayMode pane    # Dedicated suggestion pane
> aiDisplayMode auto    # Auto-select based on suggestion length (default)
```

## Configuration

AI Assist can be configured through the `aiConfig` command:

```
> aiConfig api_provider openai
> aiConfig model gpt-4-turbo
> aiConfig temperature 0.7
```

Or by editing your `settings.json`:

```json
{
    "aiassist.api_key": "your-api-key",
    "aiassist.api_provider": "openai",
    "aiassist.model": "gpt-4-turbo",
    "aiassist.display_mode": "auto",
    "aiassist.auto_suggest": true,
    "aiassist.suggestion_delay": 500,
    "aiassist.max_context_lines": 15,
    "aiassist.temperature": 0.7,
    "aiassist.max_tokens": 1024
}
```

## Requirements

- micro editor v2.0.0 or newer
- Valid API key for OpenAI or Anthropic

## License

MIT