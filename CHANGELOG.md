## 0.3.0

**Bağ (tie) ve donanım (key signature) desteği** — sınav müfredatının iki
eksiği kapandı; paket artık "gerçek parça" (donanım + kiriş + bağ, çok satır
Column kompozisyonuyla) yazabiliyor (bkz. galeri 44).

* **Bağ:** `MusicalValue.tiedToPrevious` (flutter_music_core 0.0.2). Açıksa
  bir önceki nota olayından bu notaya, aynı porte konumundaki baş çiftleri
  arasında bağ çizilir. Bağlar ölçü ve kiriş sınırlarını doğal olarak aşar
  (senkop yazımı); sus zinciri keser (susa/sustan bağ debug'da assert).
  Eğri, notabaşı tarafına (sap yönünün tersine; birlikte "olası" sap yönüne
  göre) çizilen mercek biçimli dolgudur: uçlar ince, orta `engravingDefaults`
  `tieMidpointThickness` (0.22 sp); yükseklik uzunlukla orantılı (0.4–1 sp).
* **Donanım:** `KeySignature` (flutter_music_core 0.0.2, MusicXML `fifths`
  modeli: + diyez, - bemol). Anahtar ile ölçü imi arasına çizilir; konumlar
  klefe göre standart banttan türetilir (Sol/Fa/alto anahtarlarında standart
  gravürle birebir; tenor diyez istisnası uygulanmaz). Ritim dizeğinde
  donanım yoktur. Donanımın kapsadığı sesler için aksidan yazmamak çağıranın
  sorumluluğudur (`KeySignature.accidentalFor` yardımcısıyla).
* Galeri 44 senaryoya çıktı: donanımlar (diyez/bemol/fa anahtarı), bağlar
  (melodi + ritim dizeği) ve iki satırlı gerçek parça eklendi.

## 0.2.0

**Kiriş (beam) desteği, tek çizgili ritim dizeği ve ölçü tabanlı API.**

* **Yeni veri modeli:** içerik artık `measures: List<NotationMeasure>` ile
  ölçü ölçü verilir; her ölçü `Single` (tek değer) ve `Beam` (kiriş grubu)
  öğelerinden oluşur. MusicXML/MEI'deki ölçü → öğe hiyerarşisinin karşılığı:
  kiriş bir kaptır, işaret değil. Eski düz `values` + `measureCount` API'si
  kaldırıldı. Kirişsiz ölçüler için kısayol: `NotationMeasure.singles([...])`.
* **Kirişleme çağıranın kararıdır** — vuruş gruplaması otomatik çıkarılmaz.
  Aksak ölçülerde gruplama müzikal anlam taşır: 5/8'in 3+2 ve 2+3 yazımı
  `[Beam([e,e,e]), Beam([e,e])]` ve `[Beam([e,e]), Beam([e,e,e])]` olarak
  açıkça yazılır.
* **Kiriş çizimi** SMuFL `engravingDefaults` ölçüleriyle (`beamThickness` 0.5
  sp, `beamSpacing` 0.25 sp): grup için ortak sap yönü (tüm notaların ortalama
  porte konumu), sap uçlarından geçen eğimi ±1 sp ile sınırlı kiriş çizgisi,
  hiçbir sapın 3.5 sp'den kısa kalmayacağı şekilde öteleme. Karışık sürelerde
  ikincil kirişler (onaltılık = 2 seviye … altmışdörtlük = 4) ardışık koşular
  halinde; tek kalan nota kısmi kiriş ucu (beamlet, ~1 notabaşı genişliği)
  alır — noktalı sekizlik + onaltılık kalıbı standart yazımıyla çıkar.
  Kirişli notalarda bayrak çizilmez.
* **Tek çizgili ritim dizeği:** `MusicNotation.rhythm(...)`. Bütün notabaşları
  perdeden bağımsız çizginin üzerine oturur, saplar hep yukarı, anahtar olarak
  SMuFL perküsyon anahtarı (U+E069) çizilir; ek çizgi yoktur, birlik sus
  çizginin kendisinden sarkar. Barlar standart 4 sp yüksekliğinde.
* Ölçü taşması debug'da assert'le yakalanır (ölçü içeriği ölçü iminden uzunsa).
* `Measure` enum'u (NotoMusic bar glifleri) kaldırıldı — barlar 0.1.0'dan beri
  dikdörtgen olarak çiziliyor.
* Galeri 38 senaryoya çıktı: kiriş çiftleri, 5/8 3+2 / 2+3, onaltılık ikincil
  kirişler, beamlet'ler, eğimli kirişler, ters saplı akor kirişi, ritim dizeği
  (2/4, 5/8, noktalı) eklendi.

## 0.1.0

**SMuFL'ye geçiş (Bravura).** Çizim motoru NotoMusic (standart Unicode müzik
blokları) yerine SMuFL (Standard Music Font Layout) fontu **Bravura** üzerine
yeniden yazıldı. Konumlandırma artık fontun kendi metadata'sından
(`bravura_metadata.json`) gelir; 0.0.x'teki bütün deneysel görsel kalibrasyonlar
kaldırıldı.

