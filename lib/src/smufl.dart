/// SMuFL (Standard Music Font Layout) sabitleri — Bravura fontundan türetildi.
///
/// Konumlandırma değerleri fontun kendi metadata'sından (`bravura_metadata.json`)
/// alınmıştır ve **staff space** birimindedir (bir porte boşluğu = iki çizgi
/// arası). 1 staff space = fontSize / 4. Böylece sap/bayrak/ek çizgi konumları
/// deneysel görsel kalibrasyon yerine fontun tasarım verisinden gelir; sonuç
/// platformdan bağımsızdır.
///
/// Anchor'lar `(x, yUp)` çiftidir: glif origin'ine (baseline üzerinde, advance
/// başlangıcı) göre, **+y YUKARI** yönde (fontun kendi koordinatı). Painter bunu
/// piksele çevirirken sp ile çarpar ve ekran y'si için yUp'ı ters çevirir.
library;

import 'package:flutter_music_core/flutter_music_core.dart';

/// Bir SMuFL glifinin staff-space cinsinden anchor'ı (x sağa, y yukarı).
typedef SpPoint = ({double x, double yUp});

class Smufl {
  Smufl._();

  static const String fontFamily = 'Bravura';

  /// Font bu pakette tanımlı olduğundan, bağımlı uygulamada
  /// `packages/flutter_musical_notation/Bravura` adıyla paketlenir. TextStyle'a
  /// bu paket adı verilmezse (düz 'Bravura'), font yalnızca paketin kendi
  /// test/örneğinde çözülür; gerçek uygulamada glifler "tofu" kutusu çıkar.
  static const String fontPackage = 'flutter_musical_notation';

  // ---- engravingDefaults (staff space) -------------------------------------
  static const double staffLineThickness = 0.13;
  static const double stemThickness = 0.12;
  static const double legerLineThickness = 0.16;
  static const double legerLineExtension = 0.4;
  static const double thinBarlineThickness = 0.16;
  static const double thickBarlineThickness = 0.5;
  static const double barlineSeparation = 0.4;
  static const double beamThickness = 0.5;
  static const double beamSpacing = 0.25;
  static const double tieMidpointThickness = 0.22;
  static const double tieEndpointThickness = 0.1;

  // ---- Notabaşı ölçüleri (staff space) -------------------------------------
  /// Siyah/boş notabaşı advance genişliği.
  static const double noteheadWidth = 1.18;

  /// Birlik notabaşı advance genişliği (daha geniştir).
  static const double noteheadWholeWidth = 1.688;

  /// Sap tutturma noktaları (siyah ve boş notabaşı için aynı).
  static const SpPoint stemUpSE = (x: 1.18, yUp: 0.168); // sapın sağ-üst dibi
  static const SpPoint stemDownNW = (x: 0.0, yUp: -0.168); // sapın sol-alt dibi

  /// Standart sap boyu (notabaşı merkezinden), staff space.
  static const double stemLength = 3.5;

  // ---- Kod noktaları (SMuFL PUA) -------------------------------------------
  static const int _noteheadWhole = 0xE0A2;
  static const int _noteheadHalf = 0xE0A3;
  static const int _noteheadBlack = 0xE0A4;

  static const int augmentationDot = 0xE1E7;

  static const int _gClef = 0xE050;
  static const int _fClef = 0xE062;
  static const int _cClef = 0xE05C;

  /// Perküsyon anahtarı (iki dikey çubuk) — tek çizgili ritim dizeği için.
  /// Origin dikeyde ortalıdır; baseline dizek çizgisine oturur.
  static const int percussionClef = 0xE069; // unpitchedPercussionClef1

  static const int _timeSig0 = 0xE080; // 0..9 ardışık

  static const int _accidentalDoubleFlat = 0xE264;
  static const int _accidentalFlat = 0xE260;
  static const int _accidentalNatural = 0xE261;
  static const int _accidentalSharp = 0xE262;
  static const int _accidentalDoubleSharp = 0xE263;

  static const int _restWhole = 0xE4E3;
  static const int _restHalf = 0xE4E4;
  static const int _restQuarter = 0xE4E5;
  static const int _rest8th = 0xE4E6;
  static const int _rest16th = 0xE4E7;
  static const int _rest32nd = 0xE4E8;
  static const int _rest64th = 0xE4E9;

  /// Kod noktasını çizilebilir stringe çevirir.
  static String ch(int codepoint) => String.fromCharCode(codepoint);

  // ---- Sözlükler -----------------------------------------------------------

  /// Süreye göre notabaşı glifi.
  static String notehead(MusicalDuration duration) => ch(switch (duration) {
    MusicalDuration.whole => _noteheadWhole,
    MusicalDuration.half => _noteheadHalf,
    _ => _noteheadBlack,
  });

