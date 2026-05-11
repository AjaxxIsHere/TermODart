import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_tui/dart_tui.dart';
import 'package:nemotron_bot/inference.dart';
import 'package:nemotron_bot/session.dart';
import 'package:nemotron_bot/tui/app.dart';
import 'package:nemotron_bot/tui/model.dart';
import 'package:nemotron_bot/tui/update.dart';
import 'package:path/path.dart' as p;

const _defaultSystemPrompt = 'You are a concise, highly capable terminal assistant.';

String _resolveDefaultModelPath(String currentDir) {
  final candidates = <String>[
    p.join(currentDir, 'models', 'NVIDIA-Nemotron3-Nano-4B-Q4_K_M.gguf'),
    p.join(currentDir, 'models', 'Qwen3.5-4B-UD-Q5_K_XL.gguf'),
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) return candidate;
  }

  return candidates.first;
}

ArgParser _buildParser() {
  return ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage information.')
    ..addOption('model', help: 'Path to a GGUF model file.')
    ..addOption('prompt', help: 'Override the system prompt.')
    ..addOption('load-session', help: 'Load a saved conversation from JSON.')
    ..addOption('save-session', help: 'Persist the conversation to JSON on exit.');
}

Future<void> main(List<String> arguments) async {
  final parser = _buildParser();
  final results = parser.parse(arguments);

  if (results['help'] as bool) {
    stdout.writeln('Nemotron Bot — Terminal AI Chat');
    stdout.writeln(parser.usage);
    return;
  }

  final currentDir = Directory.current.path;
  final modelPath = p.normalize(
    results['model']?.toString().trim().isNotEmpty == true
        ? results['model'].toString().trim()
        : _resolveDefaultModelPath(currentDir),
  );
  final modelFile = File(modelPath);
  final saveSessionPath = results['save-session']?.toString().trim();
  final loadSessionPath = results['load-session']?.toString().trim();
  final promptOverride = results['prompt']?.toString().trim();

  stderr.writeln('Nemotron Bot — Terminal AI Chat');
  stderr.writeln('Model path: ${modelFile.absolute.path}');

  if (!modelFile.existsSync()) {
    stderr.writeln('ERROR: Model file not found at ${modelFile.absolute.path}');
    stderr.writeln('Download a GGUF model or use --model <path>.');
    exit(1);
  }

  // Load or create conversation session
  final conversation = loadSessionPath == null
      ? ConversationSession(systemPrompt: promptOverride ?? _defaultSystemPrompt)
      : await ConversationSession.loadFromFile(
          loadSessionPath,
          fallbackSystemPrompt: promptOverride ?? _defaultSystemPrompt,
        );

  if (promptOverride != null && promptOverride.isNotEmpty) {
    conversation.systemPrompt = promptOverride;
  }

  // Load the model
  stderr.writeln('Loading model into RAM (10-30s)...');
  final inference = NemotronInference(
    modelPath: modelPath,
    conversation: conversation,
    systemPrompt: conversation.systemPrompt,
  );

  try {
    await inference.loadModel();
  } catch (e) {
    stderr.writeln('ERROR loading model: $e');
    exit(1);
  }

  stderr.writeln('Model loaded. Starting TUI...');

  // Register inference with the update module
  registerInference(inference);

  // Build initial state from existing conversation
  final initialMessages = conversation.turns.map((turn) {
    return ChatMessage(role: turn.role, content: turn.content);
  }).toList();

  final initialState = NemotronState(
    conversation: conversation,
    messages: initialMessages,
    modelLoaded: true,
    statusMessage: '',
  );

  // Start the TUI
  final appModel = NemotronAppModel(initialState);

  await Program(
    options: const ProgramOptions(
      altScreen: true,
      hideCursor: false,
    ),
    programOptions: [
      withMouseCellMotion(),
      withFps(60),
      withReportFocus(),
    ],
  ).run(appModel);

  // Cleanup
  _cleanup(inference, conversation, saveSessionPath);
}

void _cleanup(
  NemotronInference inference,
  ConversationSession conversation,
  String? saveSessionPath,
) {
  // Restore terminal
  stdout.writeln('');

  if (saveSessionPath != null && saveSessionPath.isNotEmpty) {
    try {
      final file = File(saveSessionPath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(conversation.toJson()),
      );
      stderr.writeln('Session saved to $saveSessionPath');
    } catch (e) {
      stderr.writeln('Failed to save session: $e');
    }
  }

  try {
    inference.dispose();
  } catch (_) {}

  stderr.writeln('Goodbye.');
}
