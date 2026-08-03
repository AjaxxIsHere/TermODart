# Nemotron Bot

A minimal local LLM chat CLI built on [llamadart](https://pub.dev/packages/llamadart).

No TUI — just a plain prompt loop that streams model output to the terminal.

## Quick Start

```bash
dart pub get
dart run bin/nemotron_bot.dart
```

## Options

```bash
dart run bin/nemotron_bot.dart --model path/to/model.gguf
```

If `--model` is omitted, the app auto-detects a GGUF file in `models/`.

## In-App Commands

| Command  | Action                        |
| -------- | ----------------------------- |
| `/exit`  | Quit (also `/quit`, Ctrl+C)   |
| `/clear` | Reset the conversation memory |
| `/help`  | Show commands                 |

## Notes

- Keep GGUF models in the `models/` directory or pass an explicit path with `--model`.
- Ctrl+C interrupts the current response; pressing it again quits.
