import 'package:flutter/material.dart';

/// Renders the little markdown chat models use (**bold**, `* ` / `- `
/// bullets, `#` headings) as styled text, so people never see raw symbols.
/// Unclosed `**` while a reply is still streaming is shown as plain text.
TextSpan lightMarkdown(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final lines = text.split('\n');
  for (final (i, raw) in lines.indexed) {
    var line = raw;
    var style = base;
    final heading = RegExp(r'^\s{0,3}#{1,6}\s+').firstMatch(line);
    if (heading != null) {
      line = line.substring(heading.end);
      style = base.copyWith(fontWeight: FontWeight.w700);
    }
    final bullet = RegExp(r'^(\s*)[*\-•]\s+').firstMatch(line);
    if (bullet != null) {
      spans.add(TextSpan(text: '${bullet.group(1)}•  ', style: style));
      line = line.substring(bullet.end);
    }
    _inline(line, style, spans);
    if (i < lines.length - 1) spans.add(TextSpan(text: '\n', style: base));
  }
  return TextSpan(style: base, children: spans);
}

void _inline(String line, TextStyle style, List<InlineSpan> out) {
  final bold = RegExp(r'\*\*(.+?)\*\*');
  var at = 0;
  for (final m in bold.allMatches(line)) {
    if (m.start > at) {
      out.add(TextSpan(text: line.substring(at, m.start), style: style));
    }
    out.add(
      TextSpan(
        text: m.group(1),
        style: style.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    at = m.end;
  }
  if (at < line.length) {
    out.add(TextSpan(text: line.substring(at), style: style));
  }
}
