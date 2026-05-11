import 'dart:async';

import 'package:dart_tui/dart_tui.dart';

import 'package:nemotron_bot/inference.dart';
import 'package:nemotron_bot/session.dart';
import 'messages.dart';
import 'model.dart';

// ── Mutable token buffer for streaming inference ────────────────────────────

final class _TokenBuffer {
  final _tokens = <String>[];
  bool _done = false;
  String? _error;
  String _fullResponse = '';
  StreamSubscription<String>? _subscription;

  void add(String token) {
    _tokens.add(token);
    _fullResponse += token;
  }

  List<String> drain() {
    final result = List<String>.of(_tokens);
    _tokens.clear();
    return result;
  }

  bool get isDone => _done && _tokens.isEmpty;
  bool get hasError => _error != null;
  String get fullResponse => _fullResponse;
  String? get error => _error;

  void markDone() => _done = true;
  void markError(String e) => _error = e;

  void cancel() {
    _subscription?.cancel();
    _subscription = null;
  }

  void attach(StreamSubscription<String> sub) => _subscription = sub;
}

final _activeBuffers = <String, _TokenBuffer>{};

// ── Public update function ───────────────────────────────────────────────────

/// Returns (newState, optionalCmd).
(NemotronState, Cmd?) nemotronUpdate(NemotronState state, Msg msg) {
  switch (msg) {
    // ── Lifecycle ─────────────────────────────────────────────────────────
    case QuitMsg() || InterruptMsg():
      return _quit(state);

    case WindowSizeMsg(:final width, :final height):
      return _handleResize(state, width, height);

    // ── Model lifecycle ───────────────────────────────────────────────────
    case ModelReadyMsg():
      return (state.copyWith(modelLoaded: true, statusMessage: ''), null);

    case ModelLoadErrorMsg(:final error):
      return (state.copyWith(statusMessage: 'Error: $error'), null);

    // ── Keyboard ──────────────────────────────────────────────────────────
    case KeyPressMsg(:final keyEvent):
      return _handleKey(state, keyEvent);

    // ── Mouse clicks ──────────────────────────────────────────────────────
    case MouseClickMsg(:final mouse):
      return _handleMouseClick(state, mouse);

    case MouseWheelMsg(:final mouse):
      return _handleScroll(state, mouse);

    // ── Send ──────────────────────────────────────────────────────────────
    case SendMsg(:final text):
      return _handleSend(state, text);

    case SendClickMsg():
      return _handleSend(state, state.inputText);

    // ── Sidebar actions ───────────────────────────────────────────────────
    case ClearClickMsg():
      return _handleClear(state);

    case SearchClickMsg():
      return (state.copyWith(statusMessage: 'Search: not yet implemented'), null);

    // ── Token streaming ───────────────────────────────────────────────────
    case TokensReceivedMsg(:final tokens):
      return _handleTokens(state, tokens);

    case GenerationCompleteMsg(:final fullResponse):
      return _handleGenerationComplete(state, fullResponse);

    case GenerationErrorMsg(:final error):
      return _handleGenerationError(state, error);

    case PollMsg():
      return _handlePoll(state);

    case _InferenceStartedMsg(:final sessionId, :final prompt):
      return _handleInferenceStarted(state, sessionId, prompt);

    // ── Scroll ────────────────────────────────────────────────────────────
    case ChatScrollMsg(:final delta):
      final clamped = (state.scrollOffset + delta).clamp(0, 99999999).toInt();
      return (state.copyWith(scrollOffset: clamped), null);

    default:
      return (state, null);
  }
}

// ── Private message: signals that the LLM stream has been set up ─────────────

final class _InferenceStartedMsg extends Msg {
  _InferenceStartedMsg(this.sessionId, this.prompt);
  final String sessionId;
  final String prompt;
}

// ── Internal handlers ────────────────────────────────────────────────────────

