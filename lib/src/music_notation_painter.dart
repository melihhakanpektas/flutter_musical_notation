import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_music_core/flutter_music_core.dart';
import 'package:flutter_musical_notation/src/notation_measure.dart';
import 'package:flutter_musical_notation/src/smufl.dart';

/// SMuFL (Bravura) tabanlı porte/nota çizici.
///
/// Koordinat sistemi **staff space** (sp) birimindedir: 1 sp = iki porte çizgisi
/// arası = fontSize / 4. Bütün gliflerin (notabaşı, sap, bayrak, aksidan,
/// anahtar, sus, rakam) konumu fontun kendi metadata'sından ([Smufl]) gelir.
///
/// Dikey konumlandırma diatonik "porte konumu" üzerinden yürür: [_staffIndex],
/// anahtarın ilk boşluğundaki notaya göre kaç diatonik adım (yarım boşluk)
/// uzakta olduğunu verir (aşağı = artı). Bu, tüm anahtarlar için tek formülle
/// çalışır çünkü [Clef.firstSpaceMidiNote] her zaman alttan ilk boşluğu gösterir.
///
/// İçerik [NotationMeasure] listesiyle ölçü ölçü verilir; kiriş (beam)
/// gruplaması çağıranın kararıdır ([Beam]). [rhythmStaff] true ise tek çizgili
/// ritim dizeği çizilir: bütün notabaşları çizginin üzerine oturur, saplar
/// yukarı bakar, anahtar olarak perküsyon anahtarı kullanılır.
class MusicNotationPainter extends CustomPainter {
  final int beatsPerMeasure;
  final MusicalDuration beatUnit;
  final Color color;
  final Clef clef;
  final KeySignature keySignature;
  final bool isEnd;
  final bool horizontallyCenterNotes;
  final bool drawClef;
  final bool drawTimeSignature;
  final bool rhythmStaff;
  final List<NotationMeasure> measures;

  MusicNotationPainter({
    this.beatsPerMeasure = 4,
    this.beatUnit = MusicalDuration.quarter,
    this.color = Colors.black,
    this.clef = Clef.treble,
    this.keySignature = KeySignature.none,
    this.isEnd = true,
    this.horizontallyCenterNotes = false,
    this.drawClef = true,
    this.drawTimeSignature = true,
    this.rhythmStaff = false,
    this.measures = const [],
  });

  // Çizim boyunca sabit geometri (paint başında hesaplanır).
  late double _sp; // staff space (px)
  late double _fontSize; // 4 * sp
  late double _centerY; // orta porte çizgisi (3. çizgi)

  /// Bağ (tie) için son çizilen nota olayının tutturma bilgisi: notabaşı
  /// konumları (porte konumu + sol/sağ kenar x) — paint başında sıfırlanır,
  /// sus görülünce temizlenir. Bağlar ölçü ve kiriş sınırlarını doğal olarak
  /// aşabilir (senkop yazımının gereği).
  ({List<({int index, double xLeft, double xRight})> heads})? _tiePrev;

  // Porte çizgileri odd staff-index'te (üst -7 … alt +1), boşluklar even'de.
  static const int _topLineIndex = -7;
  static const int _bottomLineIndex = 1;

  /// Orta çizginin porte konumu (tek çizgili dizekte notaların oturduğu yer).
  static const int _midLineIndex = -3;

  // ---------------------------------------------------------------------------
  // Geometri yardımcıları
  // ---------------------------------------------------------------------------

  /// Notanın diatonik porte konumu (anahtarın ilk boşluğuna göre; aşağı = +).
  /// Ritim dizeğinde perde yoksayılır: her nota çizginin üzerindedir.
  int _staffIndex(MidiNote note) =>
      rhythmStaff
          ? _midLineIndex
          : clef.firstSpaceMidiNote.expandedIndex - note.expandedIndex;

  /// Porte konumunun (yarım boşluk indeksi) piksel y'si. Orta çizgi index -3.
  double _yForIndex(int index) => _centerY + (index + 3) * (_sp / 2);

  /// Anchor'ı (staff space, +y yukarı) glif origin'ine göre canvas noktasına
  /// çevirir.
  Offset _anchor(double originX, double originY, SpPoint a) =>
      Offset(originX + a.x * _sp, originY - a.yUp * _sp);

