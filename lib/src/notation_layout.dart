import 'package:flutter/material.dart';
import 'package:flutter_music_core/flutter_music_core.dart';
import 'package:flutter_musical_notation/src/notation_measure.dart';
import 'package:flutter_musical_notation/src/smufl.dart';

/// Notasyonda dokunulabilir tek bir değer: hangi ölçünün hangi öğesi, müzikal
/// zamanı ve ekrandaki dikdörtgeni.
///
/// Dikdörtgen değerin **zaman dilimidir** (glif kutusu değil): iki nota arası
/// boşluk kalmaz, dokunma hedefi büyük olur ve `horizontallyCenterNotes`
/// gibi görsel kaydırmalardan etkilenmez.
@immutable
class NotationHit {
  const NotationHit({
    required this.measureIndex,
    required this.elementIndex,
    required this.valueIndex,
    required this.value,
    required this.timeStart,
    required this.bounds,
  });

  /// 0 tabanlı ölçü sırası.
  final int measureIndex;

  /// Ölçü içindeki [NotationElement] sırası.
  final int elementIndex;

  /// Öğe bir [Beam] ise grup içindeki sıra; [Single] ise 0.
  final int valueIndex;

  final MusicalValue value;

  /// Notasyonun başından itibaren **birlik nota** cinsinden başlangıç anı
  /// (dörtlük = 0.25). [MusicNotation.playhead] ile aynı birim.
  final double timeStart;

  final Rect bounds;

  double get timeLength => value.timeLength;
}

/// Dizeğin altına konan zaman-konumlu işaret türü (kullanıcı tap geri
/// bildirimi): dolu nokta, onay (✓) veya çarpı (✗).
enum NotationMarkerKind { dot, check, cross }

/// Dizekte belirli bir müzikal ana konan işaret (notaların **altına** çizilir).
/// Playhead ve [NotationHit] ile aynı zaman birimini (**birlik nota**) ve aynı
/// [NotationLayout] eşlemesini kullanır → notalarla hizası garantidir.
///
/// Ritim tap egzersizlerinde kullanıcının vuruşlarını gösterir: cevap fazında
/// kırmızı [NotationMarkerKind.dot], geri bildirimde doğru zamanlı vuruşlar
/// yeşil [NotationMarkerKind.check], yanlış/fazladan olanlar kırmızı
/// [NotationMarkerKind.cross].
@immutable
class NotationMarker {
  const NotationMarker({
    required this.time,
    required this.kind,
    required this.color,
  });

  /// Notasyonun başından itibaren **birlik nota** cinsinden an (dörtlük = 0.25);
  /// [NotationHit.timeStart] / playhead ile aynı birim.
  final double time;

  final NotationMarkerKind kind;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is NotationMarker &&
      other.time == time &&
      other.kind == kind &&
      other.color == color;

  @override
  int get hashCode => Object.hash(time, kind, color);
}

