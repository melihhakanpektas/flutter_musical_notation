import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_music_core/flutter_music_core.dart';
import 'package:flutter_musical_notation/flutter_musical_notation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paket fontunu test ortamına yükler (glif genişlikleri yerleşimi etkiler).
Future<void> _loadFont() async {
  final bytes = File('fonts/Bravura.otf').readAsBytesSync();
  final loader = FontLoader('packages/flutter_musical_notation/Bravura')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

MusicalValue _e() => MusicalValue(
      duration: MusicalDuration.eighth,
      midiNotes: [MidiNote(index: 0, octave: 4)],
    );
MusicalValue _q() => MusicalValue(
      duration: MusicalDuration.quarter,
      midiNotes: [MidiNote(index: 0, octave: 4)],
    );

const _size = Size(400, 150);

void main() {
  setUpAll(_loadFont);

  // 2/4: bir ölçü = 0.5 birlik nota. İçerik: dörtlük + iki sekizlik.
  NotationLayout twoFourLayout({int measureCount = 1}) => NotationLayout(
        size: _size,
        beatsPerMeasure: 2,
        rhythmStaff: true,
        measures: [
          for (var i = 0; i < measureCount; i++)
            NotationMeasure([
              Single(_q()),
              Beam([_e(), _e()]),
            ]),
        ],
      );

  group('NotationLayout: zaman ↔ x', () {
    test('ölçü uzunluğu ölçü iminden gelir', () {
      expect(twoFourLayout().measureTimeLength, 0.5); // 2 × dörtlük
      expect(
        NotationLayout(
          size: _size,
          beatsPerMeasure: 5,
          beatUnit: MusicalDuration.eighth,
          measures: [NotationMeasure([Single(_e())])],
        ).measureTimeLength,
        closeTo(5 / 8, 1e-9),
      );
    });

    test('xForTime monoton artar ve sınırlarda kırpılır', () {
      final layout = twoFourLayout(measureCount: 2);
      final total = layout.totalTimeLength;

      final xs = [
        for (var t = 0.0; t <= total; t += total / 16) layout.xForTime(t),
      ];
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], greaterThanOrEqualTo(xs[i - 1]),
            reason: 'playhead geri gitmemeli');
      }

      // Sınırların dışı kırpılır (çubuk notasyondan taşmaz).
      expect(layout.xForTime(-1), layout.xForTime(0));
      expect(layout.xForTime(total + 5), layout.xForTime(total));
      expect(layout.xForTime(0), greaterThan(layout.regionLeftOf(0)),
          reason: 'notalar bara yapışmaz, iç bölgeden başlar');
      expect(layout.xForTime(total), lessThan(_size.width));
    });

    test('playhead ilk notanın slot\'unda başlar (çizimle aynı hesap)', () {
      final layout = twoFourLayout();
      final firstHit = layout.hits.first;
      expect(layout.xForTime(0), closeTo(firstHit.bounds.left, 1e-9));
    });
  });

  group('NotationLayout: dokunma hedefleri', () {
    test('her değer için bir hit; zaman ve sıra doğru', () {
      final layout = twoFourLayout();
      expect(layout.hits.length, 3); // dörtlük + 2 sekizlik

      expect(layout.hits[0].timeStart, 0);
      expect(layout.hits[0].value.duration, MusicalDuration.quarter);
      expect(layout.hits[0].elementIndex, 0);
      expect(layout.hits[0].valueIndex, 0);

      // Kiriş grubundaki iki sekizlik aynı öğede, sırayla.
      expect(layout.hits[1].timeStart, closeTo(0.25, 1e-9));
      expect(layout.hits[1].elementIndex, 1);
      expect(layout.hits[1].valueIndex, 0);
      expect(layout.hits[2].timeStart, closeTo(0.375, 1e-9));
      expect(layout.hits[2].elementIndex, 1);
      expect(layout.hits[2].valueIndex, 1);
    });

    test('hedefler bitişiktir (aralarında boşluk yok) ve süreyle orantılıdır',
        () {
      final layout = twoFourLayout();
      // Dörtlük, sekizliğin iki katı genişlikte.
      expect(layout.hits[0].bounds.width,
          closeTo(layout.hits[1].bounds.width * 2, 1e-6));
      // Bitişik: birinin sağı ötekinin solu.
      expect(layout.hits[0].bounds.right, closeTo(layout.hits[1].bounds.left, 1e-9));
      expect(layout.hits[1].bounds.right, closeTo(layout.hits[2].bounds.left, 1e-9));
    });

    test('hitAt doğru değeri bulur; boşlukta null döner', () {
      final layout = twoFourLayout();
      for (final hit in layout.hits) {
        final center = Offset(hit.bounds.center.dx, _size.height / 2);
        expect(layout.hitAt(center), same(hit));
      }
      // Nota bölgesinin solunda (anahtar/ölçü imi) hedef yok.
      expect(layout.hitAt(const Offset(1, 75)), isNull);
    });

    test('çok ölçülü: ikinci ölçünün hedefleri ölçü zamanıyla kayar', () {
      final layout = twoFourLayout(measureCount: 2);
      expect(layout.hits.length, 6);
      expect(layout.hits[3].measureIndex, 1);
      expect(layout.hits[3].timeStart, closeTo(0.5, 1e-9));
      expect(layout.hits[3].bounds.left,
          greaterThan(layout.hits[2].bounds.right));
    });
  });

  group('NotationLayout: çok satır (measuresPerLine)', () {
    // 4 ölçü, satır başına 2 → 2 satır. Dikey ekranda ölçüler alta sarar.
    NotationLayout wrapped({int measureCount = 4, int perLine = 2}) =>
        NotationLayout(
          size: _size,
          beatsPerMeasure: 2,
          rhythmStaff: true,
          measuresPerLine: perLine,
          measures: [
            for (var i = 0; i < measureCount; i++)
              NotationMeasure([
                Single(_q()),
                Beam([_e(), _e()]),
              ]),
          ],
        );

    test('satır sayısı ve satır yüksekliği', () {
      expect(wrapped().lineCount, 2);
      expect(wrapped().lineHeight, _size.height / 2);
      expect(wrapped(measureCount: 3).lineCount, 2, reason: '3 ölçü → 2+1');
      expect(wrapped(measureCount: 2).lineCount, 1);
      expect(wrapped(measureCount: 1).lineCount, 1);
      // measuresPerLine verilmezse tek satır (eski davranış).
      expect(twoFourLayout(measureCount: 4).lineCount, 1);
    });

    test('ölçüler satırlara dağılır; son satır yarım kalabilir', () {
      final layout = wrapped(measureCount: 3);
      expect(layout.lineOf(0), 0);
      expect(layout.lineOf(1), 0);
      expect(layout.lineOf(2), 1);
      expect(layout.measuresInLine(0), 2);
      expect(layout.measuresInLine(1), 1, reason: 'son satır yarım');
    });

    test('HER SATIR doldurulur: yarım kalan satırın ölçüsü satırı kaplar', () {
      // 3 ölçü + 2/satır → satır 0'da 2 ölçü, satır 1'de 1 ölçü; ikisi de
      // sağa kadar uzar (kullanıcı kararı 2026-07-17).
      final layout = wrapped(measureCount: 3);
      for (final line in [0, 1]) {
        final lineRight = layout.regionLeftOf(line) +
            layout.measuresInLine(line) * layout.measureWidthOf(line);
        expect(lineRight, closeTo(layout.regionLeftOf(0) +
            2 * layout.measureWidthOf(0), 1e-6),
            reason: 'satır $line sağ kenara kadar dolar');
        expect(lineRight, greaterThan(_size.width * 0.9));
      }
      // Tek ölçülük satırın ölçüsü, iki ölçülük satırınkinin ~2 katı geniştir.
      expect(layout.measureWidthOf(1),
          greaterThan(layout.measureWidthOf(0) * 1.8));
    });

    test('tek ölçülük patern satırı doldurur (yarısı boş kalmaz)', () {
      final layout = wrapped(measureCount: 1);
      expect(layout.lineCount, 1);
      final lineRight = layout.regionLeftOf(0) + layout.measureWidthOf(0);
      expect(lineRight, greaterThan(_size.width * 0.9),
          reason: 'measuresPerLine=2 olsa da tek ölçü satırı kaplar');
    });

    test('2 ve 4 ölçü: her satırda iki ölçü, satırlar dolu', () {
      for (final count in [2, 4]) {
        final layout = wrapped(measureCount: count);
        for (var line = 0; line < layout.lineCount; line++) {
          expect(layout.measuresInLine(line), 2);
          final lineRight = layout.regionLeftOf(line) +
              2 * layout.measureWidthOf(line);
          expect(lineRight, greaterThan(_size.width * 0.9),
              reason: '$count ölçü / satır $line dolu');
        }
      }
    });

    test('ölçü imi yalnız ilk satırda → sonraki satırlar daha erken başlar', () {
      final layout = wrapped();
      expect(layout.regionLeftOf(1), lessThan(layout.regionLeftOf(0)));
    });

    test('satır başına centerY bandı ayrışır', () {
      final layout = wrapped();
      expect(layout.centerYOf(0), _size.height / 4);
      expect(layout.centerYOf(1), _size.height * 3 / 4);
    });

    test('playhead doğru satırda: zaman sardıkça satır artar', () {
      final layout = wrapped();
      // 2/4 ölçü = 0.5 birlik; satır 0 = ölçü 0-1 (0 → 1.0), satır 1 = 2-3.
      expect(layout.lineForTime(0), 0);
      expect(layout.lineForTime(0.4), 0);
      expect(layout.lineForTime(0.6), 0, reason: '2. ölçü hâlâ 1. satırda');
      expect(layout.lineForTime(1.1), 1, reason: '3. ölçü 2. satıra sarar');
      expect(layout.lineForTime(layout.totalTimeLength), 1);

      // Yeni satırda x başa döner (aşağı-sola sarma).
      expect(layout.xForTime(1.1), lessThan(layout.xForTime(0.9)));
    });

    test('dokunma hedefi kendi satırının bandında kalır', () {
      final layout = wrapped();
      final line0Hits = layout.hits.where((h) => h.measureIndex < 2);
      final line1Hits = layout.hits.where((h) => h.measureIndex >= 2);

      for (final hit in line0Hits) {
        expect(hit.bounds.top, 0);
        expect(hit.bounds.bottom, layout.lineHeight);
      }
      for (final hit in line1Hits) {
        expect(hit.bounds.top, layout.lineHeight);
        expect(hit.bounds.bottom, closeTo(_size.height, 1e-9));
      }

      // Aynı x'te ama farklı satırda iki hedef karışmaz.
      final first = line0Hits.first;
      final third = line1Hits.first;
      expect(layout.hitAt(first.bounds.center), same(first));
      expect(layout.hitAt(third.bounds.center), same(third));
    });

    test('hits müzikal zamanı global tutar (satır sarması etkilemez)', () {
      final layout = wrapped();
      expect(layout.hits.first.timeStart, 0);
      // 3. ölçünün ilk değeri = 2 × 0.5 birlik.
      final line1First =
          layout.hits.firstWhere((h) => h.measureIndex == 2);
      expect(line1First.timeStart, closeTo(1.0, 1e-9));
    });
  });

  group('MusicNotation widget', () {
    testWidgets('notaya dokunmak o değeri bildirir', (tester) async {
      final tapped = <NotationHit>[];
      late NotationLayout layout;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: _size.width,
              height: _size.height,
              child: Builder(builder: (context) {
                final notation = MusicNotation.rhythm(
                  beatsPerMeasure: 2,
                  height: _size.height,
                  measures: [
                    NotationMeasure([
                      Single(_q()),
                      Beam([_e(), _e()]),
                    ]),
                  ],
                  onValueTap: tapped.add,
                );
                layout = notation.layoutFor(_size);
                return notation;
              }),
            ),
          ),
        ),
      ));
      await tester.pump();

      // Üçüncü değerin (2. sekizlik) merkezine dokun (yerel → global).
      final target = layout.hits[2];
      final origin = tester.getTopLeft(find.byType(MusicNotation));
      await tester.tapAt(origin + target.bounds.center);
      await tester.pump();

      expect(tapped, hasLength(1));
      expect(tapped.single.timeStart, closeTo(target.timeStart, 1e-9));
      expect(tapped.single.value.duration, MusicalDuration.eighth);
      expect(tapped.single.valueIndex, 1);
    });

    testWidgets('içeriksiz dizek çizilir (cevap öncesi bekleme çerçevesi)',
        (tester) async {
      // Yerleşim boş içerikte de bir ölçü sayar (dizek + bar çizilsin diye);
      // nota döngüsü boş listeye indekslememeli.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: MusicNotation(measures: [], measuresPerLine: 2),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('çok satırlı: yükseklik satır sayısıyla katlanır ve hatasız '
        'çizilir', (tester) async {
      final notation = MusicNotation.rhythm(
        beatsPerMeasure: 2,
        height: 100, // satır BAŞINA yükseklik
        measuresPerLine: 2,
        measures: [
          for (var i = 0; i < 4; i++)
            NotationMeasure([
              Single(_q()),
              Beam([_e(), _e()]),
            ]),
        ],
      );
      expect(notation.lineCount, 2);
      expect(notation.totalHeight, 200);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 400, child: notation)),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(MusicNotation)).height, 200);
    });

    testWidgets('marker\'lar (nokta/tik/çarpı) hatasız çizilir', (tester) async {
      const markers = [
        NotationMarker(time: 0, kind: NotationMarkerKind.check, color: Colors.green),
        NotationMarker(
            time: 0.25, kind: NotationMarkerKind.cross, color: Colors.red),
        NotationMarker(
            time: 0.375, kind: NotationMarkerKind.dot, color: Colors.red),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: _size.width,
              height: _size.height,
              child: MusicNotation.rhythm(
                beatsPerMeasure: 2,
                height: _size.height,
                markers: markers,
                measures: [
                  NotationMeasure([
                    Single(_q()),
                    Beam([_e(), _e()]),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    test('shouldRepaint marker değişimini yakalar', () {
      // Ölçü listesini paylaş: yalnız marker farkı ölçülsün (ayrı ölçü
      // örnekleri zaten repaint gerektirirdi).
      final measures = [
        NotationMeasure([Single(_q())]),
      ];
      MusicNotationPainter painterWith(List<NotationMarker> markers) =>
          MusicNotationPainter(
            beatsPerMeasure: 2,
            rhythmStaff: true,
            markers: markers,
            measures: measures,
          );
      final a = painterWith(const []);
      final b = painterWith(const [
        NotationMarker(time: 0, kind: NotationMarkerKind.dot, color: Colors.red),
      ]);
      expect(b.shouldRepaint(a), isTrue);
      expect(a.shouldRepaint(painterWith(const [])), isFalse);
    });

    testWidgets('playhead değişince yeniden boyanır (widget kurulmadan)',
        (tester) async {
      final playhead = ValueNotifier<double?>(null);
      var builds = 0;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: _size.width,
              height: _size.height,
              child: Builder(builder: (context) {
                builds++;
                return MusicNotation.rhythm(
                  beatsPerMeasure: 2,
                  height: _size.height,
                  playhead: playhead,
                  measures: [
                    NotationMeasure([
                      Single(_q()),
                      Beam([_e(), _e()]),
                    ]),
                  ],
                );
              }),
            ),
          ),
        ),
      ));
      await tester.pump();
      final buildsAfterFirst = builds;

      playhead.value = 0.25;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(builds, buildsAfterFirst,
          reason: 'playhead yalnız repaint tetikler, rebuild değil');

      playhead.value = null; // gizle
      await tester.pump();
      expect(tester.takeException(), isNull);

      playhead.dispose();
    });
  });
}