  TextPainter _painter(String glyph, {Color? color, double sizeSp = 4}) {
    return TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontFamily: Smufl.fontFamily,
          package: Smufl.fontPackage,
          fontSize: _sp * sizeSp,
          color: color ?? this.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// Glifi, SMuFL origin'i (baseline üzerinde, advance başlangıcı) canvas
  /// [originX],[originY] noktasına gelecek şekilde çizer ve advance genişliğini
  /// (px) döndürür. TextPainter kutunun sol-üstünü verilen noktaya koyar;
  /// baseline'ı kutu tepesinden [baseline] kadar aşağıdadır, bu yüzden y'yi
  /// origin baseline'a hizalamak için geri çekeriz.
  double _drawGlyph(
    Canvas canvas,
    String glyph,
    double originX,
    double originY, {
    Color? color,
    double sizeSp = 4,
  }) {
    final tp = _painter(glyph, color: color, sizeSp: sizeSp);
    final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(canvas, Offset(originX, originY - baseline));
    return tp.width;
  }

  double _glyphWidth(String glyph, {double sizeSp = 4}) =>
      _painter(glyph, sizeSp: sizeSp).width;

  Paint _fill(Color c) =>
      Paint()
        ..color = c
        ..style = PaintingStyle.fill;

  // ---------------------------------------------------------------------------
  // paint
  // ---------------------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    _fontSize = size.height / 3;
    _sp = _fontSize / 4;
    _centerY = size.height / 2;
    _tiePrev = null;

    _drawStaffLines(canvas, size);

    double x = _sp; // sol kenar boşluğu

    if (drawClef) {
      x += _drawClef(canvas, x) + _sp;
    }
    final keyW = _drawKeySignature(canvas, x);
    if (keyW > 0) x += keyW + _sp;
    if (drawTimeSignature) {
      x += _drawTimeSignature(canvas, x) + _sp;
    }

    final endThickness =
        (isEnd ? Smufl.thickBarlineThickness : Smufl.thinBarlineThickness) * _sp;
    final regionLeft = x;
    final regionRight = size.width - endThickness - _sp * 0.25;
    final measureCount = measures.isEmpty ? 1 : measures.length;
    final measureWidth = (regionRight - regionLeft) / measureCount;

    _drawBarlines(canvas, regionLeft, measureWidth, measureCount);
    _drawNotes(canvas, regionLeft, measureWidth);
  }

