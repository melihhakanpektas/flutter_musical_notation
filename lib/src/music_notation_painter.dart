import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_music_core/flutter_music_core.dart';
import 'package:flutter_musical_notation/src/measure.dart';

/// NotoMusic TextStyle factory - uses native Flutter font
TextStyle _notoMusicStyle(
  double fontSize,
  FontWeight fontWeight,
  Color color,
  double letterSpacing,
) {
  return TextStyle(
    fontFamily: 'NotoMusic',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

class MusicNotationPainter extends CustomPainter {
  final int beatsPerMeasure;
  final MusicalDuration beatUnit;
  final int measureCount;
  final Color color;
  final Clef clef;
  final bool isEnd;
  final bool horizontallyCenterNotes;
  final bool drawClef;
  final bool drawTimeSignature;
  final List<MusicalValue> values;

  MusicNotationPainter({
    this.beatsPerMeasure = 4,
    this.beatUnit = MusicalDuration.quarter,
    this.measureCount = 1,
    this.color = Colors.black,
    this.clef = Clef.treble,
    this.isEnd = true,
    this.horizontallyCenterNotes = false,
    this.drawClef = true,
    this.drawTimeSignature = true,
    this.values = const [],
  });

  double _fontSize(double height) => height / 3;

  late TextPainter _measurePainter;
  late TextPainter _measureLinePainter;
  late TextPainter _clefPainter;
  late TextPainter _beatsPerMeasurePainter;
  late TextPainter _beatUnitPainter;
  late TextPainter _endPainter;
  late double _noteSpaceHeight;
  late double _measureDescent;
  late double _measureExactHeight;
  late double _lineStrokeWidth;

  final bottomLimitIndex = 2;
  final topLimitIndex = -8;

  void _initializeDrawingElements(Canvas canvas, Size size) {
    final fontSize = _fontSize(size.height);
    _measurePainter = noteTextPainter(Measure.measureSpace.symbol, fontSize: fontSize)
      ..layout(maxWidth: size.width);
    _measureDescent = _measurePainter.computeLineMetrics().first.descent;
    _measureExactHeight = _measurePainter.computeLineMetrics().first.baseline - _measureDescent;
    _noteSpaceHeight = _measurePainter.height * 0.0675;
    _measureLinePainter = noteTextPainter(Measure.measureLine.symbol, fontSize: fontSize)
      ..layout(maxWidth: size.width);
    _clefPainter = noteTextPainter(clef.symbol, fontSize: fontSize)..layout(maxWidth: size.width);
    _beatsPerMeasurePainter = noteTextPainter(beatsPerMeasure.toString(), fontSize: fontSize * 0.7)
      ..layout(maxWidth: size.width);
    _beatUnitPainter = noteTextPainter(beatUnit.value.toString(), fontSize: fontSize * 0.7)
      ..layout(maxWidth: size.width);
    _endPainter = noteTextPainter(Measure.measureEnd.symbol, fontSize: fontSize)
      ..layout(maxWidth: size.width);

    _lineStrokeWidth = size.height / 100;
  }

  void centerCanvasVertical(Canvas canvas, Size size) {
    final yOffset = size.height / 2 - (_measurePainter.height / 2);
    canvas.translate(0, yOffset);
  }

  void drawStaff(Canvas canvas, Size size) {
    final lineSpacing =
        (_measureExactHeight - _lineStrokeWidth + 1) / 4; // Distance between staff lines
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = _lineStrokeWidth;

    // Draw 5 horizontal lines for the staff
    for (int i = 0; i < 5; i++) {
      final y = i * lineSpacing + _measureDescent + _lineStrokeWidth / 2 - 1;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  double clefEndX = 0.0;

  void _drawClef(Canvas canvas, Size size) {
    canvas.save();
    var dx = _measureLinePainter.width * 2;
    var dy = (_measureLinePainter.height * .06) * clef.offsetYMultiplier;
    canvas.translate(dx, dy);
    _clefPainter.paint(canvas, Offset.zero);
    canvas.restore();
    clefEndX = _clefPainter.width + dx;
  }

  double timeSignatureEndX = 0.0;

  void _drawTimeSignature(Canvas canvas, Size size) {
    canvas.save();
    var dx = clefEndX + _measureLinePainter.width * 2;
    var dy = _measurePainter.height / 8;
    canvas.translate(dx, dy);
    var beatsPerMeasureXOffset = 0.0;
    var beatUnitXOffset = 0.0;
    if (beatsPerMeasure.toString().length > beatUnit.value.toString().length) {
      beatUnitXOffset = (_beatsPerMeasurePainter.width / 2) - (_beatUnitPainter.width / 2);
    } else {
      beatsPerMeasureXOffset = (_beatUnitPainter.width / 2) - (_beatsPerMeasurePainter.width / 2);
    }

    _beatsPerMeasurePainter.paint(
      canvas,
      Offset(beatsPerMeasureXOffset, -_measurePainter.height * .15),
    );
    _beatUnitPainter.paint(canvas, Offset(beatUnitXOffset, _measurePainter.height * .15));
    canvas.restore();

    timeSignatureEndX = max(_beatsPerMeasurePainter.width, _beatUnitPainter.width) + dx;
  }

  late double widthOfAMeasure;

  void drawMeasures(Canvas canvas, Size size) {
    final staffWidthExceptLines =
        (size.width - timeSignatureEndX - (isEnd ? _endPainter.width : _measureLinePainter.width));
    // Draw measures
    widthOfAMeasure = staffWidthExceptLines / measureCount;

    canvas.save();
    for (var i = 0; i < measureCount + 1; i++) {
      canvas.save();
      if (i == measureCount) {
        if (isEnd) {
          canvas.translate(size.width - _endPainter.width - timeSignatureEndX, 0);
          _endPainter.paint(canvas, Offset.zero);
        } else {
          canvas.translate(widthOfAMeasure * i - timeSignatureEndX, 0);
          _measureLinePainter.paint(canvas, Offset.zero);
        }
      } else {
        canvas.translate(widthOfAMeasure * i, 0);
        _measureLinePainter.paint(canvas, Offset.zero);
      }
      canvas.restore();
      if (i == 0) {
        canvas.translate(timeSignatureEndX, 0);
      }
    }
    canvas.restore();
  }

  void drawNotes(Canvas canvas, Size size) {
    final measureTimeLength = beatsPerMeasure * (1 / beatUnit.value);

    var currentNoteIndex = 0;

    // Boyutla orantılı: 150 px yükseklikte eski sabit (-37.5) ile birebir,
    // diğer boyutlarda da doğru ölçeklenir.
    final measureStartPadding =
        (horizontallyCenterNotes ? -_fontSize(size.height) * 0.75 : widthOfAMeasure * 0.1);

    final staffWidthExceptLines =
        (size.width - timeSignatureEndX - (isEnd ? _endPainter.width : _measureLinePainter.width));
    // Draw measures
    widthOfAMeasure = staffWidthExceptLines / measureCount - measureStartPadding;

    canvas.translate(timeSignatureEndX, 0);
    for (var i = 0; i < measureCount; i++) {
      var notesInMeasureList = <MusicalValue>[];
      var currentBeat = 0.0;

      // Get all notes in the measure
      while (currentBeat < measureTimeLength && currentNoteIndex < values.length) {
        final currentNote = values[currentNoteIndex];
        currentBeat += currentNote.timeLength;
        notesInMeasureList.add(currentNote);
        currentNoteIndex++;
      }

      canvas.translate(measureStartPadding, 0);

      // Draw notes in the measure
      for (var note in notesInMeasureList) {
        final timeLengthRatioOfNoteInMeasure = note.timeLength / measureTimeLength;
        final widthOfNote = widthOfAMeasure * timeLengthRatioOfNoteInMeasure;
        drawChord(canvas, size, note, horizontallyCenterNotes ? widthOfNote / 2 : 0);
        canvas.translate(widthOfNote, 0);
      }
    }
  }

  double drawChord(Canvas canvas, Size size, MusicalValue musicalValue, double startDx) {
    // Calculates the average note position to determine if the chord should be rotated horizontally
    final isRest = musicalValue.type == RhythmicType.rest;
    final isHorizontalRotated =
        musicalValue.duration != MusicalDuration.whole &&
        !isRest &&
        (musicalValue.midiNotes.map((e) => e.octave * 7 + e.index).reduce((a, b) => a + b) /
                musicalValue.midiNotes.length) >
            (clef.firstSpaceMidiNote.octave * 7 + clef.firstSpaceMidiNote.index + 3);

    // Reorder notes according to its horizontal rotation
    final sortedNoteList =
        musicalValue.midiNotes.toList()..sort(
          (a, b) =>
              isHorizontalRotated
                  ? b.midiNumberWithoutAccidental.compareTo(a.midiNumber)
                  : a.midiNumberWithoutAccidental.compareTo(b.midiNumber),
        );

    final accidentalsWidth = drawAccidentals(
      sortedNoteList,
      canvas,
      size,
      startDx,
      color: musicalValue.color,
    );
    var noteWidth = 0.0;

    var isPreviousRotatedVertical = false;
    final verticalRotatedNotes = <MidiNote>[];

    final noteSymbol = musicalValue.duration.symbol(musicalValue.type);
    final headWidth = _headWidthFor(size, musicalValue.duration);

    if (!isRest && musicalValue.midiNotes.isNotEmpty && isHorizontalRotated) {
      // Ters saplı notalar parçalardan kurulur: doğru eğimli notabaşı +
      // tek ortak sap + doğru kıvrımlı bayrak (glif döndürme yönteminin
      // ayna-bayrak / çift-sap / kopuk-sap kusurlarını giderir).
      noteWidth = _drawStemDownChord(
        canvas: canvas,
        size: size,
        value: musicalValue,
        sortedDescending: sortedNoteList,
        dx: accidentalsWidth + startDx,
      );
    } else if (!isRest && musicalValue.midiNotes.isNotEmpty) {
      for (var i = 0; i < sortedNoteList.length; i++) {
        final note = sortedNoteList[i];
        final noteIndexDifference = calculateNoteIndexDifferenceWithClefsFirstSpaceMidiNote(note);
        bool isVerticalRotated = false;
        if (i != 0 &&
            !isPreviousRotatedVertical &&
            calculateIndexDifferenceBetweenFirstNoteToSecondNote(sortedNoteList[i - 1], note) ==
                -1) {
          verticalRotatedNotes.add(note);
          isVerticalRotated = true;
          isPreviousRotatedVertical = true;
        } else {
          isPreviousRotatedVertical = false;
        }
        drawNote(
          canvas: canvas,
          size: size,
          noteText: noteSymbol,
          dx: accidentalsWidth + startDx,
          isRest: isRest,
          indexFromClefFirstSpace: noteIndexDifference,
          isVerticalRotated: isVerticalRotated,
          color: musicalValue.color,
        );
      }
      noteWidth = headWidth;
      drawExtraLines(
        canvas: canvas,
        size: size,
        note: musicalValue,
        dx: accidentalsWidth + startDx,
        noteSymbol: noteSymbol,
        verticalRotatedNotes: verticalRotatedNotes,
        headWidth: headWidth,
      );
      if (musicalValue.dotted) {
        _drawAugmentationDots(
          canvas: canvas,
          notes: sortedNoteList,
          dx: accidentalsWidth + startDx,
          noteWidth: headWidth,
          color: musicalValue.color,
        );
      }
    } else {
      noteWidth = drawNote(
        canvas: canvas,
        size: size,
        noteText: noteSymbol,
        dx: startDx,
        isRest: isRest,
        indexFromClefFirstSpace: 0,
        color: musicalValue.color,
      );
    }
    return noteWidth + accidentalsWidth;
  }

  /// Süreye uygun notabaşı genişliği — ek çizgi ve nokta konumlandırmasının
  /// ortak ölçüsü. Birlik notanın başı siyah baştan geniştir; ölçü süreye
  /// göre seçilmezse ledger çizgisi başa ortalanmaz.
  double _headWidthFor(Size size, MusicalDuration duration) {
    final glyph = switch (duration) {
      MusicalDuration.whole => '\u{1D15D}', // birlik: glifin kendisi baştır
      MusicalDuration.half => '\u{1D157}', // boş notabaşı
      _ => '\u{1D158}', // siyah notabaşı
    };
    final painter = noteTextPainter(glyph, fontSize: _fontSize(size.height))
      ..layout(maxWidth: size.width);
    return painter.width;
  }

  /// Baş merkezi y'si: staff'ın ilk boşluğundaki notanın merkezi + staff
  /// pozisyonu başına yarım çizgi aralığı (uzatma noktalarıyla aynı formül).
  double _headCenterY(int indexFromClefFirstSpace) {
    final lineSpacing = (_measureExactHeight - _lineStrokeWidth + 1) / 4;
    return _measureDescent +
        _lineStrokeWidth / 2 -
        1 +
        lineSpacing * 3.5 +
        indexFromClefFirstSpace * _noteSpaceHeight;
  }

  /// Ters saplı (stem-down) nota/akoru parçalardan kurar.
  ///
  /// - Notabaşı glifi (U+1D158 / yarımlıkta U+1D157): doğru eğim
  /// - Tek ortak sap: en tiz başın merkezinden en pes başın ~3.5 boşluk
  ///   altına, başların sol kenarında
  /// - Bayrak (U+1D16E/U+1D16F) sap dibinde dikeyde çevrilir: kıvrım sağa
  /// - İkili aralığın (second) başı sapın soluna ofsetlenir
  double _drawStemDownChord({
    required Canvas canvas,
    required Size size,
    required MusicalValue value,
    required List<MidiNote> sortedDescending,
    required double dx,
  }) {
    final fontSize = _fontSize(size.height);
    final drawColor = value.color ?? color;
    final headPainter = noteTextPainter(
      value.duration == MusicalDuration.half ? '\u{1D157}' : '\u{1D158}',
      fontSize: fontSize,
      color: drawColor,
    )..layout(maxWidth: size.width);
    final headW = headPainter.width;

    // Ön geçiş: her notabaşının sap'a göre yönü (bitişik ikilinin ikinci
    // notası sapın soluna gider) ve porte konumu.
    var previousWasLeft = false;
    final indices = <int>[];
    final leftSide = <bool>[];
    for (var i = 0; i < sortedDescending.length; i++) {
      final note = sortedDescending[i];
      var left = false;
      if (i != 0 &&
          !previousWasLeft &&
          calculateIndexDifferenceBetweenFirstNoteToSecondNote(sortedDescending[i - 1], note) ==
              1) {
        left = true;
      }
      previousWasLeft = left;
      indices.add(calculateNoteIndexDifferenceWithClefsFirstSpaceMidiNote(note));
      leftSide.add(left);
    }

    // Sola kayan notabaşı, aksidanlarla birlikte aksidan bölgesine girip
    // çakışır (aksidanlar bloğun soluna, notabaşından bağımsız çizilir).
    // Bu durumda tüm nota bloğunu bir notabaşı genişliği sağa alırız;
    // aksidansız bitişik akorlar (sol kaymanın sorun olmadığı yer) etkilenmez.
    final hasLeftHead = leftSide.any((left) => left);
    final hasAccidental = sortedDescending.any((note) => note.accidental != null);
    if (hasLeftHead && hasAccidental) dx += headW;

    // Çizim geçişi.
    for (var i = 0; i < sortedDescending.length; i++) {
      headPainter.paint(
        canvas,
        Offset(dx + (leftSide[i] ? -headW : 0), indices[i] * _noteSpaceHeight - .5),
      );
    }

    final topIndex = indices.reduce(min);
    final bottomIndex = indices.reduce(max);

    final stemPaint =
        Paint()
          ..color = drawColor
          ..strokeWidth = _lineStrokeWidth * 0.8;
    final stemX = dx + _lineStrokeWidth / 2;
    final stemBottomY = _headCenterY(bottomIndex) + _noteSpaceHeight * 7;
    canvas.drawLine(Offset(stemX, _headCenterY(topIndex)), Offset(stemX, stemBottomY), stemPaint);

    if (value.duration.value >= MusicalDuration.eighth.value) {
      final flagPainter = noteTextPainter(
        value.duration == MusicalDuration.eighth ? '\u{1D16E}' : '\u{1D16F}',
        fontSize: fontSize,
        color: drawColor,
      )..layout(maxWidth: size.width);
      // Dikey ayna: kıvrım yönü korunur (sağa), bağlantı ucu sap dibine
      // gelir. Combining flag glifinin advance genişliği sıfır olduğundan
      // yatay ofset de glif YÜKSEKLİĞİNE ölçeklenir; değerler NotoMusic
      // için görsel kalibrasyondur (sol kenar sapla hizalı, üst uç sap
      // dibine değer).
      const flagDx = 0.021;
      const flagDy = 0.31;
      canvas.save();
      canvas.translate(stemX, stemBottomY);
      canvas.scale(1, -1);
      flagPainter.paint(canvas, Offset(flagPainter.height * flagDx, -flagPainter.height * flagDy));
      canvas.restore();
    }

    // Ek çizgiler: başlara ortalı; solda baş varsa sola uzar.
    final linePaint =
        Paint()
          ..color = drawColor
          ..strokeWidth = _lineStrokeWidth;
    final anyLeft = leftSide.any((left) => left);
    final lineFrom = dx + (anyLeft ? -headW : 0) - headW * 0.35;
    final lineTo = dx + headW * 1.35;
    final bottomLineCount = ((bottomIndex - bottomLimitIndex) / 2).ceil();
    final topLineCount = ((topIndex - topLimitIndex) / 2).floor();
    for (var i = 0; i < bottomLineCount; i++) {
      final y = _measureDescent + _noteSpaceHeight * 2 * (i + 5) + 1;
      canvas.drawLine(Offset(lineFrom, y), Offset(lineTo, y), linePaint);
    }
    for (var i = 0; i > topLineCount; i--) {
      final y = _measureDescent + _noteSpaceHeight * 2 * (i - 1);
      canvas.drawLine(Offset(lineFrom, y), Offset(lineTo, y), linePaint);
    }

    if (value.dotted) {
      _drawAugmentationDots(
        canvas: canvas,
        notes: sortedDescending,
        dx: dx,
        noteWidth: headW,
        color: value.color,
      );
    }
    return headW;
  }

  /// returns the width of the accidentals
  double drawAccidentals(
    List<MidiNote> sortedNoteList,
    Canvas canvas,
    Size size,
    double dx, {
    Color? color,
  }) {
    var notesWithAccidentals = sortedNoteList.where((e) => e.accidental != null).toList();
    var width = _measureLinePainter.width;
    canvas.save();
    canvas.translate(dx, 0);
    for (var i = 0; i < notesWithAccidentals.length; i++) {
      final note = notesWithAccidentals[i];
      final noteIndexDifference = calculateNoteIndexDifferenceWithClefsFirstSpaceMidiNote(note);
      final noteYOffset = noteIndexDifference * _noteSpaceHeight;
      canvas.save();
      canvas.translate(0, noteYOffset - _noteSpaceHeight * -2);

      final accidentalPainter = noteTextPainter(
        note.accidental!.symbol,
        fontSize: _fontSize(size.height) * 0.8,
        color: color,
      )..layout(maxWidth: size.width);
      accidentalPainter.paint(canvas, Offset.zero);
      canvas.restore();
      if (notesWithAccidentals.isNotEmpty) {
        width += accidentalPainter.width + _measureLinePainter.width;
        canvas.translate(accidentalPainter.width + _measureLinePainter.width, 0);
      }
    }
    canvas.restore();
    return width;
  }

  /// Dik saplı nota veya sus çizer (ters saplılar [_drawStemDownChord] ile
  /// parçalardan kurulur).
  double drawNote({
    required Canvas canvas,
    required Size size,
    required String noteText,
    required double dx,
    required int indexFromClefFirstSpace,
    bool isRest = false,
    bool isVerticalRotated = false,
    Color? color,
  }) {
    final notePainter = noteTextPainter(noteText, fontSize: _fontSize(size.height), color: color)
      ..layout(maxWidth: size.width);
    final noteYOffset = isRest ? 0.0 : indexFromClefFirstSpace * _noteSpaceHeight;
    canvas.save();
    canvas.translate(dx, noteYOffset);
    if (isVerticalRotated) {
      // Ayna uzayında -1.915w, ekranda ikinci notabaşını ana başların
      // sağına koyar (dik akorda ikili aralık — doğru gravür konumu).
      canvas.transform(Matrix4.rotationY(pi).storage);
      canvas.translate(-notePainter.width * 1.915, 0);
    }
    notePainter.paint(canvas, Offset.zero);
    canvas.restore();
    return notePainter.width;
  }

  /// Noktalı değerin uzatma noktaları: her notabaşının sağına, boşluk
  /// hizasına (çizgideki nota için bir üst boşluğa) çizilir.
  void _drawAugmentationDots({
    required Canvas canvas,
    required List<MidiNote> notes,
    required double dx,
    required double noteWidth,
    Color? color,
  }) {
    final paint =
        Paint()
          ..color = color ?? this.color
          ..style = PaintingStyle.fill;
    final radius = _noteSpaceHeight * 0.5;
    // Notabaşları her iki sap yönünde de ~[0, w] kutusunda (yeni geometri);
    // nokta tek kolonda, başların sağında durur.
    final dotX = dx + noteWidth * 1.25 + radius;
    final lineSpacing = (_measureExactHeight - _lineStrokeWidth + 1) / 4;
    final firstSpaceCenterY = _measureDescent + _lineStrokeWidth / 2 - 1 + lineSpacing * 3.5;
    for (final note in notes) {
      var index = calculateNoteIndexDifferenceWithClefsFirstSpaceMidiNote(note);
      if (index.isOdd) index -= 1; // çizgideki nota → bir üst boşluk
      final y = firstSpaceCenterY + index * _noteSpaceHeight;
      canvas.drawCircle(Offset(dotX, y), radius, paint);
    }
  }

  /// Dik saplı notaların ek (ledger) çizgileri. Uzunluk, glif genişliğine
  /// değil notabaşı genişliğine ([headWidth]) dayanır — bayraklı gliflerde
  /// çizginin gereğinden uzun çıkmasını önler.
  void drawExtraLines({
    required Canvas canvas,
    required Size size,
    required MusicalValue note,
    required double dx,
    required String noteSymbol,
    required List<MidiNote> verticalRotatedNotes,
    required double headWidth,
  }) {
    final notePainter = noteTextPainter(noteSymbol, fontSize: _fontSize(size.height))
      ..layout(maxWidth: size.width);
    final lowestNoteSpace = calculateNoteIndexDifferenceWithClefsFirstSpaceMidiNote(
      note.midiNotes.first,
    );
    final highestNoteSpace = calculateNoteIndexDifferenceWithClefsFirstSpaceMidiNote(
      note.midiNotes.last,
    );

    final bottomLineCount = ((lowestNoteSpace - bottomLimitIndex) / 2).ceil();
    final topLineCount = ((highestNoteSpace - topLimitIndex) / 2).floor();
    canvas.save();
    canvas.translate(dx, 0);
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = _lineStrokeWidth;

    double bottomY(int i) => _measureDescent + _noteSpaceHeight * 2 * (i + 5) + 1;
    double topY(int i) => _measureDescent + _noteSpaceHeight * 2 * (i - 1) + 1;
    void line(double fromX, double toX, double y) =>
        canvas.drawLine(Offset(fromX, y), Offset(toX, y), paint);

    // Ana başlar [0, headWidth] kutusunda; çizgi başa ortalanır.
    for (int i = 0; i < bottomLineCount; i++) {
      line(-headWidth * 0.35, headWidth * 1.35, bottomY(i));
    }
    for (int i = 0; i > topLineCount; i--) {
      line(-headWidth * 0.35, headWidth * 1.35, topY(i));
    }

    if (verticalRotatedNotes.isNotEmpty) {
      final rotatedLowestNoteSpace = calculateNoteIndexDifferenceWithClefsFirstSpaceMidiNote(
        verticalRotatedNotes.first,
      );
      final rotatedHighestNoteSpace = calculateNoteIndexDifferenceWithClefsFirstSpaceMidiNote(
        verticalRotatedNotes.last,
      );
      final bottomRotatedLineCount = ((rotatedLowestNoteSpace - bottomLimitIndex) / 2).ceil();
      final topRotatedLineCount = ((rotatedHighestNoteSpace - topLimitIndex) / 2).floor();

      // İkili aralığın (second) başı ana başların sağında; merkezi glif
      // genişliğine bağlıdır (ayna + -1.915w ötelemesi).
      final secondCenter = notePainter.width * 1.915 - headWidth / 2;
      for (int i = 0; i < bottomRotatedLineCount; i++) {
        line(secondCenter - headWidth * 0.85, secondCenter + headWidth * 0.85, bottomY(i));
      }
      for (int i = 0; i > topRotatedLineCount; i--) {
        line(secondCenter - headWidth * 0.85, secondCenter + headWidth * 0.85, topY(i));
      }
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _initializeDrawingElements(canvas, size);

    // Center the canvas vertically
    centerCanvasVertical(canvas, size);

    // Draw a staff that fills the width of the canvas
    drawStaff(canvas, size);

    if (drawClef) {
      // Draw the clef
      _drawClef(canvas, size);
    }

    if (drawTimeSignature) {
      // Draw the time signature
      _drawTimeSignature(canvas, size);
    }

    // Draw measures
    drawMeasures(canvas, size);

    // Draw notes
    drawNotes(canvas, size);
  }

  TextStyle noteTextStyle({required double fontSize, bool isBold = false, Color? color}) =>
      _notoMusicStyle(
        fontSize,
        isBold ? FontWeight.bold : FontWeight.normal,
        color ?? this.color,
        fontSize * -0.1,
      );

  TextPainter noteTextPainter(
    String text, {
    required double fontSize,
    bool isBold = false,
    Color? color,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: noteTextStyle(fontSize: fontSize, isBold: isBold, color: color ?? this.color),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
    );
  }

  int calculateIndexDifferenceBetweenFirstNoteToSecondNote(MidiNote midiNote1, MidiNote midiNote2) {
    final int midiNote1ExactIndex = midiNote1.index + (midiNote1.octave * 7);
    final int midiNote2ExactIndex = midiNote2.index + (midiNote2.octave * 7);
    return midiNote1ExactIndex - midiNote2ExactIndex;
  }

  int calculateNoteIndexDifferenceWithClefsFirstSpaceMidiNote(MidiNote otherMidiNote) {
    return calculateIndexDifferenceBetweenFirstNoteToSecondNote(
      clef.firstSpaceMidiNote,
      otherMidiNote,
    );
  }

  @override
  bool shouldRepaint(covariant MusicNotationPainter oldDelegate) {
    // Eski davranış her zaman `false` idi: tema/renk veya nota değişimi
    // repaint tetiklemiyordu. Alan karşılaştırması güvenli yöndedir
    // (values listesi kimlikle karşılaştırılır; yeni liste → repaint).
    return oldDelegate.beatsPerMeasure != beatsPerMeasure ||
        oldDelegate.beatUnit != beatUnit ||
        oldDelegate.measureCount != measureCount ||
        oldDelegate.color != color ||
        oldDelegate.clef != clef ||
        oldDelegate.isEnd != isEnd ||
        oldDelegate.horizontallyCenterNotes != horizontallyCenterNotes ||
        oldDelegate.drawClef != drawClef ||
        oldDelegate.drawTimeSignature != drawTimeSignature ||
        !listEquals(oldDelegate.values, values);
  }
}
