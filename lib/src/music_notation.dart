import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_music_core/flutter_music_core.dart';
import 'package:flutter_musical_notation/src/music_notation_painter.dart';
import 'package:flutter_musical_notation/src/notation_layout.dart';
import 'package:flutter_musical_notation/src/notation_measure.dart';

/// Porte üzerinde nota dizen widget.
///
/// İçerik [measures] ile ölçü ölçü verilir; her ölçü [Single] ve [Beam]
/// öğelerinden oluşur. Kiriş gruplaması çağıranın kararıdır — özellikle aksak
/// ölçülerde (5/8'in 3+2 / 2+3 yazımı gibi) gruplama müzikal anlam taşır:
///
/// ```dart
/// MusicNotation(
///   beatsPerMeasure: 5,
///   beatUnit: MusicalDuration.eighth,
///   measures: [
///     NotationMeasure([Beam([e, e, e]), Beam([e, e])]), // 3+2
///   ],
/// )
/// ```
///
/// Ritim egzersizleri için tek çizgili dizek: [MusicNotation.rhythm].
class MusicNotation extends StatelessWidget {
  final int beatsPerMeasure;
  final MusicalDuration beatUnit;
  final Color color;
  final bool isEnd;
  final Clef clef;
  final KeySignature keySignature;
  final double height;
  final bool horizontallyCenterNotes;
  final bool drawClef;
  final bool drawTimeSignature;
  final bool rhythmStaff;
  final List<NotationMeasure> measures;

  /// Satır (sistem) başına **azami** ölçü sayısı; null = hepsi tek satırda.
  /// Dar/dikey ekranda ölçüler alta sarar — [height] o zaman **satır başına**
  /// yüksekliği belirtir, widget `satırSayısı × height` kadar yer kaplar.
  ///
  /// **Her satır sağa kadar doldurulur** (justified): 3 ölçü + 2/satır → ilk
  /// satırda 2 ölçü, ikinci satırda 1 ölçü ve o tek ölçü satırı tam kaplar.
  /// Ölçü imi yalnız ilk satıra yazılır (gravür kuralı), anahtar her satırda
  /// tekrarlanır.
  final int? measuresPerLine;

  /// Bir nota/susa dokunulduğunda çağrılır (nota düzeyinde çalma için).
  /// Dokunma hedefi değerin **zaman dilimidir**, glif kutusu değil: aradaki
  /// boşluklar da en yakın değere sayılır.
  final void Function(NotationHit hit)? onValueTap;

  /// Çalım imleci: değeri **birlik nota** cinsinden müzikal an (null = gizli).
  /// Değiştikçe yalnız yeniden boyanır (widget yeniden kurulmaz), böylece
  /// çubuk akıcı ilerler — MuseScore/Finale'deki oynatma çubuğu gibi.
  final ValueListenable<double?>? playhead;

  final Color? playheadColor;

  /// Notaların **altına** çizilen zaman-konumlu işaretler (kullanıcı tap geri
  /// bildirimi: kırmızı nokta / yeşil onay / kırmızı çarpı). Değiştikçe widget
  /// yeniden kurulur (düşük frekanslı — playhead gibi abone değildir).
  final List<NotationMarker> markers;

  const MusicNotation({
    this.beatsPerMeasure = 4,
    this.beatUnit = MusicalDuration.quarter,
    this.color = Colors.black,
    this.isEnd = true,
    this.clef = Clef.treble,
    this.keySignature = KeySignature.none,
    this.height = 150,
    this.horizontallyCenterNotes = false,
    this.drawClef = true,
    this.drawTimeSignature = true,
    this.measures = const [],
    this.measuresPerLine,
    this.onValueTap,
    this.playhead,
    this.playheadColor,
    this.markers = const [],
    super.key,
  }) : rhythmStaff = false;

  /// Tek çizgili ritim dizeği: bütün notalar perdeden bağımsız çizginin
  /// üzerine oturur, saplar yukarı bakar, anahtar olarak perküsyon anahtarı
  /// çizilir. Ritim okuma/tekrar egzersizlerinin standart gösterimi.
  const MusicNotation.rhythm({
    this.beatsPerMeasure = 4,
    this.beatUnit = MusicalDuration.quarter,
    this.color = Colors.black,
    this.isEnd = true,
    this.height = 150,
    this.horizontallyCenterNotes = false,
    this.drawClef = true,
    this.drawTimeSignature = true,
    this.measures = const [],
    this.measuresPerLine,
    this.onValueTap,
    this.playhead,
    this.playheadColor,
    this.markers = const [],
    super.key,
  }) : rhythmStaff = true,
       clef = Clef.treble, // ritim dizeğinde kullanılmaz
       keySignature = KeySignature.none; // ritim dizeğinde donanım yoktur

