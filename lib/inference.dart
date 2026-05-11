import 'dart:async';

import 'package:llamadart/llamadart.dart';

import 'session.dart';

class ChatResponse {
  final String text;
  final Duration duration;

  const ChatResponse({required this.text, required this.duration});
}

class NemotronInference {
  final String modelPath;
  final ConversationSession conversation;
  final String systemPrompt;

  late final LlamaBackend _backend;
  late final LlamaEngine _engine;
  late final ChatSession _chatSession;
  bool _loaded = false;

  NemotronInference({
    required this.modelPath,
    required this.conversation,
    required this.systemPrompt,
    LlamaBackend? backend,
  }) : _backend = backend ?? LlamaBackend();

  Future<void> loadModel() async {
    if (_loaded) {
      return;
    }

    _engine = LlamaEngine(_backend);
    await _engine.loadModel(modelPath);
    _chatSession = ChatSession(
      _engine,
      systemPrompt: systemPrompt.isEmpty ? null : systemPrompt,
    );

    for (final message in conversation.toChatMessages()) {
      _chatSession.addMessage(message);
    }

    _loaded = true;
  }

  Future<ChatResponse> chat(String input) async {
    if (!_loaded) {
      throw StateError('Model has not been loaded yet.');
    }

    final stopwatch = Stopwatch()..start();
    final buffer = StringBuffer();

    await for (final chunk in _chatSession.create([LlamaTextContent(input)])) {
      final text = chunk.choices.first.delta.content ?? '';
      buffer.write(text);
    }

    stopwatch.stop();

    final responseText = buffer.toString().trim();
    conversation.addUserMessage(input);
    conversation.addAssistantMessage(responseText);

    return ChatResponse(text: responseText, duration: stopwatch.elapsed);
  }

  /// Returns a stream of token strings for incremental UI updates.
  /// Does NOT modify [conversation] — callers must manage session state.
  Stream<String> chatStream(String input) async* {
    if (!_loaded) {
      throw StateError('Model has not been loaded yet.');
    }

    await for (final chunk in _chatSession.create([LlamaTextContent(input)])) {
      final text = chunk.choices.first.delta.content ?? '';
      if (text.isNotEmpty) yield text;
    }
  }

  /// Reset the chat session, clearing all conversation context from the LLM.
  void clearSession() {
    _chatSession = ChatSession(
      _engine,
      systemPrompt: systemPrompt.isEmpty ? null : systemPrompt,
    );
  }

  Future<void> dispose() async {
    if (_loaded) {
      await _engine.dispose();
      _loaded = false;
    }
  }
}