(NemotronState, Cmd?) _quit(NemotronState state) {
  if (state.inferenceSessionId.isNotEmpty) {
    _activeBuffers.remove(state.inferenceSessionId)?.cancel();
  }
  return (state, () => quit());
}

(NemotronState, Cmd?) _handleResize(NemotronState state, int w, int h) {
  return (state.copyWith(termWidth: w, termHeight: h), null);
}

(NemotronState, Cmd?) _handleKey(NemotronState state, TeaKey key) {
  final code = key.code;
  final text = key.text;

  if (code == KeyCode.rune && text == 'q' &&
      key.modifiers.contains(KeyMod.ctrl)) {
    return _quit(state);
  }

  if (code == KeyCode.enter) {
    return _handleSend(state, state.inputText);
  }

  if (code == KeyCode.backspace) {
    if (state.inputText.isEmpty) return (state, null);
    return (state.copyWith(
      inputText: state.inputText.substring(0, state.inputText.length - 1),
    ), null);
  }

  if (code == KeyCode.escape) {
    return (state.copyWith(inputText: ''), null);
  }

  if (code == KeyCode.rune && text.isNotEmpty) {
    if (state.isGenerating) return (state, null);
    return (state.copyWith(inputText: state.inputText + text), null);
  }

  if (code == KeyCode.space) {
    if (state.isGenerating) return (state, null);
    return (state.copyWith(inputText: '${state.inputText} '), null);
  }

  return (state, null);
}

(NemotronState, Cmd?) _handleMouseClick(NemotronState state, Mouse mouse) {
  final x = mouse.x;
  final y = mouse.y;
  final sw = state.sidebarWidth;

  if (x < sw && y >= state.headerHeight && y < state.termHeight - state.footerHeight) {
    final relY = y - state.headerHeight;
    final clearBtnY = _sidebarClearButtonY(state);
    final searchBtnY = _sidebarSearchButtonY(state);

    if (relY == clearBtnY && x >= 2 && x < 2 + 8) {
      return _handleClear(state);
    }
    if (relY == searchBtnY && x >= 2 && x < 2 + 8) {
      return (state.copyWith(statusMessage: 'Search: not yet implemented'), null);
    }
  }

  // Send button (footer, last row, aligned right)
  if (y == state.termHeight - 2 && x >= state.termWidth - 12 && x < state.termWidth - 2) {
    return _handleSend(state, state.inputText);
  }

  return (state, null);
}

(NemotronState, Cmd?) _handleScroll(NemotronState state, Mouse mouse) {
  final x = mouse.x;
  if (x < state.sidebarWidth) return (state, null);
  final delta = mouse.button == MouseButton.wheelUp ? -1 : 1;
  final clamped = (state.scrollOffset + delta).clamp(0, 99999999).toInt();
  return (state.copyWith(scrollOffset: clamped), null);
}

(NemotronState, Cmd?) _handleSend(NemotronState state, String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || state.isGenerating) return (state, null);

  return (
    state.copyWith(
      inputText: '',
      isGenerating: true,
      streamingResponse: '',
      statusMessage: '',
    ),
    _startInference(state, trimmed),
  );
}

(NemotronState, Cmd?) _handleClear(NemotronState state) {
  // Reset the LLM chat session to clear context
  _getInference()?.clearSession();

  return (
    state.copyWith(
      messages: const [],
      streamingResponse: '',
      scrollOffset: 0,
      inputText: '',
      conversation: ConversationSession(
        systemPrompt: state.conversation.systemPrompt,
      ),
      statusMessage: 'Conversation cleared.',
    ),
    null,
  );
}

(NemotronState, Cmd?) _handleInferenceStarted(
    NemotronState state, String sessionId, String prompt) {
  state.conversation.addUserMessage(prompt);
  final newMessages = [
    ...state.messages,
    ChatMessage(role: 'user', content: prompt),
  ];
  return (
    state.copyWith(
      messages: newMessages,
      inferenceSessionId: sessionId,
    ),
    _pollCmd(sessionId),
  );
}

