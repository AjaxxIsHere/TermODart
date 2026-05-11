import 'package:dart_tui/dart_tui.dart';

import 'model.dart';
import 'theme.dart';

// ── Public view function ─────────────────────────────────────────────────────

View nemotronView(NemotronState state) {
  if (!state.modelLoaded) {
    return _loadingView(state);
  }

  final header = _renderHeader(state);
  final sidebar = _renderSidebar(state);
  final chat = _renderChat(state);
  final footer = _renderFooter(state);

  // Join sidebar and chat horizontally (ANSI-aware)
  final mainContent = joinHorizontal(
    AlignVertical.top,
    [sidebar, chat],
  );

  // Stack vertically (ANSI-aware)
  final full = joinVertical(Align.left, [header, mainContent, footer]);

  return View(
    content: full,
    mouseMode: MouseMode.cellMotion,
    cursor: _footerCursor(state),
  );
}

// ── Loading screen ───────────────────────────────────────────────────────────

View _loadingView(NemotronState state) {
  final w = state.termWidth;
  final h = state.termHeight;
  final msg = state.statusMessage.isNotEmpty
      ? state.statusMessage
      : 'Loading Nemotron model...';

  final content = StringBuffer();
  // Center vertically
  final vPad = (h ~/ 2) - 2;
  for (var i = 0; i < vPad; i++) {
    content.writeln();
  }

  final hPad = ((w - msg.length) ~/ 2).clamp(0, 999).toInt();
  content.writeln(' ' * hPad + styledText(msg, fg: cyan, bold: true));

  // ASCII cat
  for (final line in asciiCat) {
    final catPad = ((w - line.length) ~/ 2).clamp(0, 999).toInt();
    content.writeln(' ' * catPad + styledText(line, fg: purpleBright));
  }

  // Fill remaining
  for (var i = 0; i < vPad - 1; i++) {
    content.writeln();
  }

  return View(content: content.toString());
}

// ── Header ───────────────────────────────────────────────────────────────────

String _renderHeader(NemotronState state) {
  final w = state.termWidth;
  final title = ' NEMOTRON // TERMINAL ';
  final status = state.isGenerating ? ' ● GENERATING...' : ' ● ONLINE ';

  final innerW = w - 4; // account for border + padding
  final rhsW = status.length;
  final lhsW = innerW - rhsW;
  final lhs = title.padRight(lhsW);
  final rhs = status;

  final inner = '$lhs$rhs';
  return headerStyle
      .copyWith(width: w, height: 1)
      .render(inner);
}

// ── Sidebar ──────────────────────────────────────────────────────────────────

String _renderSidebar(NemotronState state) {
  final innerW = state.sidebarWidth - 4; // inside border + padding
  if (innerW < 6) return '';
  final panelHeight = state.mainHeight > 2 ? state.mainHeight - 2 : 0;

  final buf = StringBuffer();

  // Section: Files
  buf.writeln(styledText(' FILES ', fg: cyan, bold: true));
  if (state.attachedFiles.isEmpty) {
    buf.writeln(styledText(' (none)', fg: textMuted));
  } else {
    for (final f in state.attachedFiles) {
      final display = f.length > innerW - 3 ? '...${f.substring(f.length - (innerW - 6))}' : f;
      buf.writeln('  $display');
    }
  }

  // Spacer before buttons
  final spacerLines = state.mainHeight - 6 - asciiCat.length - 4;
  for (var i = 0; i < spacerLines.clamp(0, 999).toInt(); i++) {
    buf.writeln();
  }

  // Buttons
  buf.writeln(_renderButton(' CLEAR  ', innerW, primary: true));
  buf.writeln();
  buf.writeln(_renderButton(' SEARCH ', innerW, primary: false));

  // Cat logo at bottom
  buf.writeln();
  for (final line in asciiCat) {
    buf.writeln(styledText(line.padLeft((innerW - line.length) ~/ 2 + line.length).padRight(innerW), fg: purpleBright));
  }

  return sidebarStyle
      .copyWith(width: state.sidebarWidth, height: panelHeight)
      .render(buf.toString());
}

