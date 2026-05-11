Term Bot is a local LLM CLI built around `llamadart`.

## Quick Start

```bash
dart pub get
dart run bin/nemotron_bot.dart
```

## Useful Flags

```bash
dart run bin/nemotron_bot.dart --help
dart run bin/nemotron_bot.dart --model models/NVIDIA-Nemotron3-Nano-4B-Q4_K_M.gguf
dart run bin/nemotron_bot.dart --prompt "You are a patient tutor." --save-session sessions/demo.json
dart run bin/nemotron_bot.dart --load-session sessions/demo.json --history
```

## Notes

- Keep GGUF models in the `models/` directory or pass an explicit path with `--model`.
- Use `exit` to quit, `/history` to inspect the current conversation, `/save` to persist the session immediately, and `/reset` to clear the in-memory conversation.
