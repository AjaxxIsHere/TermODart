import 'dart:io';

import 'package:nemotron_bot/session.dart';
import 'package:test/test.dart';

void main() {
  test('ConversationSession serializes and restores chat turns', () async {
    final session = ConversationSession(systemPrompt: 'Be concise.');
    session.addUserMessage('Hello');
    session.addAssistantMessage('Hi there');

    final tempDir = await Directory.systemTemp.createTemp('nemotron_session_test_');
    final filePath = '${tempDir.path}/session.json';

    await session.saveToFile(filePath);
    final restored = await ConversationSession.loadFromFile(filePath);

    expect(restored.systemPrompt, 'Be concise.');
    expect(restored.turns, hasLength(2));
    expect(restored.turns.first.role, 'user');
    expect(restored.turns.first.content, 'Hello');
    expect(restored.turns.last.role, 'assistant');
    expect(restored.turns.last.content, 'Hi there');
  });

  test('formatTranscript renders readable roles', () {
    final session = ConversationSession(systemPrompt: 'Prompt');
    session.addUserMessage('How are you?');
    session.addAssistantMessage('I am ready.');

    final transcript = session.formatTranscript();

    expect(transcript, contains('USER: How are you?'));
    expect(transcript, contains('ASSISTANT: I am ready.'));
  });
}