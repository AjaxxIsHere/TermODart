import 'dart:convert';
import 'dart:io';

import 'package:llamadart/llamadart.dart';

class ConversationTurn {
  final String role;
  final String content;
  final DateTime createdAt;

  const ConversationTurn({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ConversationTurn.user(String content) {
    return ConversationTurn(
      role: 'user',
      content: content,
      createdAt: DateTime.now().toUtc(),
    );
  }

  factory ConversationTurn.assistant(String content) {
    return ConversationTurn(
      role: 'assistant',
      content: content,
      createdAt: DateTime.now().toUtc(),
    );
  }

  factory ConversationTurn.fromJson(Map<String, dynamic> json) {
    return ConversationTurn(
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ConversationSession {
  final List<ConversationTurn> _turns;
  String systemPrompt;

  ConversationSession({
    List<ConversationTurn>? turns,
    required this.systemPrompt,
  }) : _turns = List.of(turns ?? const []);

  List<ConversationTurn> get turns => List.unmodifiable(_turns);

  void addUserMessage(String content) {
    _turns.add(ConversationTurn.user(content));
  }

  void addAssistantMessage(String content) {
    _turns.add(ConversationTurn.assistant(content));
  }

  void clear({bool keepSystemPrompt = true}) {
    _turns.clear();
    if (!keepSystemPrompt) {
      systemPrompt = '';
    }
  }

  String formatTranscript() {
    if (_turns.isEmpty) {
      return '(no conversation yet)';
    }

    final buffer = StringBuffer();
    for (final turn in _turns) {
      buffer.writeln('${turn.role.toUpperCase()}: ${turn.content}');
    }
    return buffer.toString().trimRight();
  }

  List<LlamaChatMessage> toChatMessages() {
    return _turns.map((turn) {
      final role = switch (turn.role) {
        'assistant' => LlamaChatRole.assistant,
        'system' => LlamaChatRole.system,
        _ => LlamaChatRole.user,
      };

      return LlamaChatMessage.fromText(role: role, text: turn.content);
    }).toList(growable: false);
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': 1,
      'systemPrompt': systemPrompt,
      'turns': _turns.map((turn) => turn.toJson()).toList(),
    };
  }

  static ConversationSession fromJson(Map<String, dynamic> json) {
    final turns = (json['turns'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ConversationTurn.fromJson)
        .toList(growable: false);

    return ConversationSession(
      turns: turns,
      systemPrompt: json['systemPrompt'] as String? ?? '',
    );
  }

  static Future<ConversationSession> loadFromFile(
    String path, {
    String fallbackSystemPrompt = '',
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      return ConversationSession(systemPrompt: fallbackSystemPrompt);
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return ConversationSession(systemPrompt: fallbackSystemPrompt);
    }

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final session = ConversationSession.fromJson(decoded);
      if (session.systemPrompt.isEmpty) {
        session.systemPrompt = fallbackSystemPrompt;
      }
      return session;
    }

    return ConversationSession(systemPrompt: fallbackSystemPrompt);
  }

  Future<void> saveToFile(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(toJson()));
  }
}