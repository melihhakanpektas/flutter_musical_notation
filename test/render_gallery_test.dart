import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_music_core/flutter_music_core.dart';
import 'package:flutter_musical_notation/flutter_musical_notation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Görsel galeri üretimi: temsili senaryoları `test/renders/` altına PNG
/// olarak yazar. Görsel regresyon incelemesi ve dokümantasyon içindir;
/// render hatasında test kırmızıya düşer.
Future<void> _loadFont() async {
  final bytes = File('fonts/NotoMusic-Regular.ttf').readAsBytesSync();
  final loader = FontLoader('NotoMusic')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<void> _render(
  WidgetTester tester,
  String name,
  MusicNotation notation, {
  double width = 460,
  double height = 160,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: Colors.white,
              width: width,
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: notation,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull, reason: name);

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image =
      (await tester.runAsync(() => boundary.toImage(pixelRatio: 2)))!;
  final data = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  ))!;
  Directory('test/renders').createSync(recursive: true);
  File('test/renders/$name.png').writeAsBytesSync(data.buffer.asUint8List());
}

MidiNote _n(int index, int octave, [MusicalAccidental? accidental]) =>
    MidiNote(index: index, octave: octave, accidental: accidental);

void main() {
  testWidgets('render gallery', (tester) async {
    await _loadFont();

    // 1) Tek ses geri bildirimi: hedef nota tek başına (ortalanmış).
    await _render(
      tester,
      '01_tek_ses',
      MusicNotation(
        horizontallyCenterNotes: true,
        values: [
          MusicalValue(
            duration: MusicalDuration.whole,
            midiNotes: [_n(5, 4)], // La4
          ),
        ],
      ),
    );

    // 2) Çift ses (tam beşli, harmonik): Do4 + Sol4.
    await _render(
      tester,
      '02_cift_ses_besli',
      MusicNotation(
        horizontallyCenterNotes: true,
        values: [
          MusicalValue(
            duration: MusicalDuration.whole,
            midiNotes: [_n(0, 4), _n(4, 4)],
          ),
        ],
      ),
    );

    // 3) Çift ses ikili aralık (second) — notabaşı ofseti: Do4 + Re4.
    await _render(
      tester,
      '03_cift_ses_ikili',
      MusicNotation(
        horizontallyCenterNotes: true,
        values: [
          MusicalValue(
            duration: MusicalDuration.whole,
            midiNotes: [_n(0, 4), _n(1, 4)],
          ),
        ],
      ),
    );

    // 4) Üç ses: Do majör (Do4-Mi4-Sol4).
    await _render(
      tester,
      '04_uc_ses_major',
      MusicNotation(
        horizontallyCenterNotes: true,
        values: [
          MusicalValue(
            duration: MusicalDuration.whole,
            midiNotes: [_n(0, 4), _n(2, 4), _n(4, 4)],
          ),
        ],
      ),
    );

    // 5) Dört ses: Cmaj7 (Do4-Mi4-Sol4-Si4).
    await _render(
      tester,
      '05_dort_ses_cmaj7',
      MusicNotation(
        horizontallyCenterNotes: true,
        values: [
          MusicalValue(
            duration: MusicalDuration.whole,
            midiNotes: [_n(0, 4), _n(2, 4), _n(4, 4), _n(6, 4)],
          ),
        ],
      ),
    );

    // 6) Yüksek akor, ters sap: La4-Do5-Mi5 (dörtlük).
    await _render(
      tester,
      '06_ters_sap_akor',
      MusicNotation(
        horizontallyCenterNotes: true,
        values: [
          MusicalValue(
            duration: MusicalDuration.quarter,
            midiNotes: [_n(5, 4), _n(0, 5), _n(2, 5)],
          ),
        ],
      ),
    );

    // 7) Ritim paterni, 2/4, 2 ölçü: ♩ ♪♪ | ♪ ♩ ♪ (senkoplu).
    await _render(
      tester,
      '07_ritim_2_4',
      MusicNotation(
        beatsPerMeasure: 2,
        measureCount: 2,
        values: [
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(4, 4)]),
          MusicalValue(duration: MusicalDuration.eighth, midiNotes: [_n(4, 4)]),
          MusicalValue(duration: MusicalDuration.eighth, midiNotes: [_n(4, 4)]),
          MusicalValue(duration: MusicalDuration.eighth, midiNotes: [_n(4, 4)]),
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(4, 4)]),
          MusicalValue(duration: MusicalDuration.eighth, midiNotes: [_n(4, 4)]),
        ],
      ),
      width: 560,
    );

    // 8) Noktalı değerler, 2/4: ♩. ♪ | ♪ ♩. (nokta çizimi).
    await _render(
      tester,
      '08_ritim_noktali',
      MusicNotation(
        beatsPerMeasure: 2,
        measureCount: 2,
        values: [
          MusicalValue(
              duration: MusicalDuration.quarter,
              dotted: true,
              midiNotes: [_n(4, 4)]),
          MusicalValue(duration: MusicalDuration.eighth, midiNotes: [_n(4, 4)]),
          MusicalValue(duration: MusicalDuration.eighth, midiNotes: [_n(4, 4)]),
          MusicalValue(
              duration: MusicalDuration.quarter,
              dotted: true,
              midiNotes: [_n(4, 4)]),
        ],
      ),
      width: 560,
    );

    // 9) 5/8 aksak ölçü: ♪ ♪ ♩ ♪ (2+3 hissi).
    await _render(
      tester,
      '09_ritim_5_8',
      MusicNotation(
        beatsPerMeasure: 5,
        beatUnit: MusicalDuration.eighth,
        values: [
          MusicalValue(duration: MusicalDuration.eighth, midiNotes: [_n(4, 4)]),
          MusicalValue(duration: MusicalDuration.eighth, midiNotes: [_n(4, 4)]),
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(4, 4)]),
          MusicalValue(duration: MusicalDuration.eighth, midiNotes: [_n(4, 4)]),
        ],
      ),
    );

    // 10) Aksidanlar: Fa♯4 ve Si♭4.
    await _render(
      tester,
      '10_aksidanlar',
      MusicNotation(
        values: [
          MusicalValue(
            duration: MusicalDuration.half,
            midiNotes: [_n(3, 4, MusicalAccidental.sharp)],
          ),
          MusicalValue(
            duration: MusicalDuration.half,
            midiNotes: [_n(6, 4, MusicalAccidental.flat)],
          ),
        ],
      ),
    );

    // 11) Uç bölgeler: sol anahtarında La5 (üst ledger), Do4 (alt ledger).
    await _render(
      tester,
      '11_ledger_uclar',
      MusicNotation(
        values: [
          MusicalValue(duration: MusicalDuration.half, midiNotes: [_n(5, 5)]),
          MusicalValue(duration: MusicalDuration.half, midiNotes: [_n(0, 4)]),
        ],
      ),
    );

    // 13) Üst ledger + ters saplı ikili aralık: La5+Si5 (dip dibe, çubuklu).
    await _render(
      tester,
      '13_ust_ikili_sapli',
      MusicNotation(
        horizontallyCenterNotes: true,
        values: [
          MusicalValue(
            duration: MusicalDuration.quarter,
            midiNotes: [_n(5, 5), _n(6, 5)],
          ),
        ],
      ),
    );

    // 14) Alt ledger + dik ikili aralık: Si3+Do4 (dip dibe, çubuklu).
    await _render(
      tester,
      '14_alt_ikili_sapli',
      MusicNotation(
        horizontallyCenterNotes: true,
        values: [
          MusicalValue(
            duration: MusicalDuration.quarter,
            midiNotes: [_n(6, 3), _n(0, 4)],
          ),
        ],
      ),
    );

    // 15) Alt bölgede çubuklu dizi: Do4-Re4-Mi4-Fa4 (dörtlükler, dip dibe).
    await _render(
      tester,
      '15_sapli_dizi_alt',
      MusicNotation(
        values: [
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(0, 4)]),
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(1, 4)]),
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(2, 4)]),
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(3, 4)]),
        ],
      ),
      width: 560,
    );

    // 16) Üst bölgede çubuklu dizi: Fa5-Sol5-La5-Sol5 (sekizlikler, ledger).
    await _render(
      tester,
      '16_sapli_dizi_ust',
      MusicNotation(
        beatsPerMeasure: 2,
        values: [
          MusicalValue(duration: MusicalDuration.eighth, midiNotes: [_n(3, 5)]),
          MusicalValue(duration: MusicalDuration.eighth, midiNotes: [_n(4, 5)]),
          MusicalValue(duration: MusicalDuration.eighth, midiNotes: [_n(5, 5)]),
          MusicalValue(duration: MusicalDuration.eighth, midiNotes: [_n(4, 5)]),
        ],
      ),
      width: 560,
    );

    // 12) Fa anahtarı, bas bölge: Mi2 (uygulama alt ucu) ve Do3.
    await _render(
      tester,
      '12_fa_anahtari_bas',
      MusicNotation(
        clef: Clef.bass,
        values: [
          MusicalValue(duration: MusicalDuration.half, midiNotes: [_n(2, 2)]),
          MusicalValue(duration: MusicalDuration.half, midiNotes: [_n(0, 3)]),
        ],
      ),
    );
  });
}
