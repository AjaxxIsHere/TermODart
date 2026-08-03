import 'dart:io';

import 'package:llamadart/llamadart.dart';
import 'package:path/path.dart' as p;

/// Known model files, tried in order when no `--model` flag is given.
const _defaultModelCandidates = <String>[
  'models/Qwen3.5-4B-UD-Q5_K_XL.gguf',
  'models/NVIDIA-Nemotron3-Nano-4B-Q4_K_M.gguf',
];

const _systemPrompt = 'You are a concise and highly capable Linux terminal assistant.';

void main(List<String> arguments) async {
  final modelPath = _resolveModelPath(arguments);

  if (!File(modelPath).existsSync()) {
    stderr.writeln('ERROR: Model file not found at ${p.absolute(modelPath)}');
    stderr.writeln('Download a GGUF model into models/ or pass --model <path>.');
    exit(1);
  }

  stderr.writeln('Loading model: ${p.basename(modelPath)} (this can take 10-30s)...');

  final backend = LlamaBackend();
  final engine = LlamaEngine(backend);
  final session = ChatSession(engine, systemPrompt: _systemPrompt);
  var generating = false;
  var quit = false;

  // Ctrl+C cancels the current generation; a second press quits.
  final sigintSub = ProcessSignal.sigint.watch().listen((_) {
    if (generating) {
      engine.cancelGeneration();
      stdout.writeln('\n[interrupted]');
    } else {
      quit = true;
      stdout.writeln();
    }
  });

  try {
    await engine.setNativeLogLevel(LlamaLogLevel.warn);
    await engine.loadModel(modelPath);

    stderr.writeln('Ready. Type a message (or /exit to quit).');

    while (!quit) {
      stdout.write('> ');
      final input = stdin.readLineSync();
      if (input == null) break; // EOF (e.g. Ctrl+D)

      final prompt = input.trim();
      if (prompt.isEmpty) continue;

      if (prompt == '/exit' || prompt == '/quit') break;
      if (prompt == '/clear') {
        session.reset();
        stdout.writeln('[conversation cleared]');
        continue;
      }
      if (prompt == '/help') {
        stdout.writeln('Commands: /exit, /quit, /clear, /help');
        continue;
      }

      generating = true;
      try {
        await for (final chunk
            in session.create([LlamaTextContent(prompt)])) {
          final content = chunk.choices.first.delta.content;
          if (content != null && content.isNotEmpty) {
            stdout.write(content);
            stdout.flush(); // Stream tokens in real time.
          }
        }
        stdout.writeln();
      } catch (e) {
        stderr.writeln('\nERROR: $e');
      } finally {
        generating = false;
      }
    }
  } catch (e, st) {
    stderr.writeln('\nERROR: $e');
    stderr.writeln(st);
  } finally {
    await sigintSub.cancel();
    await engine.dispose();
    stderr.writeln('Goodbye.');
  }
}

/// Returns the model path from `--model <path>` or auto-detects one.
String _resolveModelPath(List<String> arguments) {
  for (var i = 0; i < arguments.length - 1; i++) {
    if (arguments[i] == '--model' || arguments[i] == '-m') {
      final value = arguments[i + 1].trim();
      if (value.isNotEmpty) return p.normalize(value);
    }
  }

  for (final candidate in _defaultModelCandidates) {
    if (File(candidate).existsSync()) return p.normalize(candidate);
  }

  return p.normalize(_defaultModelCandidates.first);
}