(NemotronState, Cmd?) _handleTokens(NemotronState state, List<String> tokens) {
  return (
    state.copyWith(streamingResponse: state.streamingResponse + tokens.join()),
    _pollCmd(state.inferenceSessionId),
  );
}

(NemotronState, Cmd?) _handleGenerationComplete(
    NemotronState state, String fullResponse) {
  final text = fullResponse.trim();
  final conv = state.conversation;
  conv.addAssistantMessage(text);

  final newMessages = [
    ...state.messages,
    ChatMessage(role: 'assistant', content: text),
  ];

  _activeBuffers.remove(state.inferenceSessionId);

  return (
    state.copyWith(
      isGenerating: false,
      streamingResponse: '',
      messages: newMessages,
      conversation: conv,
      inferenceSessionId: '',
      scrollOffset: 99999999,
    ),
    null,
  );
}

(NemotronState, Cmd?) _handleGenerationError(NemotronState state, String error) {
  _activeBuffers.remove(state.inferenceSessionId);

  return (
    state.copyWith(
      isGenerating: false,
      streamingResponse: '',
      statusMessage: 'Error: $error',
      inferenceSessionId: '',
    ),
    null,
  );
}

(NemotronState, Cmd?) _handlePoll(NemotronState state) {
  final buffer = _activeBuffers[state.inferenceSessionId];
  if (buffer == null) {
    return (
      state.copyWith(isGenerating: false, inferenceSessionId: ''),
      null,
    );
  }

  final tokens = buffer.drain();
  if (tokens.isNotEmpty) {
    return (
      state.copyWith(streamingResponse: state.streamingResponse + tokens.join()),
      _pollCmd(state.inferenceSessionId),
    );
  }
  if (buffer.isDone) {
    return _handleGenerationComplete(state, buffer.fullResponse);
  }
  if (buffer.hasError) {
    return _handleGenerationError(state, buffer.error!);
  }
  return (state, _pollCmd(state.inferenceSessionId));
}

// ── Sidebar button Y positions (relative to sidebar origin) ──────────────────

int _sidebarClearButtonY(NemotronState state) {
  return state.headerHeight + 2 + state.attachedFiles.length + 1;
}

int _sidebarSearchButtonY(NemotronState state) {
  return _sidebarClearButtonY(state) + 2;
}

// ── Inference commands ───────────────────────────────────────────────────────

Cmd _startInference(NemotronState state, String prompt) {
  return () async {
    final inference = _getInference();
    if (inference == null) {
      return GenerationErrorMsg('Inference engine not available');
    }

    final sessionId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final buffer = _TokenBuffer();
    _activeBuffers[sessionId] = buffer;

    try {
      final stream = inference.chatStream(prompt);
      late StreamSubscription<String> sub;

      sub = stream.listen(
        (token) => buffer.add(token),
        onDone: () => buffer.markDone(),
        onError: (e) => buffer.markError(e.toString()),
        cancelOnError: true,
      );

      buffer.attach(sub);

      return _InferenceStartedMsg(sessionId, prompt);
    } catch (e) {
      _activeBuffers.remove(sessionId);
      return GenerationErrorMsg(e.toString());
    }
  };
}

Cmd _pollCmd(String sessionId) {
  return () async {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    final buffer = _activeBuffers[sessionId];
    if (buffer == null) {
      return GenerationErrorMsg('Inference session lost');
    }

    final tokens = buffer.drain();
    if (tokens.isNotEmpty) return TokensReceivedMsg(tokens);
    if (buffer.isDone) return GenerationCompleteMsg(buffer.fullResponse);
    if (buffer.hasError) return GenerationErrorMsg(buffer.error!);
    return PollMsg();
  };
}

// ── Inference access (set during app initialization) ─────────────────────────

NemotronInference? _inference;

void registerInference(NemotronInference inference) {
  _inference = inference;
}

NemotronInference? _getInference() => _inference;