/// Notasyonun ölçülebilir yerleşimi: müzikal zaman ↔ x eşlemesi ve dokunma
/// hedefleri.
///
/// Çizim (painter), dokunma (hit-test) ve playhead **aynı hesabı paylaşsın**
/// diye tek yerde toplanır; ayrı ayrı hesaplansalardı çubuk notaların üstüne
/// düşmez, dokunma hedefi kayardı.
///
/// Koordinatlar piksel; zaman birimi **birlik nota** ([MusicalValue.timeLength]
/// ile aynı).
class NotationLayout {
  NotationLayout({
    required this.size,
    this.beatsPerMeasure = 4,
    this.beatUnit = MusicalDuration.quarter,
    this.clef = Clef.treble,
    this.keySignature = KeySignature.none,
    this.isEnd = true,
    this.drawClef = true,
    this.drawTimeSignature = true,
    this.rhythmStaff = false,
    this.measures = const [],
    int? measuresPerLine,
  }) {
    measureTimeLength = beatsPerMeasure * (1 / beatUnit.value);
    measureCount = measures.isEmpty ? 1 : measures.length;
    this.measuresPerLine =
        (measuresPerLine == null || measuresPerLine < 1)
            ? measureCount
            : measuresPerLine;
    lineCount = (measureCount / this.measuresPerLine).ceil();
    lineHeight = size.height / lineCount;
    sp = (lineHeight / 3) / 4;

    // Ölçü imi yalnız ilk satırda yazılır (gravür kuralı); anahtar her
    // satırda tekrarlanır. Bu yüzden sonraki satırların nota bölgesi biraz
    // daha erken başlar — satırlar bağımsız hizalanır (standart davranış).
    _regionLeftByLine = [
      for (var line = 0; line < lineCount; line++) _computeRegionLeft(line),
    ];
    final endThickness =
        (isEnd ? Smufl.thickBarlineThickness : Smufl.thinBarlineThickness) * sp;
    final regionRight = size.width - endThickness - sp * 0.25;
    // **Her satır doldurulur** (justified): genişlik o satırdaki GERÇEK ölçü
    // sayısına bölünür. Yarım kalan satır da sağa kadar uzar — 3 ölçüde ikinci
    // satırdaki tek ölçü satırı tam kaplar, 1 ölçülük patern satırı boş
    // bırakmaz (kullanıcı kararı 2026-07-17).
    _measureWidthByLine = [
      for (var line = 0; line < lineCount; line++)
        (regionRight - _regionLeftByLine[line]) / measuresInLine(line),
    ];

    hits = _computeHits();
  }

  final Size size;
  final int beatsPerMeasure;
  final MusicalDuration beatUnit;
  final Clef clef;
  final KeySignature keySignature;
  final bool isEnd;
  final bool drawClef;
  final bool drawTimeSignature;
  final bool rhythmStaff;
  final List<NotationMeasure> measures;

  /// Staff space (px): 1 sp = iki porte çizgisi arası.
  late final double sp;

  /// Bir ölçünün birlik-nota cinsinden uzunluğu (4/4 → 1.0, 2/4 → 0.5).
  late final double measureTimeLength;
  late final int measureCount;

  /// Satır (sistem) başına ölçü sayısı — dar/dikey ekranda ölçüler alta sarar.
  late final int measuresPerLine;

  /// Kaç satıra sarıldı.
  late final int lineCount;

  /// Bir satırın (sistemin) piksel yüksekliği.
  late final double lineHeight;

  late final List<double> _regionLeftByLine;
  late final List<double> _measureWidthByLine;

  /// Soldan sağa, çizim sırasıyla dokunma hedefleri.
  late final List<NotationHit> hits;

  /// Notasyonun toplam müzikal uzunluğu (birlik nota).
  double get totalTimeLength => measureCount * measureTimeLength;

  /// [measureIndex] ölçüsünün bulunduğu satır.
  int lineOf(int measureIndex) => measureIndex ~/ measuresPerLine;

  /// [line] satırının porte orta çizgisinin y'si.
  double centerYOf(int line) => line * lineHeight + lineHeight / 2;

  /// [line] satırında notaların başladığı x.
  double regionLeftOf(int line) => _regionLeftByLine[line];

  /// [line] satırında bir ölçünün genişliği. Her satır sağa kadar
  /// doldurulduğundan yarım kalan satırın ölçüleri daha geniştir.
  double measureWidthOf(int line) => _measureWidthByLine[line];

  /// [line] satırındaki ölçü sayısı (son satır yarım kalabilir).
  int measuresInLine(int line) {
    final remaining = measureCount - line * measuresPerLine;
    return remaining < measuresPerLine ? remaining : measuresPerLine;
  }

  double _computeRegionLeft(int line) {
    var x = sp; // sol kenar boşluğu (painter ile aynı)
    if (drawClef) x += clefWidth + sp;
    final keyW = keySignatureWidth;
    if (keyW > 0) x += keyW + sp;
    // Ölçü imi yalnız ilk satırda.
    if (drawTimeSignature && line == 0) x += timeSignatureWidth + sp;
    return x;
  }

  // --- Ölçüm (çizmeden) ------------------------------------------------------

