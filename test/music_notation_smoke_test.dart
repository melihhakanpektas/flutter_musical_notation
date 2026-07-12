import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_music_core/flutter_music_core.dart';
import 'package:flutter_musical_notation/flutter_musical_notation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paket fontunu test ortamına yükler (testlerde pubspec fontları otomatik
/// yüklenmez).
Future<void> _loadFont() async {
  final bytes = File('fonts/NotoMusic-Regular.ttf').readAsBytesSync();
  final loader = FontLoader('NotoMusic')
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<void> _pump(WidgetTester tester, MusicNotation notation) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 420, height: 160, child: notation),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(_loadFont);

  testWidgets('renders single notes, dotted values, chords with seconds, '
      'rotated stems and rests without errors', (tester) async {
    await _pump(
      tester,
      MusicNotation(
        beatsPerMeasure: 2,
        values: [
          MusicalValue(
            duration: MusicalDuration.quarter,
            dotted: true,
            midiNotes: [MidiNote(index: 4, octave: 4)],
          ),
          MusicalValue(
            duration: MusicalDuration.eighth,
            midiNotes: [MidiNote(index: 5, octave: 4)],
          ),
        ],
      ),
    );

    await _pump(
      tester,
      MusicNotation(
        values: [
          MusicalValue(
            duration: MusicalDuration.quarter,
            dotted: true,
            midiNotes: [
              MidiNote(index: 0, octave: 4),
              MidiNote(index: 1, octave: 4), // ikili aralık (second)
              MidiNote(index: 4, octave: 4),
            ],
          ),
          MusicalValue(
            duration: MusicalDuration.eighth,
            midiNotes: [MidiNote(index: 5, octave: 5)], // ters sap + ledger
          ),
          MusicalValue(
            type: RhythmicType.rest,
            duration: MusicalDuration.quarter,
          ),
          MusicalValue(
            duration: MusicalDuration.quarter,
            midiNotes: [MidiNote(index: 2, octave: 4)],
          ),
        ],
      ),
    );

    // 5/8 aksak ölçü + fa anahtarı.
    await _pump(
      tester,
      MusicNotation(
        beatsPerMeasure: 5,
        beatUnit: MusicalDuration.eighth,
        clef: Clef.bass,
        values: [
          MusicalValue(
            duration: MusicalDuration.eighth,
            midiNotes: [MidiNote(index: 4, octave: 2)],
          ),
          MusicalValue(
            duration: MusicalDuration.eighth,
            midiNotes: [MidiNote(index: 5, octave: 2)],
          ),
          MusicalValue(
            duration: MusicalDuration.quarter,
            midiNotes: [MidiNote(index: 6, octave: 2)],
          ),
          MusicalValue(
            duration: MusicalDuration.eighth,
            midiNotes: [MidiNote(index: 4, octave: 2)],
          ),
        ],
      ),
    );
  });

  test('MusicalValue.timeLength honors the dotted multiplier', () {
    expect(MusicalValue(duration: MusicalDuration.quarter).timeLength, 0.25);
    expect(
      MusicalValue(duration: MusicalDuration.quarter, dotted: true).timeLength,
      0.375,
    );
  });

  test('shouldRepaint reacts to field changes', () {
    final values = [MusicalValue()];
    final a = MusicNotationPainter(values: values);
    final b = MusicNotationPainter(values: values);
    final c = MusicNotationPainter(values: values, color: Colors.red);

    expect(a.shouldRepaint(b), isFalse);
    expect(a.shouldRepaint(c), isTrue);
  });
}
