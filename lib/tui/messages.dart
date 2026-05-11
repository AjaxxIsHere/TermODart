import 'package:dart_tui/dart_tui.dart';

/// User pressed Enter in the input field with non-empty text.
final class SendMsg extends Msg {
  SendMsg(this.text);
  final String text;
}

/// User clicked the Send button.
final class SendClickMsg extends Msg {}

/// User clicked Clear in the sidebar.
final class ClearClickMsg extends Msg {}

/// User clicked Search in the sidebar.
final class SearchClickMsg extends Msg {}

/// A batch of tokens arrived from the LLM.
final class TokensReceivedMsg extends Msg {
  TokensReceivedMsg(this.tokens);
  final List<String> tokens;
}

/// LLM generation completed successfully.
final class GenerationCompleteMsg extends Msg {
  GenerationCompleteMsg(this.fullResponse);
  final String fullResponse;
}

/// LLM generation failed.
final class GenerationErrorMsg extends Msg {
  GenerationErrorMsg(this.error);
  final String error;
}

/// Model loaded and ready.
final class ModelReadyMsg extends Msg {}

/// Model failed to load.
final class ModelLoadErrorMsg extends Msg {
  ModelLoadErrorMsg(this.error);
  final String error;
}

/// Periodic poll during generation to check for new tokens.
final class PollMsg extends Msg {}

/// Scroll the chat viewport.
final class ChatScrollMsg extends Msg {
  ChatScrollMsg(this.delta);
  final int delta;
}

/// User requested quit (q, Ctrl+C, or quit button).
final class QuitAppMsg extends Msg {}