  double _glyphWidth(String glyph) {
    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontFamily: Smufl.fontFamily,
          package: Smufl.fontPackage,
          fontSize: sp * 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  double get clefWidth => rhythmStaff
      ? _glyphWidth(Smufl.ch(Smufl.percussionClef))
      : _glyphWidth(Smufl.clef(clef).glyph);

  double get keySignatureWidth {
    final fifths = keySignature.fifths;
    if (rhythmStaff || fifths == 0) return 0;
    final glyph = Smufl.accidental(
      fifths > 0 ? MusicalAccidental.sharp : MusicalAccidental.flat,
    );
    return _glyphWidth(glyph) * fifths.abs();
  }

  double get timeSignatureWidth {
    double widthOf(String s) => s
        .split('')
        .map((d) => _glyphWidth(Smufl.digit(int.parse(d))))
        .fold(0.0, (a, b) => a + b);
    final numW = widthOf(beatsPerMeasure.toString());
    final denW = widthOf(beatUnit.value.toString());
    return numW > denW ? numW : denW;
  }

  // --- Zaman ↔ x -------------------------------------------------------------

  /// Ölçünün notaların yerleştiği iç bölgesi (barlara yapışmasınlar diye
  /// kenarlardan pay bırakılır) — painter ile aynı oranlar.
  double _innerLeft(int measureIndex) {
    final line = lineOf(measureIndex);
    final indexInLine = measureIndex % measuresPerLine;
    final mw = measureWidthOf(line);
    return regionLeftOf(line) + indexInLine * mw + mw * 0.06;
  }

  double _innerWidth(int measureIndex) => measureWidthOf(lineOf(measureIndex)) * 0.88;

  /// [measureIndex] ölçüsünde, ölçü başından [timeInMeasure] kadar sonraki
  /// anın x'i.
  double slotX(int measureIndex, double timeInMeasure) =>
      _innerLeft(measureIndex) +
      (timeInMeasure / measureTimeLength) * _innerWidth(measureIndex);

  /// [time] anının düştüğü ölçü (sınırlar kırpılır).
  int measureForTime(double time) {
    if (time <= 0) return 0;
    if (time >= totalTimeLength) return measureCount - 1;
    return (time / measureTimeLength).floor();
  }

  /// [time] anının bulunduğu satır — playhead doğru sistemde çizilsin diye.
  int lineForTime(double time) => lineOf(measureForTime(time));

  /// Notasyonun başından itibaren [time] anının x'i — playhead bunu izler.
  /// Sınırların dışı kırpılır. Çok satırlıda x, o anın **kendi satırındaki**
  /// konumudur (satır için bkz. [lineForTime]).
  double xForTime(double time) {
    if (time <= 0) return slotX(0, 0);
    if (time >= totalTimeLength) {
      return slotX(measureCount - 1, measureTimeLength);
    }
    final measureIndex = measureForTime(time);
    return slotX(measureIndex, time - measureIndex * measureTimeLength);
  }

  // --- Dokunma ---------------------------------------------------------------

  List<NotationHit> _computeHits() {
    final out = <NotationHit>[];
    for (var m = 0; m < measures.length; m++) {
      var cursorTime = 0.0;
      final elements = measures[m].elements;
      for (var e = 0; e < elements.length; e++) {
        final element = elements[e];
        final values = switch (element) {
          Single(:final value) => [value],
          Beam(:final values) => values,
        };
        for (var v = 0; v < values.length; v++) {
          final value = values[v];
          final left = slotX(m, cursorTime);
          final right = slotX(m, cursorTime + value.timeLength);
          // Dikey hedef, ölçünün kendi SATIRININ bandıdır (çok satırlıda
          // dokunma başka satıra taşmaz).
          final line = lineOf(m);
          out.add(NotationHit(
            measureIndex: m,
            elementIndex: e,
            valueIndex: v,
            value: value,
            timeStart: m * measureTimeLength + cursorTime,
            bounds: Rect.fromLTRB(
              left,
              line * lineHeight,
              right,
              (line + 1) * lineHeight,
            ),
          ));
          cursorTime += value.timeLength;
        }
      }
    }
    return out;
  }

  /// [position] noktasındaki değer; boşluğa denk gelirse null.
  NotationHit? hitAt(Offset position) {
    for (final hit in hits) {
      if (hit.bounds.contains(position)) return hit;
    }
    return null;
  }
}
