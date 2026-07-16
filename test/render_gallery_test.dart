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
  final bytes = File('fonts/Bravura.otf').readAsBytesSync();
  // Painter fontu paket adıyla çözer (package: parametresi); test de aynı
  // efektif aile adı altında yüklemeli.
  final loader = FontLoader('packages/flutter_musical_notation/Bravura')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<void> _render(
  WidgetTester tester,
  String name,
  Widget notation, {
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

MusicalValue _v(
  MusicalDuration duration,
  List<MidiNote> notes, {
  bool dotted = false,
}) =>
    MusicalValue(duration: duration, dotted: dotted, midiNotes: notes);

MusicalValue _rest(MusicalDuration duration) =>
    MusicalValue(type: RhythmicType.rest, duration: duration);

void main() {
  testWidgets('render gallery', (tester) async {
    await _loadFont();

    // 1) Tek ses geri bildirimi: hedef nota tek başına (ortalanmış).
    await _render(
      tester,
      '01_tek_ses',
      MusicNotation(
        horizontallyCenterNotes: true,
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.whole, [_n(5, 4)]), // La4
          ]),
        ],
      ),
    );

    // 2) Çift ses (tam beşli, harmonik): Do4 + Sol4.
    await _render(
      tester,
      '02_cift_ses_besli',
      MusicNotation(
        horizontallyCenterNotes: true,
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.whole, [_n(0, 4), _n(4, 4)]),
          ]),
        ],
      ),
    );

    // 3) Çift ses ikili aralık (second) — notabaşı ofseti: Do4 + Re4.
    await _render(
      tester,
      '03_cift_ses_ikili',
      MusicNotation(
        horizontallyCenterNotes: true,
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.whole, [_n(0, 4), _n(1, 4)]),
          ]),
        ],
      ),
    );

    // 4) Üç ses: Do majör (Do4-Mi4-Sol4).
    await _render(
      tester,
      '04_uc_ses_major',
      MusicNotation(
        horizontallyCenterNotes: true,
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.whole, [_n(0, 4), _n(2, 4), _n(4, 4)]),
          ]),
        ],
      ),
    );

    // 5) Dört ses: Cmaj7 (Do4-Mi4-Sol4-Si4).
    await _render(
      tester,
      '05_dort_ses_cmaj7',
      MusicNotation(
        horizontallyCenterNotes: true,
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.whole, [_n(0, 4), _n(2, 4), _n(4, 4), _n(6, 4)]),
          ]),
        ],
      ),
    );

    // 6) Yüksek akor, ters sap: La4-Do5-Mi5 (dörtlük).
    await _render(
      tester,
      '06_ters_sap_akor',
      MusicNotation(
        horizontallyCenterNotes: true,
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(5, 4), _n(0, 5), _n(2, 5)]),
          ]),
        ],
      ),
    );

    // 7) Ritim paterni, 2/4, 2 ölçü: ♩ ♪♪ | ♪ ♩ ♪ (senkoplu, kirişsiz —
    // bağımsız bayraklar regresyon güvencesi).
    await _render(
      tester,
      '07_ritim_2_4',
      MusicNotation(
        beatsPerMeasure: 2,
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(4, 4)]),
            _v(MusicalDuration.eighth, [_n(4, 4)]),
            _v(MusicalDuration.eighth, [_n(4, 4)]),
          ]),
          NotationMeasure.singles([
            _v(MusicalDuration.eighth, [_n(4, 4)]),
            _v(MusicalDuration.quarter, [_n(4, 4)]),
            _v(MusicalDuration.eighth, [_n(4, 4)]),
          ]),
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
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(4, 4)], dotted: true),
            _v(MusicalDuration.eighth, [_n(4, 4)]),
          ]),
          NotationMeasure.singles([
            _v(MusicalDuration.eighth, [_n(4, 4)]),
            _v(MusicalDuration.quarter, [_n(4, 4)], dotted: true),
          ]),
        ],
      ),
      width: 560,
    );

    // 9) 5/8 aksak ölçü: ♪ ♪ ♩ ♪ (kirişsiz).
    await _render(
      tester,
      '09_ritim_5_8',
      MusicNotation(
        beatsPerMeasure: 5,
        beatUnit: MusicalDuration.eighth,
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.eighth, [_n(4, 4)]),
            _v(MusicalDuration.eighth, [_n(4, 4)]),
            _v(MusicalDuration.quarter, [_n(4, 4)]),
            _v(MusicalDuration.eighth, [_n(4, 4)]),
          ]),
        ],
      ),
    );

    // 10) Aksidanlar: Fa♯4 ve Si♭4.
    await _render(
      tester,
      '10_aksidanlar',
      MusicNotation(
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.half, [_n(3, 4, MusicalAccidental.sharp)]),
            _v(MusicalDuration.half, [_n(6, 4, MusicalAccidental.flat)]),
          ]),
        ],
      ),
    );

    // 11) Uç bölgeler: sol anahtarında La5 (üst ledger), Do4 (alt ledger).
    await _render(
      tester,
      '11_ledger_uclar',
      MusicNotation(
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.half, [_n(5, 5)]),
            _v(MusicalDuration.half, [_n(0, 4)]),
          ]),
        ],
      ),
    );

    // 12) Fa anahtarı, bas bölge: Mi2 (uygulama alt ucu) ve Do3.
    await _render(
      tester,
      '12_fa_anahtari_bas',
      MusicNotation(
        clef: Clef.bass,
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.half, [_n(2, 2)]),
            _v(MusicalDuration.half, [_n(0, 3)]),
          ]),
        ],
      ),
    );

    // 13) Üst ledger + ters saplı ikili aralık: La5+Si5 (dip dibe, çubuklu).
    await _render(
      tester,
      '13_ust_ikili_sapli',
      MusicNotation(
        horizontallyCenterNotes: true,
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(5, 5), _n(6, 5)]),
          ]),
        ],
      ),
    );

    // 14) Alt ledger + dik ikili aralık: Si3+Do4 (dip dibe, çubuklu).
    await _render(
      tester,
      '14_alt_ikili_sapli',
      MusicNotation(
        horizontallyCenterNotes: true,
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(6, 3), _n(0, 4)]),
          ]),
        ],
      ),
    );

    // 15) Alt bölgede çubuklu dizi: Do4-Re4-Mi4-Fa4 (dörtlükler, dip dibe).
    await _render(
      tester,
      '15_sapli_dizi_alt',
      MusicNotation(
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(0, 4)]),
            _v(MusicalDuration.quarter, [_n(1, 4)]),
            _v(MusicalDuration.quarter, [_n(2, 4)]),
            _v(MusicalDuration.quarter, [_n(3, 4)]),
          ]),
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
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.eighth, [_n(3, 5)]),
            _v(MusicalDuration.eighth, [_n(4, 5)]),
            _v(MusicalDuration.eighth, [_n(5, 5)]),
            _v(MusicalDuration.eighth, [_n(4, 5)]),
          ]),
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
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.sixteenth, [_n(3, 5)]),
            _v(MusicalDuration.sixteenth, [_n(5, 5)]),
            _v(MusicalDuration.sixteenth, [_n(2, 4)]),
            _v(MusicalDuration.sixteenth, [_n(4, 4)]),
            _v(MusicalDuration.quarter, [_n(4, 4)]),
          ]),
        ],
      ),
      width: 560,
    );

    // 18) Komple çıkan dizi Do4→Do6 (dörtlük). Dik→ters sap geçişinde
    // notabaşı hizası merdiven gibi düzgün olmalı; kayma varsa burada görünür.
    await _render(
      tester,
      '18_komple_dizi',
      MusicNotation(
        beatsPerMeasure: 4,
        measures: [
          NotationMeasure.singles([
            for (var index = 0; index <= 3; index++)
              _v(MusicalDuration.quarter, [_n(index, 4)]),
          ]),
          NotationMeasure.singles([
            for (var index = 4; index <= 6; index++)
              _v(MusicalDuration.quarter, [_n(index, 4)]),
            _v(MusicalDuration.quarter, [_n(0, 5)]),
          ]),
          NotationMeasure.singles([
            for (var index = 1; index <= 4; index++)
              _v(MusicalDuration.quarter, [_n(index, 5)]),
          ]),
          NotationMeasure.singles([
            for (var index = 5; index <= 6; index++)
              _v(MusicalDuration.quarter, [_n(index, 5)]),
            _v(MusicalDuration.quarter, [_n(0, 6)]),
            _rest(MusicalDuration.quarter),
          ]),
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
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(0, 4, MusicalAccidental.sharp)]),
            _v(MusicalDuration.quarter, [_n(1, 4, MusicalAccidental.sharp)]),
            _v(MusicalDuration.quarter, [_n(3, 4, MusicalAccidental.sharp)]),
            _v(MusicalDuration.quarter, [_n(4, 4, MusicalAccidental.sharp)]),
            _v(MusicalDuration.quarter, [_n(5, 4, MusicalAccidental.sharp)]),
          ]),
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
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(1, 4, MusicalAccidental.flat)]),
            _v(MusicalDuration.quarter, [_n(2, 4, MusicalAccidental.flat)]),
            _v(MusicalDuration.quarter, [_n(4, 4, MusicalAccidental.flat)]),
            _v(MusicalDuration.quarter, [_n(5, 4, MusicalAccidental.flat)]),
            _v(MusicalDuration.quarter, [_n(6, 4, MusicalAccidental.flat)]),
          ]),
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
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(0, 4), _n(1, 4)]),
            _v(MusicalDuration.quarter, [
              _n(0, 4, MusicalAccidental.sharp),
              _n(1, 4, MusicalAccidental.sharp),
            ]),
            _v(MusicalDuration.quarter, [
              _n(1, 4, MusicalAccidental.flat),
              _n(2, 4, MusicalAccidental.flat),
            ]),
          ]),
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
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(0, 4)]),
            _v(MusicalDuration.quarter, [_n(5, 3)]),
            _v(MusicalDuration.quarter, [_n(3, 3)]),
            _v(MusicalDuration.quarter, [_n(1, 3)]),
          ]),
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
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(5, 5)]),
            _v(MusicalDuration.quarter, [_n(0, 6)]),
            _v(MusicalDuration.quarter, [_n(2, 6)]),
            _v(MusicalDuration.quarter, [_n(4, 6)]),
          ]),
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
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(3, 3), _n(4, 3)]),
            _v(MusicalDuration.quarter, [_n(5, 3), _n(6, 3)]),
            _v(MusicalDuration.quarter, [_n(0, 4), _n(1, 4)]),
          ]),
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
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(5, 5), _n(6, 5)]),
            _v(MusicalDuration.quarter, [_n(0, 6), _n(1, 6)]),
            _v(MusicalDuration.quarter, [_n(2, 6), _n(3, 6)]),
          ]),
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
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(6, 3), _n(0, 4)]),
            _v(MusicalDuration.quarter, [_n(4, 5), _n(5, 5)]),
            _v(MusicalDuration.quarter, [_n(0, 6), _n(1, 6)]),
          ]),
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
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [
              _n(0, 4, MusicalAccidental.sharp),
              _n(1, 4, MusicalAccidental.sharp),
            ]),
            _v(MusicalDuration.quarter, [
              _n(5, 5, MusicalAccidental.flat),
              _n(6, 5, MusicalAccidental.flat),
            ]),
          ]),
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
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(5, 3), _n(0, 4), _n(1, 4)]),
            _v(MusicalDuration.quarter, [_n(5, 5), _n(0, 6), _n(1, 6)]),
          ]),
        ],
      ),
      width: 560,
    );

    // ---- Kiriş (beam) senaryoları -------------------------------------------

    // 29) Kirişli sekizlik çiftleri, 2/4: Beam(♪♪) ×2 | Beam(♪♪♪♪).
    await _render(
      tester,
      '29_kiris_ciftler',
      MusicNotation(
        beatsPerMeasure: 2,
        measures: [
          NotationMeasure([
            Beam([
              _v(MusicalDuration.eighth, [_n(2, 4)]),
              _v(MusicalDuration.eighth, [_n(4, 4)]),
            ]),
            Beam([
              _v(MusicalDuration.eighth, [_n(5, 4)]),
              _v(MusicalDuration.eighth, [_n(4, 4)]),
            ]),
          ]),
          NotationMeasure([
            Beam([
              _v(MusicalDuration.eighth, [_n(2, 4)]),
              _v(MusicalDuration.eighth, [_n(3, 4)]),
              _v(MusicalDuration.eighth, [_n(4, 4)]),
              _v(MusicalDuration.eighth, [_n(5, 4)]),
            ]),
          ]),
        ],
      ),
      width: 560,
    );

    // 30) 5/8 aksak, 3+2 gruplama: Beam(♪♪♪) + Beam(♪♪).
    await _render(
      tester,
      '30_kiris_5_8_3_2',
      MusicNotation(
        beatsPerMeasure: 5,
        beatUnit: MusicalDuration.eighth,
        measures: [
          NotationMeasure([
            Beam([
              _v(MusicalDuration.eighth, [_n(4, 4)]),
              _v(MusicalDuration.eighth, [_n(4, 4)]),
              _v(MusicalDuration.eighth, [_n(4, 4)]),
            ]),
            Beam([
              _v(MusicalDuration.eighth, [_n(2, 4)]),
              _v(MusicalDuration.eighth, [_n(2, 4)]),
            ]),
          ]),
        ],
      ),
    );

    // 31) 5/8 aksak, 2+3 gruplama: Beam(♪♪) + Beam(♪♪♪) — 30 ile aynı
    // perdeler, sadece gruplama farklı; ikisinin farkı görselde net olmalı.
    await _render(
      tester,
      '31_kiris_5_8_2_3',
      MusicNotation(
        beatsPerMeasure: 5,
        beatUnit: MusicalDuration.eighth,
        measures: [
          NotationMeasure([
            Beam([
              _v(MusicalDuration.eighth, [_n(4, 4)]),
              _v(MusicalDuration.eighth, [_n(4, 4)]),
            ]),
            Beam([
              _v(MusicalDuration.eighth, [_n(2, 4)]),
              _v(MusicalDuration.eighth, [_n(2, 4)]),
              _v(MusicalDuration.eighth, [_n(2, 4)]),
            ]),
          ]),
        ],
      ),
    );

    // 32) Onaltılık kirişler: Beam(4×16) çift kiriş | karışık Beam(♪ 16 16)
    // ve Beam(16 16 ♪) — seviye-2 kiriş kısmi koşular.
    await _render(
      tester,
      '32_kiris_onaltilik',
      MusicNotation(
        beatsPerMeasure: 2,
        measures: [
          NotationMeasure([
            Beam([
              _v(MusicalDuration.sixteenth, [_n(0, 4)]),
              _v(MusicalDuration.sixteenth, [_n(1, 4)]),
              _v(MusicalDuration.sixteenth, [_n(2, 4)]),
              _v(MusicalDuration.sixteenth, [_n(3, 4)]),
            ]),
            Beam([
              _v(MusicalDuration.eighth, [_n(4, 4)]),
              _v(MusicalDuration.sixteenth, [_n(3, 4)]),
              _v(MusicalDuration.sixteenth, [_n(2, 4)]),
            ]),
          ]),
          NotationMeasure([
            Beam([
              _v(MusicalDuration.sixteenth, [_n(2, 4)]),
              _v(MusicalDuration.sixteenth, [_n(3, 4)]),
              _v(MusicalDuration.eighth, [_n(4, 4)]),
            ]),
            Single(_v(MusicalDuration.quarter, [_n(0, 4)])),
          ]),
        ],
      ),
      width: 560,
    );

    // 33) Noktalı sekizlik + onaltılık kirişi (beamlet): ♪. 16 | 16 ♪. —
    // onaltılığın ikinci kirişi kısmi uç olarak sola/sağa bakar.
    await _render(
      tester,
      '33_kiris_noktali_beamlet',
      MusicNotation(
        beatsPerMeasure: 2,
        measures: [
          NotationMeasure([
            Beam([
              _v(MusicalDuration.eighth, [_n(4, 4)], dotted: true),
              _v(MusicalDuration.sixteenth, [_n(2, 4)]),
            ]),
            Beam([
              _v(MusicalDuration.sixteenth, [_n(0, 4)]),
              _v(MusicalDuration.eighth, [_n(2, 4)], dotted: true),
            ]),
          ]),
          NotationMeasure([
            Beam([
              _v(MusicalDuration.eighth, [_n(4, 4)], dotted: true),
              _v(MusicalDuration.sixteenth, [_n(4, 4)]),
            ]),
            Beam([
              _v(MusicalDuration.eighth, [_n(4, 4)]),
              _v(MusicalDuration.eighth, [_n(4, 4)]),
            ]),
          ]),
        ],
      ),
      width: 560,
    );

    // 34) Eğimli kirişler: çıkan dizi (eğim yukarı, dik sap), yüksek inen dizi
    // (ters sap). Eğim ±1 sp ile sınırlı.
    await _render(
      tester,
      '34_kiris_egimli',
      MusicNotation(
        beatsPerMeasure: 2,
        measures: [
          NotationMeasure([
            Beam([
              _v(MusicalDuration.eighth, [_n(0, 4)]),
              _v(MusicalDuration.eighth, [_n(2, 4)]),
              _v(MusicalDuration.eighth, [_n(4, 4)]),
              _v(MusicalDuration.eighth, [_n(6, 4)]),
            ]),
          ]),
          NotationMeasure([
            Beam([
              _v(MusicalDuration.eighth, [_n(5, 5)]),
              _v(MusicalDuration.eighth, [_n(3, 5)]),
              _v(MusicalDuration.eighth, [_n(1, 5)]),
              _v(MusicalDuration.eighth, [_n(0, 5)]),
            ]),
          ]),
        ],
      ),
      width: 560,
    );

    // 35) Ters saplı kiriş + akor: yüksek bölgede Beam(akor ♪, ♪) ve tepe
    // notası uçta — sap boyları kirişe uzar.
    await _render(
      tester,
      '35_kiris_ters_sap_akor',
      MusicNotation(
        beatsPerMeasure: 2,
        measures: [
          NotationMeasure([
            Beam([
              _v(MusicalDuration.eighth, [_n(0, 5), _n(2, 5)]),
              _v(MusicalDuration.eighth, [_n(4, 5)]),
              _v(MusicalDuration.eighth, [_n(2, 5)]),
              _v(MusicalDuration.eighth, [_n(0, 5)]),
            ]),
          ]),
        ],
      ),
    );

    // ---- Tek çizgili ritim dizeği ---------------------------------------------

    // 36) Ritim dizeği, 2/4: ♩ Beam(♪♪) | Beam(♪♪) sus — perküsyon anahtarı,
    // notalar çizgide, saplar yukarı.
    await _render(
      tester,
      '36_ritim_dizek',
      MusicNotation.rhythm(
        beatsPerMeasure: 2,
        height: 110,
        measures: [
          NotationMeasure([
            Single(_v(MusicalDuration.quarter, [_n(0, 4)])),
            Beam([
              _v(MusicalDuration.eighth, [_n(0, 4)]),
              _v(MusicalDuration.eighth, [_n(0, 4)]),
            ]),
          ]),
          NotationMeasure([
            Beam([
              _v(MusicalDuration.eighth, [_n(0, 4)]),
              _v(MusicalDuration.eighth, [_n(0, 4)]),
            ]),
            Single(_rest(MusicalDuration.quarter)),
          ]),
        ],
      ),
      width: 560,
      height: 120,
    );

    // 37) Ritim dizeği, 5/8: 3+2 | 2+3 — kullanıcının belirlediği gruplama
    // aynı ölçü iminde iki farklı yazım verir.
    await _render(
      tester,
      '37_ritim_5_8_gruplar',
      MusicNotation.rhythm(
        beatsPerMeasure: 5,
        beatUnit: MusicalDuration.eighth,
        height: 110,
        measures: [
          NotationMeasure([
            Beam([
              _v(MusicalDuration.eighth, [_n(0, 4)]),
              _v(MusicalDuration.eighth, [_n(0, 4)]),
              _v(MusicalDuration.eighth, [_n(0, 4)]),
            ]),
            Beam([
              _v(MusicalDuration.eighth, [_n(0, 4)]),
              _v(MusicalDuration.eighth, [_n(0, 4)]),
            ]),
          ]),
          NotationMeasure([
            Beam([
              _v(MusicalDuration.eighth, [_n(0, 4)]),
              _v(MusicalDuration.eighth, [_n(0, 4)]),
            ]),
            Beam([
              _v(MusicalDuration.eighth, [_n(0, 4)]),
              _v(MusicalDuration.eighth, [_n(0, 4)]),
              _v(MusicalDuration.eighth, [_n(0, 4)]),
            ]),
          ]),
        ],
      ),
      width: 700,
      height: 120,
    );

    // 38) Ritim dizeği, noktalı değerler: ♩. Beam(♪. 16) | ♩ sus ♪ — nokta
    // çizginin üstündeki boşluğa çizilir.
    await _render(
      tester,
      '38_ritim_noktali',
      MusicNotation.rhythm(
        beatsPerMeasure: 3,
        beatUnit: MusicalDuration.quarter,
        height: 110,
        measures: [
          NotationMeasure([
            Single(_v(MusicalDuration.quarter, [_n(0, 4)], dotted: true)),
            Beam([
              _v(MusicalDuration.eighth, [_n(0, 4)], dotted: true),
              _v(MusicalDuration.sixteenth, [_n(0, 4)]),
            ]),
            Single(_v(MusicalDuration.eighth, [_n(0, 4)])),
          ]),
          NotationMeasure([
            Single(_v(MusicalDuration.quarter, [_n(0, 4)])),
            Single(_rest(MusicalDuration.quarter)),
            Single(_v(MusicalDuration.eighth, [_n(0, 4)])),
            Single(_v(MusicalDuration.eighth, [_n(0, 4)])),
          ]),
        ],
      ),
      width: 700,
      height: 120,
    );

    // ---- Donanım (key signature) ------------------------------------------------

    // 39) Diyezli donanım: La majör (3♯) — Fa♯ Do♯ Sol♯ anahtar sonrası;
    // melodide donanımın kapsadığı notalara ayrıca aksidan yazılmaz.
    await _render(
      tester,
      '39_donanim_diyez',
      MusicNotation(
        beatsPerMeasure: 4,
        keySignature: const KeySignature(3),
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.quarter, [_n(5, 4)]), // La4
            _v(MusicalDuration.quarter, [_n(6, 4)]), // Si4
            _v(MusicalDuration.quarter, [_n(0, 5)]), // Do♯5 (donanımdan)
            _v(MusicalDuration.quarter, [_n(2, 5)]), // Mi5
          ]),
        ],
      ),
      width: 560,
    );

    // 40) Bemollü donanım: Mi♭ majör (3♭) — Si♭ Mi♭ La♭.
    await _render(
      tester,
      '40_donanim_bemol',
      MusicNotation(
        beatsPerMeasure: 4,
        keySignature: const KeySignature(-3),
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.half, [_n(2, 4)]), // Mi♭4 (donanımdan)
            _v(MusicalDuration.half, [_n(6, 4)]), // Si♭4 (donanımdan)
          ]),
        ],
      ),
      width: 560,
    );

    // 41) Fa anahtarında donanım: Re majör (2♯) — konumlar klefe göre kayar.
    await _render(
      tester,
      '41_donanim_bas',
      MusicNotation(
        clef: Clef.bass,
        keySignature: const KeySignature(2),
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.half, [_n(1, 3)]), // Re3
            _v(MusicalDuration.half, [_n(5, 2)]), // La2
          ]),
        ],
      ),
      width: 560,
    );

    // ---- Bağ (tie) ----------------------------------------------------------------

    // 42) Melodide bağlar: ölçü içi (Sol4, altta), ölçü aşırı (Sol4, barın
    // üstünden geçer) ve ters saplı bölgede (Re5, üstte).
    await _render(
      tester,
      '42_bag_melodi',
      MusicNotation(
        beatsPerMeasure: 4,
        measures: [
          NotationMeasure.singles([
            _v(MusicalDuration.half, [_n(0, 5)]),
            _v(MusicalDuration.quarter, [_n(4, 4)]),
            MusicalValue(
              duration: MusicalDuration.quarter,
              tiedToPrevious: true,
              midiNotes: [_n(4, 4)],
            ),
          ]),
          NotationMeasure.singles([
            MusicalValue(
              duration: MusicalDuration.half,
              tiedToPrevious: true, // ölçü aşırı bağ
              midiNotes: [_n(4, 4)],
            ),
            _v(MusicalDuration.quarter, [_n(1, 5)]),
            MusicalValue(
              duration: MusicalDuration.quarter,
              tiedToPrevious: true, // ters sap → bağ üstte
              midiNotes: [_n(1, 5)],
            ),
          ]),
        ],
      ),
      width: 700,
    );

    // 43) Ritim dizeğinde bağlar: kiriş içi bağ ve kirişten ölçü aşırı süs
    // notasına bağ (senkop yazımı).
    await _render(
      tester,
      '43_bag_ritim',
      MusicNotation.rhythm(
        beatsPerMeasure: 2,
        height: 110,
        measures: [
          NotationMeasure([
            Single(_v(MusicalDuration.quarter, [_n(0, 4)])),
            Beam([
              _v(MusicalDuration.eighth, [_n(0, 4)]),
              MusicalValue(
                duration: MusicalDuration.eighth,
                tiedToPrevious: true, // kiriş içi bağ
                midiNotes: [_n(0, 4)],
              ),
            ]),
          ]),
          NotationMeasure([
            Single(MusicalValue(
              duration: MusicalDuration.quarter,
              tiedToPrevious: true, // kirişten ölçü aşırı bağ
              midiNotes: [_n(0, 4)],
            )),
            Single(_rest(MusicalDuration.quarter)),
          ]),
        ],
      ),
      width: 560,
      height: 120,
    );

    // 44) Gerçek parça: Sol majör (1♯), iki satır (Column ile kompozisyon).
    // 2. satırda anahtar + donanım tekrarlanır, ölçü imi tekrarlanmaz;
    // kalın bitiş barı yalnız son satırda. Kirişler + ölçü aşırı bağ.
    await _render(
      tester,
      '44_gercek_parca',
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MusicNotation(
            beatsPerMeasure: 2,
            keySignature: const KeySignature(1),
            isEnd: false,
            height: 140,
            measures: [
              NotationMeasure([
                Beam([
                  _v(MusicalDuration.eighth, [_n(4, 4)]),
                  _v(MusicalDuration.eighth, [_n(5, 4)]),
                ]),
                Beam([
                  _v(MusicalDuration.eighth, [_n(6, 4)]),
                  _v(MusicalDuration.eighth, [_n(5, 4)]),
                ]),
              ]),
              NotationMeasure([
                Single(_v(MusicalDuration.quarter, [_n(6, 4)])),
                Single(_v(MusicalDuration.quarter, [_n(1, 5)])),
              ]),
              NotationMeasure([
                Beam([
                  _v(MusicalDuration.eighth, [_n(1, 5)]),
                  _v(MusicalDuration.eighth, [_n(0, 5)]),
                ]),
                Single(_v(MusicalDuration.quarter, [_n(6, 4)])),
              ]),
              NotationMeasure([
                Single(_v(MusicalDuration.half, [_n(5, 4)])),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          MusicNotation(
            beatsPerMeasure: 2,
            keySignature: const KeySignature(1),
            drawTimeSignature: false,
            height: 140,
            measures: [
              NotationMeasure([
                Beam([
                  _v(MusicalDuration.eighth, [_n(4, 4)]),
                  _v(MusicalDuration.eighth, [_n(6, 4)]),
                ]),
                Beam([
                  _v(MusicalDuration.eighth, [_n(1, 5)]),
                  _v(MusicalDuration.eighth, [_n(6, 4)]),
                ]),
              ]),
              NotationMeasure([
                Single(_v(MusicalDuration.quarter, [_n(0, 5)])),
                Single(_v(MusicalDuration.quarter, [_n(5, 4)])),
              ]),
              NotationMeasure([
                Single(MusicalValue(
                  duration: MusicalDuration.quarter,
                  tiedToPrevious: true, // ölçü aşırı bağ
                  midiNotes: [_n(5, 4)],
                )),
                Beam([
                  _v(MusicalDuration.eighth, [_n(4, 4)]),
                  _v(MusicalDuration.eighth, [_n(5, 4)]),
                ]),
              ]),
              NotationMeasure([
                Single(_v(MusicalDuration.half, [_n(4, 4)])),
              ]),
            ],
          ),
        ],
      ),
      width: 900,
      height: 320,
    );
  });
}
