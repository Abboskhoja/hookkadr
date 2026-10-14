import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/core/widgets/light_markdown.dart';

String plain(TextSpan s) => s.toPlainText();

void main() {
  const base = TextStyle(fontSize: 16);

  test('bold, bullets and headings lose their symbols', () {
    final s = lightMarkdown(
      '## G‘oyalar\n* **Tavsif:** Qahva\n- ikkinchi',
      base,
    );
    expect(plain(s), 'G‘oyalar\n•  Tavsif: Qahva\n•  ikkinchi');
    final bold = <String>[];
    s.visitChildren((c) {
      if (c is TextSpan && c.style?.fontWeight == FontWeight.w700) {
        bold.add(c.text ?? '');
      }
      return true;
    });
    expect(bold, containsAll(['G‘oyalar', 'Tavsif:']));
  });

  test('an unfinished bold marker while streaming stays readable', () {
    expect(plain(lightMarkdown('**1. Qahva', base)), '**1. Qahva');
  });
}
