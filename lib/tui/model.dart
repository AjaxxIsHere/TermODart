import 'package:nemotron_bot/session.dart';

/// A single chat message displayed in the UI.
final class ChatMessage {
  final String role; // 'user' | 'assistant' | 'system'
  final String content;

  const ChatMessage({required this.role, required this.content});
}

/// Pure application state (data, no Elm wiring).
final class NemotronState {
  NemotronState({
    this.termWidth = 80,
    this.termHeight = 24,
    this.modelLoaded = false,
    this.isGenerating = false,
    this.statusMessage = '',
    this.messages = const [],
    this.streamingResponse = '',
    this.inputText = '',
    this.scrollOffset = 0,
    this.attachedFiles = const [],
    ConversationSession? conversation,
    this.inferenceSessionId = '',
  }) : conversation = conversation ?? ConversationSession(systemPrompt: '');

  // ── Terminal ─────────────────────────────────────────────────────────────
  final int termWidth;
  final int termHeight;

  // ── App state ────────────────────────────────────────────────────────────
  final bool modelLoaded;
  final bool isGenerating;
  final String statusMessage;

  // ── Chat data ────────────────────────────────────────────────────────────
  final List<ChatMessage> messages;
  final String streamingResponse;

  // ── Input ────────────────────────────────────────────────────────────────
  final String inputText;

  // ── Scroll ───────────────────────────────────────────────────────────────
  final int scrollOffset;

  // ── Sidebar ──────────────────────────────────────────────────────────────
  final List<String> attachedFiles;

  // ── Conversation (LLM context) ───────────────────────────────────────────
  final ConversationSession conversation;

  // ── Active inference session key ─────────────────────────────────────────
  final String inferenceSessionId;

  // ── Derived layout ───────────────────────────────────────────────────────

  int get sidebarWidth => termWidth ~/ 4;
  int get chatWidth => termWidth - sidebarWidth;
  int get headerHeight => 3;
  int get footerHeight => 5;
  int get mainHeight {
    final remaining = termHeight - headerHeight - footerHeight;
    return remaining > 0 ? remaining : 0;
  }

  // ── Conversation history buffer (last 8000 chars for LLM context) ───────

  String get conversationHistory {
    final transcript = conversation.formatTranscript();
    if (transcript.length <= 8000) return transcript;
    return transcript.substring(transcript.length - 8000);
  }

  // ── copyWith ─────────────────────────────────────────────────────────────

  NemotronState copyWith({
    int? termWidth,
    int? termHeight,
    bool? modelLoaded,
    bool? isGenerating,
    String? statusMessage,
    List<ChatMessage>? messages,
    String? streamingResponse,
    String? inputText,
    int? scrollOffset,
    List<String>? attachedFiles,
    ConversationSession? conversation,
    String? inferenceSessionId,
  }) =>
      NemotronState(
        termWidth: termWidth ?? this.termWidth,
        termHeight: termHeight ?? this.termHeight,
        modelLoaded: modelLoaded ?? this.modelLoaded,
        isGenerating: isGenerating ?? this.isGenerating,
        statusMessage: statusMessage ?? this.statusMessage,
        messages: messages ?? this.messages,
        streamingResponse: streamingResponse ?? this.streamingResponse,
        inputText: inputText ?? this.inputText,
        scrollOffset: scrollOffset ?? this.scrollOffset,
        attachedFiles: attachedFiles ?? this.attachedFiles,
        conversation: conversation ?? this.conversation,
        inferenceSessionId: inferenceSessionId ?? this.inferenceSessionId,
      );
}
