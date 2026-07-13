import 'package:flutter_music_core/flutter_music_core.dart';

/// Bir ölçünün içeriği: sıralı dizim öğeleri.
///
/// Kirişleme (beam) kararı çağırana aittir — vuruş gruplaması otomatik
/// çıkarılmaz. Özellikle aksak ölçülerde (ör. 5/8'in 3+2 mi 2+3 mü olduğu)
/// gruplama müzikal bir karardır ve nota yazımının kendisini değiştirir.
/// Bu model MusicXML/MEI'deki ölçü → öğe hiyerarşisinin karşılığıdır
/// (MEI'de `<beam>` elementi de tam böyle bir kaptır).
class NotationMeasure {
  final List<NotationElement> elements;

  const NotationMeasure(this.elements);

  /// Ölçüdeki tüm değerleri kirişsiz tek tek yazan kısayol.
  factory NotationMeasure.singles(List<MusicalValue> values) =>
      NotationMeasure([for (final v in values) Single(v)]);

  /// Birlik nota cinsinden toplam süre.
  double get timeLength =>
      elements.fold(0.0, (sum, e) => sum + e.timeLength);
}

/// Ölçü içindeki dizim öğesi: tek değer ([Single]) veya kiriş grubu ([Beam]).
sealed class NotationElement {
  const NotationElement();

  /// Birlik nota cinsinden süre.
  double get timeLength;
}

/// Kirişsiz tek nota/akor/sus — bayraklı süreler kendi bayrağıyla çizilir.
class Single extends NotationElement {
  final MusicalValue value;

  const Single(this.value);

  @override
  double get timeLength => value.timeLength;
}

/// Kirişle birleştirilen nota grubu.
///
/// En az iki öğe gerekir; tüm öğeler bayraklı süreli (sekizlik ve kısası)
/// **nota** olmalıdır (sus kirişlenemez — susun etrafında grubu bölerek
/// ayrı [Beam]/[Single] öğeleri yazın). Karışık süreler desteklenir:
/// ikincil kirişler ve kısmi kiriş uçları (beamlet) otomatik hesaplanır
/// (ör. noktalı sekizlik + onaltılık).
class Beam extends NotationElement {
  final List<MusicalValue> values;

  Beam(this.values)
    : assert(values.length >= 2, 'Beam en az iki değer ister.'),
      assert(
        values.every((v) => v.type == RhythmicType.note),
        'Beam yalnızca nota içerebilir; susu grubun dışına alın.',
      ),
      assert(
        values.every((v) => v.duration.value >= MusicalDuration.eighth.value),
        'Beam yalnızca bayraklı süreler (sekizlik ve kısası) içerebilir.',
      );

  @override
  double get timeLength => values.fold(0.0, (sum, v) => sum + v.timeLength);
}
