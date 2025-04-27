# AI Assist Plugin

The AI Assist plugin for micro editor provides an AI-powered coding assistant similar to GitHub Copilot.

## Features

- Real-time code suggestions as you type
- Multiple display modes for suggestions
- Code explanation
- Support for various AI providers (OpenAI, Anthropic)
- Configurable settings

## Installation

```
> plugin install aiassist
```

## Configuration

AI Assist requires an API key for either OpenAI or Anthropic. You can set this up using:

```
> aiConfig api_key YOUR_API_KEY
> aiConfig api_provider openai  # or anthropic
```

## Commands

- `aiComplete`: Generate code completion at cursor
- `aiExplain`: Explain selected code or current block
- `aiConfig [option] [value]`: Configure plugin settings
- `aiDisplayMode [mode]`: Set display mode for suggestions

## Display Modes

AI Assist offers three display modes:

1. **Ghost mode** (`ghost`): Inline suggestions
2. **Popup mode** (`popup`): Temporary popup for multi-line suggestions
3. **Pane mode** (`pane`): Dedicated pane for suggestions
4. **Auto mode** (`auto`): Automatically choose ghost for single-line and popup for multi-line

Set your preferred mode with `aiDisplayMode [mode]` or in settings.

## Keybindings

- `Alt-]`: Trigger code completion
- `Alt-e`: Explain current code
- `Tab`: Accept current suggestion (when active)

## Settings

You can configure the following settings:

```
aiassist.api_key: Your API key
aiassist.api_provider: API provider (openai or anthropic)
aiassist.model: Model to use (e.g., gpt-4-turbo, claude-3-opus-20240229)
aiassist.display_mode: Suggestion display mode (auto, ghost, popup, pane)
aiassist.auto_suggest: Enable auto-suggestions (true or false)
aiassist.suggestion_delay: Delay before auto-suggesting (ms)
aiassist.max_context_lines: Number of context lines to send to AI
aiassist.temperature: Temperature for AI generation
aiassist.max_tokens: Maximum tokens for completion
```

## Examples

To get code completion:
1. Place cursor where you want code
2. Press `Alt-]` or wait for auto-suggestion
3. Press `Tab` to accept suggestion

To explain code:
1. Select code you want explained
2. Press `Alt-e`
3. A new pane will open with the explanation