  /// Notasyon katmanının painter'ı. Playhead **buraya verilmez** — ayrı bir
  /// overlay katmanında çizilir ki imleç hareket ederken notasyon (dizek,
  /// anahtar glifi, notalar) yeniden çizilmesin (performans). [layout]
  /// verilirse overlay ile aynı yerleşim paylaşılır.
  MusicNotationPainter _painter({NotationLayout? layout}) => MusicNotationPainter(
        beatsPerMeasure: beatsPerMeasure,
        beatUnit: beatUnit,
        color: color,
        clef: clef,
        keySignature: keySignature,
        isEnd: isEnd,
        horizontallyCenterNotes: horizontallyCenterNotes,
        drawClef: drawClef,
        drawTimeSignature: drawTimeSignature,
        rhythmStaff: rhythmStaff,
        measures: measures,
        measuresPerLine: measuresPerLine,
        markers: markers,
        presetLayout: layout,
      );

  /// Kaç satıra (sisteme) sarıldığı — widget yüksekliği bunun katıdır.
  int get lineCount {
    final perLine = measuresPerLine;
    if (perLine == null || perLine < 1) return 1;
    final count = measures.isEmpty ? 1 : measures.length;
    return (count / perLine).ceil();
  }

  /// Widget'ın toplam yüksekliği: `satırSayısı × height`.
  double get totalHeight => height * lineCount;

  /// Bu yapılandırmanın [size] için yerleşimi (zaman↔x, dokunma hedefleri).
  /// Çağıran, çizimle birebir aynı hesabı görür.
  NotationLayout layoutFor(Size size) => _painter().layoutFor(size);

  @override
  Widget build(BuildContext context) {
    // Basit yol: imleç ve dokunma yoksa tek katman çizim.
    if (playhead == null && onValueTap == null) {
      return SizedBox(
        height: totalHeight,
        width: double.infinity,
        child: CustomPaint(painter: _painter()),
      );
    }

    // İmleç/dokunma varsa gerçek yerleşim gerekir (LayoutBuilder genişliği
    // verir). Notasyon ve imleç **aynı** [layout] instance'ını paylaşır.
    return SizedBox(
      height: totalHeight,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, totalHeight);
          final layout = layoutFor(size);

          // Notasyon katmanı ayrı bir RepaintBoundary'de: imleç hareket
          // ederken (20 fps) bu katman YENİDEN BOYANMAZ — yalnız aşağıdaki
          // ince imleç çizgisi kendi katmanında repaint eder. Böylece dizek/
          // anahtar/nota glifleri her karede yeniden çizilmez (kasma önlemi).
          Widget content = RepaintBoundary(
            child: CustomPaint(painter: _painter(layout: layout)),
          );

          if (playhead != null) {
            content = Stack(
              fit: StackFit.expand,
              children: [
                content,
                CustomPaint(
                  painter: _PlayheadPainter(
                    layout: layout,
                    playhead: playhead!,
                    color: playheadColor ?? color,
                  ),
                ),
              ],
            );
          }

          if (onValueTap != null) {
            content = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final hit = layout.hitAt(details.localPosition);
                if (hit != null) onValueTap!(hit);
              },
              child: content,
            );
          }

          return content;
        },
      ),
    );
  }
}

/// Yalnız çalım imlecini (dikey çubuk) çizen hafif üst katman. Notasyondan
/// **ayrı** bir CustomPaint'tir ve `super(repaint: playhead)` ile yalnız
/// kendisi yeniden boyanır — notasyon katmanına dokunmaz (MuseScore/Finale
/// deseninde imleç akıcı ilerlerken notalar yeniden çizilmez).
class _PlayheadPainter extends CustomPainter {
  _PlayheadPainter({
    required this.layout,
    required this.playhead,
    required this.color,
  }) : super(repaint: playhead);

  final NotationLayout layout;
  final ValueListenable<double?> playhead;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final time = playhead.value;
    if (time == null) return;
    final sp = layout.sp;
    final x = layout.xForTime(time);
    final centerY = layout.centerYOf(layout.lineForTime(time));
    final paint = Paint()
      ..color = color
      ..strokeWidth = sp * 0.18; // ≈ stemThickness × 1.5
    // Porte yüksekliğinin biraz dışına taşar ki notalar arasında kaybolmasın.
    canvas.drawLine(
      Offset(x, centerY - 3 * sp),
      Offset(x, centerY + 3 * sp),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PlayheadPainter old) =>
      old.layout != layout || old.color != color;
}
