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

    // 17) Onaltılık bayraklar: yüksekte ters sap (çift bayrak), alçakta dik.
    await _render(
      tester,
      '17_onaltilik_bayraklar',
      MusicNotation(
        beatsPerMeasure: 2,
        values: [
          MusicalValue(duration: MusicalDuration.sixteenth, midiNotes: [_n(3, 5)]),
          MusicalValue(duration: MusicalDuration.sixteenth, midiNotes: [_n(5, 5)]),
          MusicalValue(duration: MusicalDuration.sixteenth, midiNotes: [_n(2, 4)]),
          MusicalValue(duration: MusicalDuration.sixteenth, midiNotes: [_n(4, 4)]),
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(4, 4)]),
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

    // 18) Komple çıkan dizi Do4→Do6 (dörtlük). Dik→ters sap geçişinde
    // notabaşı hizası merdiven gibi düzgün olmalı; kayma varsa burada görünür.
    await _render(
      tester,
      '18_komple_dizi',
      MusicNotation(
        beatsPerMeasure: 4,
        measureCount: 4,
        values: [
          for (var octave = 4; octave <= 5; octave++)
            for (var index = 0; index <= 6; index++)
              MusicalValue(
                duration: MusicalDuration.quarter,
                midiNotes: [_n(index, octave)],
              ),
          MusicalValue(
            duration: MusicalDuration.quarter,
            midiNotes: [_n(0, 6)], // Do6
          ),
          MusicalValue(type: RhythmicType.rest, duration: MusicalDuration.quarter),
        ],
      ),
      width: 1000,
    );

    // 19) Diyezli dizi: Do♯4 Re♯4 Fa♯4 Sol♯4 La♯4 (dörtlük).
    await _render(
      tester,
      '19_diyez_dizi',
      MusicNotation(
        beatsPerMeasure: 5,
        values: [
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(0, 4, MusicalAccidental.sharp)]),
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(1, 4, MusicalAccidental.sharp)]),
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(3, 4, MusicalAccidental.sharp)]),
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(4, 4, MusicalAccidental.sharp)]),
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(5, 4, MusicalAccidental.sharp)]),
        ],
      ),
      width: 700,
    );

    // 20) Bemollü dizi: Re♭4 Mi♭4 Sol♭4 La♭4 Si♭4 (dörtlük).
    await _render(
      tester,
      '20_bemol_dizi',
      MusicNotation(
        beatsPerMeasure: 5,
        values: [
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(1, 4, MusicalAccidental.flat)]),
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(2, 4, MusicalAccidental.flat)]),
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(4, 4, MusicalAccidental.flat)]),
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(5, 4, MusicalAccidental.flat)]),
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(6, 4, MusicalAccidental.flat)]),
        ],
      ),
      width: 700,
    );

    // 21) Bitişik akorlar (ikili aralık): Do4-Re4, diyezli, bemollü.
    await _render(
      tester,
      '21_bitisik_akor',
      MusicNotation(
        beatsPerMeasure: 3,
        values: [
          MusicalValue(
            duration: MusicalDuration.quarter,
            midiNotes: [_n(0, 4), _n(1, 4)], // Do4-Re4
          ),
          MusicalValue(
            duration: MusicalDuration.quarter,
            midiNotes: [
              _n(0, 4, MusicalAccidental.sharp),
              _n(1, 4, MusicalAccidental.sharp),
            ], // Do♯4-Re♯4
          ),
          MusicalValue(
            duration: MusicalDuration.quarter,
            midiNotes: [
              _n(1, 4, MusicalAccidental.flat),
              _n(2, 4, MusicalAccidental.flat),
            ], // Re♭4-Mi♭4
          ),
        ],
      ),
      width: 560,
    );

    // 22) Alt ek çizgiler 1-2-3: Do4 (1.), La3 (2.), Fa3 (3.); + Re3 (3.üstü).
    await _render(
      tester,
      '22_alt_ek_cizgi',
      MusicNotation(
        beatsPerMeasure: 4,
        values: [
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(0, 4)]),
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(5, 3)]),
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(3, 3)]),
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(1, 3)]),
        ],
      ),
      width: 560,
    );

    // 23) Üst ek çizgiler 1-2-3: La5 (1.), Do6 (2.), Mi6 (3.); + Sol6 (3.üstü).
    await _render(
      tester,
      '23_ust_ek_cizgi',
      MusicNotation(
        beatsPerMeasure: 4,
        values: [
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(5, 5)]),
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(0, 6)]),
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(2, 6)]),
          MusicalValue(duration: MusicalDuration.quarter, midiNotes: [_n(4, 6)]),
        ],
      ),
      width: 560,
    );

    // 24) Alt ek çizgide bitişik ikili akorlar (dik sap): Fa3-Sol3, La3-Si3,
    // Do4-Re4. İkinci notabaşı sapın sağına ofsetlenir; ek çizgi ikisini de
    // kapsamalı.
    await _render(
      tester,
      '24_bitisik_alt_ek',
      MusicNotation(
        beatsPerMeasure: 3,
        values: [
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(3, 3), _n(4, 3)]), // Fa3-Sol3
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(5, 3), _n(6, 3)]), // La3-Si3
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(0, 4), _n(1, 4)]), // Do4-Re4
        ],
      ),
      width: 560,
    );

    // 25) Üst ek çizgide bitişik ikili akorlar (ters sap): La5-Si5, Do6-Re6,
    // Mi6-Fa6. İkinci notabaşı sapın soluna ofsetlenir.
    await _render(
      tester,
      '25_bitisik_ust_ek',
      MusicNotation(
        beatsPerMeasure: 3,
        values: [
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(5, 5), _n(6, 5)]), // La5-Si5
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(0, 6), _n(1, 6)]), // Do6-Re6
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(2, 6), _n(3, 6)]), // Mi6-Fa6
        ],
      ),
      width: 560,
    );

    // 26) Ek çizgi bölgesinde çizgi/boşluk başlangıçlı ikili karışımı:
    // Si3-Do4 (boşluk+çizgi, alt), Sol5-La5 (çizgi... boşluk+ek, üst),
    // Do6-Re6 (2.üst ek).
    await _render(
      tester,
      '26_bitisik_karisik',
      MusicNotation(
        beatsPerMeasure: 3,
        values: [
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(6, 3), _n(0, 4)]), // Si3-Do4
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(4, 5), _n(5, 5)]), // Sol5-La5
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(0, 6), _n(1, 6)]), // Do6-Re6
        ],
      ),
      width: 560,
    );

    // 27) Ek çizgide bitişik ikili + aksidan: Do♯4-Re♯4 (alt), La♭5-Si♭5 (üst).
    await _render(
      tester,
      '27_bitisik_aksidan_ek',
      MusicNotation(
        beatsPerMeasure: 2,
        values: [
          MusicalValue(
            duration: MusicalDuration.quarter,
            midiNotes: [
              _n(0, 4, MusicalAccidental.sharp),
              _n(1, 4, MusicalAccidental.sharp),
            ], // Do♯4-Re♯4
          ),
          MusicalValue(
            duration: MusicalDuration.quarter,
            midiNotes: [
              _n(5, 5, MusicalAccidental.flat),
              _n(6, 5, MusicalAccidental.flat),
            ], // La♭5-Si♭5
          ),
        ],
      ),
      width: 560,
    );

    // 28) Üç sesli akor ek çizgide, bitişik ikili içeren: La3-Do4-Re4 (alt),
    // La5-Do6-Re6 (üst).
    await _render(
      tester,
      '28_uc_ses_ek_bitisik',
      MusicNotation(
        beatsPerMeasure: 2,
        values: [
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(5, 3), _n(0, 4), _n(1, 4)]), // La3-Do4-Re4
          MusicalValue(duration: MusicalDuration.quarter,
              midiNotes: [_n(5, 5), _n(0, 6), _n(1, 6)]), // La5-Do6-Re6
        ],
      ),
      width: 560,
    );
  });
}
