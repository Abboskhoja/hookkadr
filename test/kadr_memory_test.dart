import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/chat/chat_models.dart';
import 'package:hookkadr/features/kadr_ai/kadr_memory.dart';
import 'package:hookkadr/features/kadr_ai/kadr_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<KadrMemory> _fresh([Map<String, Object> init = const {}]) async {
  SharedPreferences.setMockInitialValues(init);
  return KadrMemory(await SharedPreferences.getInstance());
}

void main() {
  group('remember command', () {
    test('recognises Uzbek "remember" phrasings', () {
      expect(
        KadrMemory.factFrom('Eslab qol: do‘konim nomi Sumkachi'),
        'do‘konim nomi Sumkachi',
      );
      expect(
        KadrMemory.factFrom('esda tut, men qisqa videolarni yoqtiraman'),
        'men qisqa videolarni yoqtiraman',
      );
      expect(
        KadrMemory.factFrom('Kadr AI, yodda tut: logotip ko‘k'),
        'logotip ko‘k',
      );
      expect(KadrMemory.factFrom('kafe uchun reklama yasa'), isNull);
      expect(KadrMemory.factFrom('eslab qol'), isNull);
    });

    test('facts persist, dedupe, stay bounded and can be forgotten', () async {
      final m = await _fresh();
      await m.remember('Do‘kon: Sumkachi');
      await m.remember('do‘kon: sumkachi'); // same fact, newest wins
      expect(m.facts, ['do‘kon: sumkachi']);
      for (var i = 0; i < 30; i++) {
        await m.remember('fakt $i');
      }
      expect(m.facts.length, KadrMemory.maxFacts);
      expect(m.facts.last, 'fakt 29');
      await m.remember('x' * 500);
      expect(m.facts.last.length, KadrMemory.maxFactChars);

      final again = KadrMemory(await SharedPreferences.getInstance());
      expect(again.facts, m.facts);
      await again.forget('fakt 29');
      expect(again.facts, isNot(contains('fakt 29')));
    });
  });

  group('learning the look', () {
    test('no preference without evidence', () async {
      final m = await _fresh();
      expect(m.preferredStyle, isNull);
      expect(m.preferredAspect, isNull);
      expect(m.promptContext(), isEmpty);
    });

    test(
      'ratings outweigh plain choices; dislikes push a style down',
      () async {
        final m = await _fresh();
        await m.choseStyle(PaintStyle.anime);
        await m.choseStyle(PaintStyle.anime);
        expect(m.preferredStyle, PaintStyle.anime);
        await m.rate(PaintStyle.cinematic, 1);
        await m.rate(PaintStyle.cinematic, 1);
        expect(m.preferredStyle, PaintStyle.cinematic);
        await m.rate(PaintStyle.anime, -1);
        expect(m.styleScore(PaintStyle.anime), lessThan(0.5));
        expect(m.learned(), contains('Yoqtirgan uslubingiz: Kino'));
      },
    );

    test('a disliked-only style is never preferred', () async {
      final m = await _fresh();
      await m.rate(PaintStyle.product, -1);
      expect(m.preferredStyle, isNull);
    });

    test('most used format after two uses', () async {
      final m = await _fresh();
      await m.choseAspect('16:9');
      expect(m.preferredAspect, isNull);
      await m.choseAspect('16:9');
      await m.choseAspect('9:16');
      expect(m.preferredAspect, '16:9');
    });

    test('prompt context lists facts and the liked style', () async {
      final m = await _fresh();
      await m.remember('Brend rangi: ko‘k');
      await m.rate(PaintStyle.product, 1);
      final c = m.promptContext();
      expect(c, contains('Brend rangi: ko‘k'));
      expect(c, contains('Mahsulot'));
    });

    test('clear forgets everything and damaged data is dropped', () async {
      final m = await _fresh({'kadr_memory_v1': '{not json'});
      expect(m.isEmpty, isTrue);
      await m.remember('a fact');
      await m.clear();
      expect(m.isEmpty, isTrue);
      final again = KadrMemory(await SharedPreferences.getInstance());
      expect(again.isEmpty, isTrue);
    });
  });

  test('chat messages keep the painter style and the rating', () {
    final m = Msg.ai('Rasm tayyor', imagePath: '/a.png', style: 'cinematic')
      ..rating = 1;
    final back = Msg.fromJson(m.toJson());
    expect(back.style, 'cinematic');
    expect(back.rating, 1);
    expect(Msg.fromJson(Msg.ai('x').toJson()).style, isNull);
  });
}
