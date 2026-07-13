import 'package:flutter/material.dart';
import 'package:flutter_music_core/flutter_music_core.dart';
import 'package:flutter_musical_notation/src/music_notation_painter.dart';
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
    super.key,
  }) : rhythmStaff = true,
       clef = Clef.treble, // ritim dizeğinde kullanılmaz
       keySignature = KeySignature.none; // ritim dizeğinde donanım yoktur

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: MusicNotationPainter(
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
        ),
      ),
    );
  }
}
