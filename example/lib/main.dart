import 'package:flutter/material.dart';
import 'package:flutter_music_core/flutter_music_core.dart';
import 'package:flutter_musical_notation/flutter_musical_notation.dart';

void main() {
  runApp(const MainApp());
}

MusicalValue _note(int index, int octave, MusicalDuration duration,
        {bool dotted = false}) =>
    MusicalValue(
      duration: duration,
      dotted: dotted,
      midiNotes: [MidiNote(index: index, octave: octave)],
    );

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Perdeli dizek: kirişli sekizlikler + tek değerler.
                MusicNotation(
                  color: Colors.white,
                  measures: [
                    NotationMeasure([
                      Single(_note(0, 4, MusicalDuration.quarter)),
                      Beam([
                        _note(2, 4, MusicalDuration.eighth),
                        _note(4, 4, MusicalDuration.eighth),
                      ]),
                      Beam([
                        _note(5, 4, MusicalDuration.eighth),
                        _note(4, 4, MusicalDuration.sixteenth),
                        _note(2, 4, MusicalDuration.sixteenth),
                      ]),
                      Single(_note(0, 4, MusicalDuration.quarter)),
                    ]),
                    NotationMeasure([
                      Beam([
                        _note(5, 5, MusicalDuration.eighth),
                        _note(4, 5, MusicalDuration.eighth),
                        _note(2, 5, MusicalDuration.eighth),
                        _note(0, 5, MusicalDuration.eighth),
                      ]),
                      Single(MusicalValue(
                        duration: MusicalDuration.half,
                        midiNotes: [MidiNote(index: 6, octave: 4)],
                      )),
                    ]),
                  ],
                ),
                const SizedBox(height: 24),
                // Tek çizgili ritim dizeği: 5/8, 3+2 gruplama.
                MusicNotation.rhythm(
                  beatsPerMeasure: 5,
                  beatUnit: MusicalDuration.eighth,
                  color: Colors.white,
                  height: 110,
                  measures: [
                    NotationMeasure([
                      Beam([
                        _note(0, 4, MusicalDuration.eighth),
                        _note(0, 4, MusicalDuration.eighth),
                        _note(0, 4, MusicalDuration.eighth),
                      ]),
                      Beam([
                        _note(0, 4, MusicalDuration.eighth),
                        _note(0, 4, MusicalDuration.eighth),
                      ]),
                    ]),
                    NotationMeasure([
                      Single(_note(0, 4, MusicalDuration.quarter)),
                      Single(_note(0, 4, MusicalDuration.eighth)),
                      Beam([
                        _note(0, 4, MusicalDuration.eighth),
                        _note(0, 4, MusicalDuration.eighth),
                      ]),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