* Koordinat sistemi **staff space** (sp) tabanlı: 1 sp = iki porte çizgisi arası
  = fontSize / 4. Bütün ölçüler (sap kalınlığı, ledger uzaması/kalınlığı, barlar)
  `engravingDefaults`'tan okunur.
* Glifler **baseline origin**'e göre yerleştirilir: her glif, SMuFL origin'i
  (baseline üzerinde, advance başlangıcı) hedef canvas noktasına gelecek şekilde
  çizilir. Anchor'lar (staff space, +y yukarı) buna görelidir.
* **Sap ve bayrak** artık notabaşının `stemUpSE` / `stemDownNW` ve bayrağın
  `stemUpNW` / `stemDownSW` anchor'larından kurulur. Combining-glif hilesi, ayna
  (Matrix4.rotationY / scale(1,-1)) dönüşümleri ve deneysel ofsetler
  (`flagDx=0.021`, `flagDy=0.31`, `-1.915w` vb.) tamamen kaldırıldı. Bayraklar
  gerçek advance genişliğine sahip normal SMuFL glifleridir (8'lik, 16'lık,
  32'lik, 64'lük).
* **İkili aralık (second)** yer değiştirmesi, sabit `noteheadWidth -
  stemThickness` kadar; dik sapta sağa, ters sapta sola. Ayna dönüşümü yok.
* **Ek (ledger) çizgiler** `legerLineExtension` / `legerLineThickness`'e göre,
  ilgili notabaşlarının gerçek yatay kapsamına çizilir (alt/üst ayrı hesaplanır).
* **Aksidanlar** tam boyutta (SMuFL zaten porte ölçeğinde tasarlar; 0.8 küçültme
  kaldırıldı) ve dikey çakışan aksidanlar sola kaydırılarak istiflenir. Bu,
  0.0.2'deki ters-saplı bitişik ikili + aksidan çakışmasını (La♭5-Si♭5) yapısal
  olarak çözer; artık özel durum kodu yoktur.
* **Anahtarlar** (Sol/Fa/Do) origin baseline'ları işaret ettikleri porte
  çizgisine oturur; referans nota porte konumundan hesaplanır.
* **Barlar** `engravingDefaults` kalınlıklarıyla dikdörtgen olarak çizilir
  (bitiş barı kalın).
* Bravura SIL OFL 1.1 lisanslı paketle gelir (`fonts/Bravura.otf`,
  `fonts/OFL-Bravura.txt`, `fonts/bravura_metadata.json`). NotoMusic geriye dönük
  uyumluluk için hâlâ paketli.
* Testler (`render_gallery_test`, `music_notation_smoke_test`) Bravura yükler.
  28 senaryoluk görsel galeri regresyon güvencesi olarak korundu.

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