String _renderButton(String label, int innerW, {required bool primary}) {
  final style = primary ? buttonStyle : buttonDimStyle;
  final rendered = style.render(label);
  // Center button
  final lines = rendered.split('\n');
  final padded = lines.map((l) {
    final visW = _visibleWidth(l);
    final pad = (innerW - visW) ~/ 2;
    return pad > 0 ? ' ' * pad + l : l;
  }).join('\n');
  return padded;
}

// ── Chat panel ───────────────────────────────────────────────────────────────

String _renderChat(NemotronState state) {
  final innerW = state.chatWidth - 4;
  if (innerW < 10) return '';
  final panelHeight = state.mainHeight > 2 ? state.mainHeight - 2 : 0;

  // Build all message lines
  final allLines = <String>[];

  // Past messages
  for (final msg in state.messages) {
    allLines.addAll(_renderMessage(msg, innerW));
  }

  // Streaming response
  if (state.isGenerating && state.streamingResponse.isNotEmpty) {
    allLines.addAll(_renderStreamingResponse(state.streamingResponse, innerW));
  }

  // Empty state
  if (allLines.isEmpty && !state.isGenerating) {
    final welcome = styledText('Welcome to Nemotron Bot!', fg: cyan, bold: true);
    final hint = styledText('Type a message and press Enter to chat.', fg: textMuted);
    final vPad = (state.mainHeight - 4) ~/ 2;
    for (var i = 0; i < vPad; i++) {
      allLines.add('');
    }
    final wPad = (innerW - _visibleWidth(welcome)) ~/ 2;
    allLines.add(' ' * wPad.clamp(0, 999).toInt() + welcome);
    final hPad2 = (innerW - _visibleWidth(hint)) ~/ 2;
    allLines.add(' ' * hPad2.clamp(0, 999).toInt() + hint);
  }

  // Calculate viewport
  final visibleH = state.mainHeight - 2; // -2 for border/padding
  final maxScroll = (allLines.length - visibleH).clamp(0, 99999999).toInt();
  final offset = state.scrollOffset.clamp(0, maxScroll).toInt();

  // Take visible slice
  final visible = <String>[];
  if (offset < allLines.length) {
    final end = (offset + visibleH).clamp(0, allLines.length).toInt();
    visible.addAll(allLines.sublist(offset, end));
  }

  // Pad to visible height
  while (visible.length < visibleH) {
    visible.add('');
  }

  return chatPanelStyle
      .copyWith(width: state.chatWidth, height: panelHeight)
      .render(visible.join('\n'));
}

List<String> _renderMessage(ChatMessage msg, int maxW) {
  final lines = <String>[];
  final prefix = msg.role == 'user' ? 'You: ' : 'Bot: ';
  final fg = msg.role == 'user' ? cyan : purpleBright;

  lines.add(styledText(prefix, fg: fg, bold: true));

  final processed = processThinkTags(msg.content);
  final wrapped = _wrapText(processed, maxW - 2); // -2 for indent
  for (final line in wrapped) {
    lines.add('  ${styledText(line, fg: msg.role == 'user' ? cyan : textPrimary)}');
  }
  lines.add(''); // blank spacer
  return lines;
}

List<String> _renderStreamingResponse(String text, int maxW) {
  final lines = <String>[];
  lines.add(styledText('Bot: ', fg: purpleBright, bold: true));

  final processed = processThinkTags(text);
  final wrapped = _wrapText(processed, maxW - 2);
  for (final line in wrapped) {
    lines.add('  ${styledText(line, fg: textPrimary)}');
  }
  return lines;
}

// ── Footer ───────────────────────────────────────────────────────────────────