  /// Süreye göre notabaşı advance genişliği (staff space).
  static double noteheadWidthOf(MusicalDuration duration) =>
      duration == MusicalDuration.whole ? noteheadWholeWidth : noteheadWidth;

  /// Süsleme (kuyruk/bayrak) olan bir süre mi? Birlik/ikilik/dörtlükte yok.
  static bool hasFlag(MusicalDuration duration) =>
      duration.value >= MusicalDuration.eighth.value;

  /// Sürenin kiriş (beam) sayısı: sekizlik 1, onaltılık 2, otuzikilik 3,
  /// altmışdörtlük 4; daha uzun sürelerde 0.
  static int beamCountOf(MusicalDuration duration) => switch (duration) {
    MusicalDuration.eighth => 1,
    MusicalDuration.sixteenth => 2,
    MusicalDuration.thirtySecond => 3,
    MusicalDuration.sixtyFourth => 4,
    _ => 0,
  };

  /// Sus glifi.
  static String rest(MusicalDuration duration) => ch(switch (duration) {
    MusicalDuration.whole => _restWhole,
    MusicalDuration.half => _restHalf,
    MusicalDuration.quarter => _restQuarter,
    MusicalDuration.eighth => _rest8th,
    MusicalDuration.sixteenth => _rest16th,
    MusicalDuration.thirtySecond => _rest32nd,
    MusicalDuration.sixtyFourth => _rest64th,
  });

  /// Aksidan glifi.
  static String accidental(MusicalAccidental accidental) =>
      ch(switch (accidental) {
        MusicalAccidental.doubleFlat => _accidentalDoubleFlat,
        MusicalAccidental.flat => _accidentalFlat,
        MusicalAccidental.natural => _accidentalNatural,
        MusicalAccidental.sharp => _accidentalSharp,
        MusicalAccidental.doubleSharp => _accidentalDoubleSharp,
      });

  /// Rakam glifi (ölçü sayısı için), 0-9.
  static String digit(int d) => ch(_timeSig0 + d);

  /// Anahtar glifi + üzerine oturduğu porte çizgisinin referans notası.
  ///
  /// SMuFL anahtarları, origin baseline'ı işaret ettikleri çizgi üzerinde
  /// olacak şekilde kayıtlıdır (Sol anahtarı Sol4 çizgisi, Fa anahtarı Fa3
  /// çizgisi, Do anahtarı orta Do çizgisi). Referans notasının porte konumu
  /// painter tarafından hesaplanır.
  static ({String glyph, MidiNote refNote}) clef(Clef clef) => switch (clef) {
    Clef.treble => (glyph: ch(_gClef), refNote: MidiNote(index: 4, octave: 4)),
    Clef.bass => (glyph: ch(_fClef), refNote: MidiNote(index: 3, octave: 3)),
    Clef.alto => (glyph: ch(_cClef), refNote: MidiNote(index: 0, octave: 4)),
    Clef.tenor => (glyph: ch(_cClef), refNote: MidiNote(index: 0, octave: 4)),
  };

  /// Süreye göre bayrak glifleri ve sap tutturma anchor'ları.
  ///
  /// `up`/`down` sırasıyla dik saplı (aşağıdan yukarı) ve ters saplı (yukarıdan
  /// aşağı) bayrak. `upAnchor` bayrağın stem tepesine (stemUpNW), `downAnchor`
  /// stem dibine (stemDownSW) oturduğu noktadır.
  static ({String up, String down, SpPoint upAnchor, SpPoint downAnchor})? flag(
    MusicalDuration duration,
  ) {
    switch (duration) {
      case MusicalDuration.eighth:
        return (
          up: ch(0xE240),
          down: ch(0xE241),
          upAnchor: (x: 0.0, yUp: -0.04),
          downAnchor: (x: 0.0, yUp: 0.132),
        );
      case MusicalDuration.sixteenth:
        return (
          up: ch(0xE242),
          down: ch(0xE243),
          upAnchor: (x: 0.0, yUp: -0.088),
          downAnchor: (x: 0.0, yUp: 0.128),
        );
      case MusicalDuration.thirtySecond:
        return (
          up: ch(0xE244),
          down: ch(0xE245),
          upAnchor: (x: 0.0, yUp: 0.376),
          downAnchor: (x: 0.0, yUp: -0.448),
        );
      case MusicalDuration.sixtyFourth:
        return (
          up: ch(0xE246),
          down: ch(0xE247),
          upAnchor: (x: 0.0, yUp: 1.172),
          downAnchor: (x: 0.0, yUp: -1.244),
        );
      default:
        return null;
    }
  }
}
