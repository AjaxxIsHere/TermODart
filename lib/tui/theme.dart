import 'package:dart_tui/dart_tui.dart';

// ── Color Palette ───────────────────────────────────────────────────────────

/// Electric Cyan — primary accent
const cyan = RgbColor(0, 255, 255);
const cyanDim = RgbColor(0, 180, 180);

/// Deep Purple — secondary accent
const purple = RgbColor(138, 43, 226);
const purpleBright = RgbColor(180, 130, 255);

/// Dark background spectrum
const bgDark = RgbColor(14, 14, 22);
const bgSurface = RgbColor(22, 22, 34);
const bgPanel = RgbColor(18, 18, 28);

/// Text
const textPrimary = RgbColor(220, 220, 235);
const textDim = RgbColor(140, 140, 160);
const textMuted = RgbColor(100, 100, 120);

/// Think-tag gray (for  think  blocks)
const thinkGray = RgbColor(128, 128, 140);

/// Semantic
const errorRed = RgbColor(255, 70, 70);
const successGreen = RgbColor(70, 255, 120);

// ── Base Styles ──────────────────────────────────────────────────────────────

final headerStyle = Style(
  foregroundRgb: cyan,
  backgroundRgb: bgPanel,
  border: Border.box,
  borderForeground: cyan,
  isBold: true,
  padding: const EdgeInsets.symmetric(horizontal: 2),
);

final sidebarStyle = Style(
  foregroundRgb: textDim,
  backgroundRgb: bgPanel,
  border: Border.box,
  borderForeground: cyanDim,
  padding: const EdgeInsets.symmetric(horizontal: 1),
);

final chatPanelStyle = Style(
  foregroundRgb: textPrimary,
  backgroundRgb: bgSurface,
  border: Border.box,
  borderForeground: cyanDim,
  padding: const EdgeInsets.only(left: 2, right: 1),
  wordWrap: true,
);

final footerStyle = Style(
  foregroundRgb: textPrimary,
  backgroundRgb: bgPanel,
  border: Border.box,
  borderForeground: cyan,
  padding: const EdgeInsets.symmetric(horizontal: 2),
);

final buttonStyle = Style(
  foregroundRgb: bgDark,
  backgroundRgb: cyan,
  isBold: true,
  padding: const EdgeInsets.symmetric(horizontal: 2),
);

final buttonDimStyle = Style(
  foregroundRgb: textPrimary,
  backgroundRgb: RgbColor(40, 40, 55),
  padding: const EdgeInsets.symmetric(horizontal: 2),
);

final loadingStyle = Style(
  foregroundRgb: cyan,
  isBold: true,
  padding: const EdgeInsets.all(1),
);

// ── ASCII Cat Logo ───────────────────────────────────────────────────────────

const asciiCat = [
  r'   /\_/\   ',
  r'  ( o.o )  ',
  r'   > ^ <   ',
  r'  /  ~  \  ',
];

// ── ANSI escape helpers for inline message styling ───────────────────────────

String ansiFg(RgbColor c) => '\x1b[38;2;${c.r};${c.g};${c.b}m';
const ansiReset = '\x1b[0m';
const ansiBold = '\x1b[1m';
const ansiItalic = '\x1b[3m';

String styledText(String text, {RgbColor? fg, bool bold = false, bool italic = false}) {
  final codes = <String>[];
  if (bold) codes.add(ansiBold);
  if (italic) codes.add(ansiItalic);
  if (fg != null) codes.add(ansiFg(fg));
  if (codes.isEmpty) return text;
  return '${codes.join()}$text$ansiReset';
}

/// Wrap  think  blocks in gray italic styling.
String processThinkTags(String text) {
  return text.replaceAllMapped(
    RegExp(r'<think>(.*?)</think>', dotAll: true),
    (m) => '$ansiItalic${ansiFg(thinkGray)}${m.group(1)}$ansiReset',
  );
}