  void _drawStaffLines(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = Smufl.staffLineThickness * _sp;
    final lineCount = rhythmStaff ? 1 : 5;
    for (int k = 0; k < lineCount; k++) {
      final y = _centerY + (k - (lineCount - 1) / 2) * _sp;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  double _drawClef(Canvas canvas, double x) {
    if (rhythmStaff) {
      // Perküsyon anahtarı dikeyde origin'e ortalıdır; çizgiye oturtulur.
      return _drawGlyph(canvas, Smufl.ch(Smufl.percussionClef), x, _centerY);
    }
    final c = Smufl.clef(clef);
    final refIndex = _staffIndex(c.refNote);
    return _drawGlyph(canvas, c.glyph, x, _yForIndex(refIndex));
  }

  /// Donanımı (anahtar sonrası diyez/bemol dizisi) çizer; kapladığı
  /// genişliği döndürür (donanımsızsa ve ritim dizeğinde 0).
  ///
  /// Konumlar klefe göre standart banttan hesaplanır: ilk aksidanın (diyezde
  /// Fa, bemolde Si) porte konumu klefin bandına oturtulur, sonrakiler sabit
  /// zikzak adımlarıyla (diyez +3/-4, bemol -3/+4) yerleşir. Sol/Fa/Do (alto)
  /// anahtarlarında standart gravürle birebir; tenor anahtarının diyez
  /// istisnası (Fa♯'ın alta alınması) uygulanmaz.
  double _drawKeySignature(Canvas canvas, double x) {
    final fifths = keySignature.fifths;
    if (rhythmStaff || fifths == 0) return 0;

    final sharps = fifths > 0;
    final glyph = Smufl.accidental(
      sharps ? MusicalAccidental.sharp : MusicalAccidental.flat,
    );

    // İlk aksidanın oktavı: porte konumu klefin standart bandına düşen tek
    // oktav seçilir (bant 7 konum genişliğinde olduğundan tektir).
    final letter = sharps ? 3 : 6; // Fa : Si
    final lo = sharps ? -11 : -4;
    final hi = sharps ? -5 : 0;
    int? index;
    for (var octave = 0; octave <= 9; octave++) {
      final candidate =
          clef.firstSpaceMidiNote.expandedIndex - (letter + 7 * octave);
      if (candidate >= lo && candidate <= hi) {
        index = candidate;
        break;
      }
    }
    assert(index != null, 'Donanım bandı bulunamadı: $clef');

    const sharpSteps = [3, -4, 3, 3, -4, 3];
    const flatSteps = [-3, 4, -3, 4, -3, 4];
    final steps = sharps ? sharpSteps : flatSteps;

    var dx = x;
    var currentIndex = index!;
    for (var i = 0; i < fifths.abs(); i++) {
      if (i > 0) currentIndex += steps[i - 1];
      dx += _drawGlyph(canvas, glyph, dx, _yForIndex(currentIndex));
    }
    return dx - x;
  }

  /// İki basamaklı ölçü imini üst üste çizer; kapladığı genişliği döndürür.
  double _drawTimeSignature(Canvas canvas, double x) {
    final num = beatsPerMeasure.toString();
    final den = beatUnit.value.toString();

    double widthOf(String s) => s
        .split('')
        .map((d) => _glyphWidth(Smufl.digit(int.parse(d))))
        .fold(0.0, (a, b) => a + b);

    final numW = widthOf(num);
    final denW = widthOf(den);
    final totalW = numW > denW ? numW : denW;

    void drawRow(String s, double rowW, double centerYRow) {
      var dx = x + (totalW - rowW) / 2;
      for (final ch in s.split('')) {
        dx += _drawGlyph(canvas, Smufl.digit(int.parse(ch)), dx, centerYRow);
      }
    }

    // Pay orta çizginin 1 sp üstünde, payda 1 sp altında ortalanır.
    drawRow(num, numW, _centerY - _sp);
    drawRow(den, denW, _centerY + _sp);
    return totalW;
  }

  void _drawBarlines(
    Canvas canvas,
    double regionLeft,
    double measureWidth,
    int measureCount,
  ) {
    // Tek çizgili dizekte de barlar standart porte yüksekliğinde (4 sp) çizilir.
    final topY = _centerY - 2 * _sp;
    final bottomY = _centerY + 2 * _sp;
    for (int i = 1; i <= measureCount; i++) {
      final boundaryX = regionLeft + i * measureWidth;
      final isFinal = i == measureCount && isEnd;
      final thickness =
          (isFinal ? Smufl.thickBarlineThickness : Smufl.thinBarlineThickness) *
          _sp;
      canvas.drawRect(
        Rect.fromLTRB(boundaryX - thickness, topY, boundaryX, bottomY),
        _fill(color),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Notalar
  // ---------------------------------------------------------------------------

  void _drawNotes(Canvas canvas, double regionLeft, double measureWidth) {
    final measureTimeLength = beatsPerMeasure * (1 / beatUnit.value);

    for (var m = 0; m < measures.length; m++) {
      final measure = measures[m];
      assert(
        measure.timeLength <= measureTimeLength + 1e-9,
        'Ölçü ${m + 1} taşıyor: ${measure.timeLength} > $measureTimeLength '
        '($beatsPerMeasure/${beatUnit.value})',
      );
      final innerLeft = regionLeft + m * measureWidth + measureWidth * 0.06;
      final innerWidth = measureWidth * 0.88;

      double originXAt(double cursorTime, MusicalValue value) {
        final slotX =
            innerLeft + (cursorTime / measureTimeLength) * innerWidth;
        if (!horizontallyCenterNotes) return slotX;
        final slotW = (value.timeLength / measureTimeLength) * innerWidth;
        final headW = Smufl.noteheadWidthOf(value.duration) * _sp;
        return slotX + slotW / 2 - headW / 2;
      }

      var cursorTime = 0.0;
      for (final element in measure.elements) {
        switch (element) {
          case Single(:final value):
            _drawValue(canvas, value, originXAt(cursorTime, value));
            cursorTime += value.timeLength;
          case Beam(:final values):
            final origins = <double>[];
            for (final v in values) {
              origins.add(originXAt(cursorTime, v));
              cursorTime += v.timeLength;
            }
            _drawBeamGroup(canvas, values, origins);
        }
      }
    }
  }

  // ---- Ortak değer yerleşimi -------------------------------------------------

  /// Değerin notalarını perdeye göre artan sıralar ve porte konumlarını verir.
  ({List<MidiNote> notes, List<int> indices}) _layoutIndices(
    MusicalValue value,
  ) {
    final notes = value.midiNotes.toList()
      ..sort((a, b) => a.expandedIndex.compareTo(b.expandedIndex));
    return (notes: notes, indices: notes.map(_staffIndex).toList());
  }

  /// İkili aralık (second) yer değiştirmesi: sap yönünde okuyarak, bir önceki
  /// yerleştirilmemiş notaya bir diatonik adım bitişik olan nota sapın öbür
  /// yanına kayar (dik sapta sağa, ters sapta sola). Her notabaşının x origin'i
  /// döner.
  List<double> _headOrigins(List<int> indices, bool stemUp, double originX) {
    final dispOffset = (Smufl.noteheadWidth - Smufl.stemThickness) * _sp;
    final order = List<int>.generate(indices.length, (i) => i);
    final readOrder = stemUp ? order : order.reversed.toList();

    final noteX = List<double>.filled(indices.length, originX);
    bool prevDisplaced = false;
    int? prevIndex;
    for (final i in readOrder) {
      var displaced = false;
      if (prevIndex != null &&
          (indices[i] - prevIndex).abs() == 1 &&
          !prevDisplaced) {
        displaced = true;
      }
      prevDisplaced = displaced;
      prevIndex = indices[i];
      if (displaced) {
        noteX[i] = stemUp ? originX + dispOffset : originX - dispOffset;
      }
    }
    return noteX;
  }

  /// Notabaşları + aksidanlar + ek çizgiler + uzatma noktaları — sap yönünden
  /// bağımsız ortak kısım. Çizilen başların (porte konumu, x) listesini
  /// döndürür (bağ tutturması için).
  List<({int index, double x})> _drawHeads({
    required Canvas canvas,
    required MusicalValue value,
    required List<MidiNote> notes,
    required List<int> indices,
    required List<double> noteX,
    required Color drawColor,
  }) {
    final headGlyph = Smufl.notehead(value.duration);
    final headW = Smufl.noteheadWidthOf(value.duration) * _sp;

    final blockLeft = noteX.reduce((a, b) => a < b ? a : b);
    _drawAccidentals(canvas, notes, indices, blockLeft, drawColor);

    for (var i = 0; i < notes.length; i++) {
      _drawGlyph(
        canvas,
        headGlyph,
        noteX[i],
        _yForIndex(indices[i]),
        color: drawColor,
      );
    }

    final heads = [
      for (var i = 0; i < notes.length; i++) (index: indices[i], x: noteX[i]),
    ];
    _drawLedgerLines(canvas, heads, headW, drawColor);
    if (value.dotted) {
      _drawAugmentationDots(canvas, heads, headW, drawColor);
    }
    return heads;
  }

  // ---- Bağ (tie) ---------------------------------------------------------------

  /// Gerekliyse önceki nota olayından bu olaya bağ çizer ve olayı bir sonraki
  /// bağ için kaydeder. Bağ, aynı porte konumundaki baş çiftleri arasına,
  /// notabaşı tarafına (sap yönünün tersine) çizilir.
  void _handleTie({
    required Canvas canvas,
    required MusicalValue value,
    required List<({int index, double x})> heads,
    required double headW,
    required bool tieAbove,
    required Color drawColor,
  }) {
    if (value.tiedToPrevious) {
      final prev = _tiePrev;
      assert(
        prev != null,
        'tiedToPrevious: önceki nota yok (ilk değer ya da sus sonrası).',
      );
      if (prev != null) {
        var drawn = false;
        for (final h in heads) {
          // Aynı porte konumundaki önceki başlardan en sağdakine bağlan.
          double? fromX;
          for (final p in prev.heads) {
            if (p.index == h.index && (fromX == null || p.xRight > fromX)) {
              fromX = p.xRight;
            }
          }
          if (fromX == null) continue;
          drawn = true;
          _drawTie(
            canvas: canvas,
            x0: fromX,
            x1: h.x,
            index: h.index,
            above: tieAbove,
            color: drawColor,
          );
        }
        assert(drawn, 'tiedToPrevious: aynı perdede önceki baş bulunamadı.');
      }
    }
    _tiePrev = (
      heads: [
        for (final h in heads) (index: h.index, xLeft: h.x, xRight: h.x + headW),
      ],
    );
  }

  /// Bağ eğrisi: uçları ince, ortası `tieMidpointThickness` kalınlığında
  /// mercek biçimli dolgu (iki kübik Bézier). Eğri yüksekliği bağ uzunluğuyla
  /// orantılı, 0.4–1.0 sp aralığına sıkıştırılır.
  void _drawTie({
    required Canvas canvas,
    required double x0,
    required double x1,
    required int index,
    required bool above,
    required Color color,
  }) {
    final dir = above ? -1.0 : 1.0;
    final gap = 0.1 * _sp;
    var sx = x0 + gap;
    var ex = x1 - gap;
    if (ex - sx < 0.5 * _sp) {
      // Çok kısa bağlarda boşluk bırakma; uçları başlara değdir.
      sx = x0;
      ex = x1;
    }
    final y = _yForIndex(index) + dir * 0.6 * _sp;
    final w = ex - sx;
    var arcH = w * 0.15;
    if (arcH < 0.4 * _sp) arcH = 0.4 * _sp;
    if (arcH > 1.0 * _sp) arcH = 1.0 * _sp;
    final h = dir * arcH;
    // Kontrol ofset farkı d: orta kalınlık ≈ 1.5·d → d = kalınlık / 1.5.
    final d = dir * (Smufl.tieMidpointThickness / 1.5) * _sp;

    final path =
        Path()
          ..moveTo(sx, y)
          ..cubicTo(sx + w / 3, y + h + d, ex - w / 3, y + h + d, ex, y)
          ..cubicTo(ex - w / 3, y + h - d, sx + w / 3, y + h - d, sx, y)
          ..close();
    canvas.drawPath(path, _fill(color));
  }

  // ---- Tek değer (kirişsiz) ---------------------------------------------------

  void _drawValue(Canvas canvas, MusicalValue value, double originX) {
    final drawColor = value.color ?? color;

    if (value.type == RhythmicType.rest) {
      _drawRest(canvas, value.duration, originX, drawColor);
      return;
    }

    final duration = value.duration;
    final layout = _layoutIndices(value);
    final indices = layout.indices;

    // Sap yönü: ortalama porte konumu orta çizginin (index -3) üstünde ise
    // (yani daha tiz) ters sap. Birlik notada sap yoktur; ritim dizeğinde
    // notalar çizgide (index -3) olduğundan sap hep yukarı bakar.
    final avgIndex = indices.reduce((a, b) => a + b) / indices.length;
    final stemDown = duration != MusicalDuration.whole && avgIndex < -3;
    final stemUp = !stemDown;

    final noteX = _headOrigins(indices, stemUp, originX);
    final heads = _drawHeads(
      canvas: canvas,
      value: value,
      notes: layout.notes,
      indices: indices,
      noteX: noteX,
      drawColor: drawColor,
    );
    _handleTie(
      canvas: canvas,
      value: value,
      heads: heads,
      headW: Smufl.noteheadWidthOf(duration) * _sp,
      // Notabaşı tarafı: sapın (birlikte "olası" sapın) tersi — süreden
      // bağımsız olarak konuma bakılır.
      tieAbove: avgIndex < -3,
      drawColor: drawColor,
    );

    if (duration != MusicalDuration.whole) {
      _drawStemAndFlag(
        canvas: canvas,
        duration: duration,
        originX: originX,
        indices: indices,
        stemUp: stemUp,
        color: drawColor,
      );
    }
  }

  void _drawRest(
    Canvas canvas,
    MusicalDuration duration,
    double originX,
    Color color,
  ) {
    _tiePrev = null; // sus, bağ zincirini keser
    // Sus dikey kaydı: birlik sus bir çizgiden sarkar (5 çizgide 4. çizgi,
    // tek çizgide çizginin kendisi), diğerleri orta çizgiye oturur.
    final originY = switch (duration) {
      MusicalDuration.whole => rhythmStaff ? _centerY : _centerY - _sp,
      _ => _centerY,
    };
    _drawGlyph(canvas, Smufl.rest(duration), originX, originY, color: color);
  }

  void _drawStemAndFlag({
    required Canvas canvas,
    required MusicalDuration duration,
    required double originX,
    required List<int> indices,
    required bool stemUp,
    required Color color,
  }) {
    final minIndex = indices.reduce((a, b) => a < b ? a : b); // en tiz (üst)
    final maxIndex = indices.reduce((a, b) => a > b ? a : b); // en pes (alt)
    final topY = _yForIndex(minIndex);
    final bottomY = _yForIndex(maxIndex);
    final stemLen = Smufl.stemLength * _sp;
    final stemThk = Smufl.stemThickness * _sp;
    final flag = Smufl.flag(duration);

    if (stemUp) {
      // Sap, en pes notabaşının sağ tutturma noktasından (stemUpSE) en tiz
      // notabaşının 3.5 sp üstüne uzanır.
      final attachBottom = _anchor(originX, bottomY, Smufl.stemUpSE);
      final stemRightX = attachBottom.dx;
      final stemTopY = topY - stemLen;
      canvas.drawRect(
        Rect.fromLTRB(stemRightX - stemThk, stemTopY, stemRightX, attachBottom.dy),
        _fill(color),
      );
      if (flag != null) {
        // Bayrağın stemUpNW anchor'ı sap tepesine (sol kenar) oturur.
        final flagOriginX = stemRightX - stemThk - flag.upAnchor.x * _sp;
        final flagOriginY = stemTopY + flag.upAnchor.yUp * _sp;
        _drawGlyph(canvas, flag.up, flagOriginX, flagOriginY, color: color);
      }
    } else {
      // Ters sap: en tiz notabaşının sol tutturma noktasından (stemDownNW) en
      // pes notabaşının 3.5 sp altına.
      final attachTop = _anchor(originX, topY, Smufl.stemDownNW);
      final stemLeftX = attachTop.dx;
      final stemBottomY = bottomY + stemLen;
      canvas.drawRect(
        Rect.fromLTRB(stemLeftX, attachTop.dy, stemLeftX + stemThk, stemBottomY),
        _fill(color),
      );
      if (flag != null) {
        // Bayrağın stemDownSW anchor'ı sap dibine (sol kenar) oturur.
        final flagOriginX = stemLeftX - flag.downAnchor.x * _sp;
        final flagOriginY = stemBottomY + flag.downAnchor.yUp * _sp;
        _drawGlyph(canvas, flag.down, flagOriginX, flagOriginY, color: color);
      }
    }
  }

  // ---- Kiriş (beam) grubu ------------------------------------------------------

  /// Kiriş grubunu çizer: ortak sap yönü, kirişe uzayan saplar, birincil kiriş
  /// ve süreye göre ikincil kirişler / kısmi kiriş uçları (beamlet).
  ///
  /// Kiriş bir glif değildir: sap uçlarından geçen (eğimi sınırlanmış) çizgi
  /// boyunca `beamThickness` kalınlığında paralelkenar olarak boyanır;
  /// ikincil kirişler `beamThickness + beamSpacing` aralıkla notabaşlarına
  /// doğru istiflenir (SMuFL `engravingDefaults`).
  void _drawBeamGroup(
    Canvas canvas,
    List<MusicalValue> values,
    List<double> origins,
  ) {
    final n = values.length;

    // 1) Yerleşim + grup sap yönü (tüm notaların ortalama porte konumu).
    final layouts = [for (final v in values) _layoutIndices(v)];
    final allIndices = [for (final l in layouts) ...l.indices];
    final avgIndex = allIndices.reduce((a, b) => a + b) / allIndices.length;
    final stemDown = avgIndex < -3; // ritim dizeğinde hep -3 → yukarı
    final stemUp = !stemDown;

    // 2) Başlar/aksidanlar/ek çizgiler/noktalar (bayrak çizilmez). Bağlar
    // soldan sağa olay sırasıyla işlenir (kiriş içi ve kirişe giren bağlar).
    for (var i = 0; i < n; i++) {
      final noteX = _headOrigins(layouts[i].indices, stemUp, origins[i]);
      final heads = _drawHeads(
        canvas: canvas,
        value: values[i],
        notes: layouts[i].notes,
        indices: layouts[i].indices,
        noteX: noteX,
        drawColor: values[i].color ?? color,
      );
      _handleTie(
        canvas: canvas,
        value: values[i],
        heads: heads,
        headW: Smufl.noteheadWidth * _sp, // kirişli süreler hep siyah baş
        tieAbove: stemDown,
        drawColor: values[i].color ?? color,
      );
    }

    // 3) Sap geometrisi: x (sapın dikey kenarı), tutturma y'si, ideal uç.
    final stemThk = Smufl.stemThickness * _sp;
    final stemLen = Smufl.stemLength * _sp;
    final stemX = <double>[];
    final attachY = <double>[];
    final idealTip = <double>[];
    for (var i = 0; i < n; i++) {
      final indices = layouts[i].indices;
      final minIndex = indices.reduce((a, b) => a < b ? a : b);
      final maxIndex = indices.reduce((a, b) => a > b ? a : b);
      if (stemUp) {
        final attach = _anchor(origins[i], _yForIndex(maxIndex), Smufl.stemUpSE);
        stemX.add(attach.dx); // sağ kenar
        attachY.add(attach.dy);
        idealTip.add(_yForIndex(minIndex) - stemLen);
      } else {
        final attach = _anchor(origins[i], _yForIndex(minIndex), Smufl.stemDownNW);
        stemX.add(attach.dx); // sol kenar
        attachY.add(attach.dy);
        idealTip.add(_yForIndex(maxIndex) + stemLen);
      }
    }

    // 4) Kiriş çizgisi: uç saplardan geçer, eğim ±1 sp ile sınırlanır, sonra
    // hiçbir sap standart boydan (3.5 sp) kısa kalmayacak şekilde ötelenir
    // (en yakın nota tam boyda, diğerleri uzar).
    final x0 = stemX.first;
    final x1 = stemX.last;
    var rise = idealTip.last - idealTip.first;
    if (rise > _sp) rise = _sp;
    if (rise < -_sp) rise = -_sp;
    final slope = x1 == x0 ? 0.0 : rise / (x1 - x0);
    double lineAt(double x) => idealTip.first + slope * (x - x0);

    var shift = idealTip[0] - lineAt(stemX[0]);
    for (var i = 1; i < n; i++) {
      final d = idealTip[i] - lineAt(stemX[i]);
      if (stemUp ? d < shift : d > shift) shift = d;
    }
    double beamYAt(double x) => lineAt(x) + shift;

    // 5) Saplar: tutturma noktasından kiriş çizgisine.
    for (var i = 0; i < n; i++) {
      final tipY = beamYAt(stemX[i]);
      final drawColor = values[i].color ?? color;
      if (stemUp) {
        canvas.drawRect(
          Rect.fromLTRB(stemX[i] - stemThk, tipY, stemX[i], attachY[i]),
          _fill(drawColor),
        );
      } else {
        canvas.drawRect(
          Rect.fromLTRB(stemX[i], attachY[i], stemX[i] + stemThk, tipY),
          _fill(drawColor),
        );
      }
    }

    // 6) Kirişler. Grup rengi: bütün değerler aynı rengi taşıyorsa o, yoksa
    // painter rengi.
    final firstColor = values.first.color;
    final beamColor =
        values.every((v) => v.color == firstColor)
            ? (firstColor ?? color)
            : color;
    final beamFill = _fill(beamColor);
    final beamThkPx = Smufl.beamThickness * _sp;
    final levelStep = (Smufl.beamThickness + Smufl.beamSpacing) * _sp;
    final towardHeads = stemUp ? 1.0 : -1.0;

    double leftEdge(int i) => stemUp ? stemX[i] - stemThk : stemX[i];
    double rightEdge(int i) => stemUp ? stemX[i] : stemX[i] + stemThk;

    void beamRect(double xa, double xb, int level) {
      final off = (level - 1) * levelStep * towardHeads;
      final ya = beamYAt(xa) + off;
      final yb = beamYAt(xb) + off;
      final h = beamThkPx * towardHeads;
      final path =
          Path()
            ..moveTo(xa, ya)
            ..lineTo(xb, yb)
            ..lineTo(xb, yb + h)
            ..lineTo(xa, ya + h)
            ..close();
      canvas.drawPath(path, beamFill);
    }

    // Birincil kiriş bütün grubu kapsar (Beam sözleşmesi: hepsi ≥ sekizlik).
    beamRect(leftEdge(0), rightEdge(n - 1), 1);

    // İkincil kirişler: seviye k, ardışık koşuları birleştirir; tek kalan nota
    // kısmi kiriş ucu (beamlet) alır — solunda komşusu varsa sola, yoksa sağa
    // bakar (noktalı sekizlik + onaltılık kalıbının standart yazımı).
    final levels = [for (final v in values) Smufl.beamCountOf(v.duration)];
    final maxLevel = levels.reduce((a, b) => a > b ? a : b);
    final beamletLen = Smufl.noteheadWidth * _sp;
    for (var k = 2; k <= maxLevel; k++) {
      var i = 0;
      while (i < n) {
        if (levels[i] < k) {
          i++;
          continue;
        }
        var j = i;
        while (j + 1 < n && levels[j + 1] >= k) {
          j++;
        }
        if (j > i) {
          beamRect(leftEdge(i), rightEdge(j), k);
        } else if (i > 0) {
          beamRect(rightEdge(i) - beamletLen, rightEdge(i), k);
        } else {
          beamRect(leftEdge(i), leftEdge(i) + beamletLen, k);
        }
        i = j + 1;
      }
    }
  }

  // ---- Aksidan / ek çizgi / nokta ----------------------------------------------

  void _drawAccidentals(
    Canvas canvas,
    List<MidiNote> notes,
    List<int> indices,
    double blockLeft,
    Color color,
  ) {
    // En tizden (üst) pese doğru; dikey olarak çakışan (2.5 sp'den yakın)
    // aksidanları bir öncekinin soluna kaydırarak istifler.
    final withAcc = <({int index, MidiNote note})>[
      for (var i = 0; i < notes.length; i++)
        if (notes[i].accidental != null) (index: indices[i], note: notes[i]),
    ]..sort((a, b) => a.index.compareTo(b.index));

    final baseRight = blockLeft - 0.3 * _sp;
    double? prevY, prevLeft;
    for (final entry in withAcc) {
      final glyph = Smufl.accidental(entry.note.accidental!);
      final w = _glyphWidth(glyph);
      final y = _yForIndex(entry.index);
      final double right;
      if (prevY != null && (prevY - y).abs() < 2.5 * _sp) {
        right = prevLeft! - 0.15 * _sp;
      } else {
        right = baseRight;
      }
      final originX = right - w;
      _drawGlyph(canvas, glyph, originX, y, color: color);
      prevY = y;
      prevLeft = originX;
    }
  }

  void _drawLedgerLines(
    Canvas canvas,
    List<({int index, double x})> heads,
    double headW,
    Color color,
  ) {
    if (rhythmStaff) return; // tek çizgili dizekte ek çizgi yoktur
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = Smufl.legerLineThickness * _sp;
    final ext = Smufl.legerLineExtension * _sp;

    void drawSide(bool below) {
      final sideHeads =
          heads
              .where((h) => below ? h.index > _bottomLineIndex : h.index < _topLineIndex)
              .toList();
      if (sideHeads.isEmpty) return;
      final left = sideHeads.map((h) => h.x).reduce((a, b) => a < b ? a : b) - ext;
      final right =
          sideHeads.map((h) => h.x + headW).reduce((a, b) => a > b ? a : b) + ext;

      if (below) {
        final maxIndex = sideHeads.map((h) => h.index).reduce((a, b) => a > b ? a : b);
        for (var L = _bottomLineIndex + 2; L <= maxIndex; L += 2) {
          final y = _yForIndex(L);
          canvas.drawLine(Offset(left, y), Offset(right, y), paint);
        }
      } else {
        final minIndex = sideHeads.map((h) => h.index).reduce((a, b) => a < b ? a : b);
        for (var L = _topLineIndex - 2; L >= minIndex; L -= 2) {
          final y = _yForIndex(L);
          canvas.drawLine(Offset(left, y), Offset(right, y), paint);
        }
      }
    }

    drawSide(true);
    drawSide(false);
  }

  void _drawAugmentationDots(
    Canvas canvas,
    List<({int index, double x})> heads,
    double headW,
    Color color,
  ) {
    final maxRight =
        heads.map((h) => h.x + headW).reduce((a, b) => a > b ? a : b);
    final dotX = maxRight + 0.35 * _sp;
    for (final h in heads) {
      var index = h.index;
      if (index.isOdd) index -= 1; // çizgideki nota → bir üst boşluk
      _drawGlyph(canvas, Smufl.ch(Smufl.augmentationDot), dotX, _yForIndex(index),
          color: color);
    }
  }

  @override
  bool shouldRepaint(covariant MusicNotationPainter oldDelegate) {
    return oldDelegate.beatsPerMeasure != beatsPerMeasure ||
        oldDelegate.beatUnit != beatUnit ||
        oldDelegate.color != color ||
        oldDelegate.clef != clef ||
        oldDelegate.keySignature != keySignature ||
        oldDelegate.isEnd != isEnd ||
        oldDelegate.horizontallyCenterNotes != horizontallyCenterNotes ||
        oldDelegate.drawClef != drawClef ||
        oldDelegate.drawTimeSignature != drawTimeSignature ||
        oldDelegate.rhythmStaff != rhythmStaff ||
        !listEquals(oldDelegate.measures, measures);
  }
}
