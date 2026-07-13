## 0.0.2

* Ters saplı bitişik ikili akorda (ör. La♭5-Si♭5) aksidan çakışması
  düzeltildi: ikinci notabaşı sapın soluna kayıp aksidan bölgesine giriyordu.
  Aksidan **ve** sola kayan notabaşı birlikte varsa nota bloğu bir notabaşı
  genişliği sağa alınır (aksidansız bitişik akorlar etkilenmez).
* Noto Music fontu artık paketle geliyor (`fonts/` + pubspec `fonts:`).
  Daha önce sistemin `NotoMusic` ailesine güveniliyordu: iOS'ta bu font yok,
  Android sürümleri arasında metrikler değişebiliyordu.
* Noktalı değer desteği: `MusicalValue.dotted` (flutter_music_core) süre
  hesabına (×1.5) ve çizime (notabaşı sağına, boşluk hizasında uzatma
  noktası) yansır.
* Ters saplı (stem-down) notalar artık glif döndürme yerine **parçalardan
  kuruluyor**: notabaşı glifi (doğru eğim) + tek ortak sap (çizgi) + dikeyde
  çevrilmiş bayrak glifi (kıvrım doğru yönde, sağa). Bu tek hamlede üç kusuru
  giderdi: ayna görüntüsü bayraklar, ikili aralıkta çift sap ve baş-sap
  kopukluğu. Ayrıca ters saplı notanın kendi yatay slotundan taşıp sonraki
  sembolle çakışması da tarihe karıştı. Bayrak, sol kenarı sapla hizalanacak
  ve üst ucu sap dibine değecek şekilde konumlandırıldı (sekizlik ve
  onaltılık; combining flag glifinin sol/üst taşması telafi edilerek).
* Ek (ledger) çizgiler artık glif genişliğine değil **süreye uygun notabaşı
  genişliğine** ortalanıyor (birlik/ikilik/siyah baş ayrı ölçülür) ve başın
  her iki yanına simetrik taşıyor — bayraklı gliflerde uzun çıkması, birlik
  notalarda sola kayması düzeltildi. İkili aralığın ledger hesabındaki
  en-tiz/en-pes kopyala-yapıştır hatası da giderildi.
* `shouldRepaint` artık alanları karşılaştırıyor (eskiden her zaman `false`
  idi: tema/renk/nota değişimi repaint tetiklemiyordu).
* `horizontallyCenterNotes` içindeki sabit -37.5 px, boyutla orantılı hale
  getirildi (150 px yükseklikte eski davranışla birebir).
* Smoke testler eklendi (font yüklemeli render, dotted süre, shouldRepaint).

Bilinen sınırlar: dik saplı yarımlık/dörtlük gliflerinde baş-sap bağlantısında
nadir küçük kaymalar görülebilir; gravür kalitesi için uzun vadeli yol tüm
notaları parçalardan kurmak ve SMuFL fontuna (Bravura/Leland) geçmektir.

## 0.0.1

* İlk sürüm.