String _renderFooter(NemotronState state) {
  final innerW = state.termWidth - 4;
  if (innerW < 10) return '';
  final panelHeight = state.footerHeight > 2 ? state.footerHeight - 2 : 0;

  final buf = StringBuffer();

  // Row 0: input prompt
  final prompt = state.isGenerating ? ' (generating...)' : ' > ';
  final inputLine = '$prompt${state.inputText}';
  final visible = _truncateRight(inputLine, innerW - 12); // leave room for send
  buf.writeln(visible);

  // Row 1: empty (spacing)
  buf.writeln('');

  // Row 2: send button (right-aligned) + status
  final statusText = state.statusMessage.isNotEmpty
      ? styledText(state.statusMessage, fg: errorRed)
      : (state.isGenerating ? styledText('Generating...', fg: cyanDim) : '');

  final sendBtn = state.isGenerating
      ? buttonDimStyle.render(' SEND ')
      : buttonStyle.render(' SEND ');

  final sendLines = sendBtn.split('\n');
  final sendRendered = sendLines.isNotEmpty ? sendLines.first : '';

  final rhsContent = sendRendered;
  final lhsSpace = innerW - _visibleWidth(rhsContent) - _visibleWidth(statusText);
  final lhs = statusText.padRight(lhsSpace.clamp(0, 999).toInt());

  buf.write('$lhs$rhsContent');

  return footerStyle
      .copyWith(width: state.termWidth, height: panelHeight)
      .render(buf.toString());
}

Cursor _footerCursor(NemotronState state) {
  // Position cursor in the input field
  final promptLen = state.isGenerating ? ' (generating...)' : ' > ';
  final col = 2 + promptLen.length + state.inputText.length; // 2 = border+padding
  // Clamp to inner width
  final innerW = state.termWidth - 4;
  final clampedCol = col.clamp(0, innerW + 1).toInt();
  final row = (state.termHeight - state.footerHeight + 1)
      .clamp(0, state.termHeight)
      .toInt();

  return Cursor(x: clampedCol + 2, y: row, shape: CursorShape.bar, blink: true);
}

// ── Text helpers ─────────────────────────────────────────────────────────────

/// Visible width (stripping ANSI escape sequences).
int _visibleWidth(String s) {
  return s.replaceAll(RegExp('\x1b\\[[0-9;]*m'), '').length;
}

/// Wrap text to a given visible width, preserving ANSI sequences.
List<String> _wrapText(String text, int maxW) {
  if (maxW <= 0) return [text];
  final lines = <String>[];

  for (final paragraph in text.split('\n')) {
    if (paragraph.isEmpty) {
      lines.add('');
      continue;
    }
    lines.addAll(_wrapLine(paragraph, maxW));
  }

  return lines;
}

List<String> _wrapLine(String line, int maxW) {
  final result = <String>[];
  var current = '';
  var currentLen = 0;
  final words = line.split(' ');

  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    final wordLen = _visibleWidth(word);

    if (currentLen + wordLen + (current.isEmpty ? 0 : 1) <= maxW) {
      current += (current.isEmpty ? '' : ' ') + word;
      currentLen = _visibleWidth(current);
    } else {
      if (current.isNotEmpty) {
        result.add(current);
        current = word;
        currentLen = wordLen;
      } else {
        // Word is longer than maxW, force-split
        result.add(word);
        current = '';
        currentLen = 0;
      }
    }
  }

  if (current.isNotEmpty) result.add(current);
  return result.isEmpty ? [''] : result;
}

/// Truncate on the right to fit visible width.
String _truncateRight(String s, int maxW) {
  if (_visibleWidth(s) <= maxW) return s;
  // Simple character-by-character walk
  var visible = 0;
  var result = '';
  final runes = s.runes.toList();
  for (var i = 0; i < runes.length; i++) {
    final ch = String.fromCharCode(runes[i]);
    // Skip ANSI escape sequences
    if (ch == '\x1b') {
      // Find the end of the escape sequence
      var j = i;
      while (j < runes.length && runes[j] != 109) { // 'm'
        j++;
      }
      // Append the entire escape sequence
      for (var k = i; k <= j && k < runes.length; k++) {
        result += String.fromCharCode(runes[k]);
      }
      i = j;
      continue;
    }
    final chW = ch.codeUnitAt(0) < 128 ? 1 : 2;
    if (visible + chW > maxW) break;
    visible += chW;
    result += ch;
  }
  return result;
}