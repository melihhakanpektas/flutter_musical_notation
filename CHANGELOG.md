## 0.0.2

* Noto Music fontu artık paketle geliyor (`fonts/` + pubspec `fonts:`).
  Daha önce sistemin `NotoMusic` ailesine güveniliyordu: iOS'ta bu font yok,
  Android sürümleri arasında metrikler değişebiliyordu.
* Noktalı değer desteği: `MusicalValue.dotted` (flutter_music_core) süre
  hesabına (×1.5) ve çizime (notabaşı sağına, boşluk hizasında uzatma
  noktası) yansır.
* Ters saplı (stem-down) notaların kendi yatay slotundan taşıp sonraki
  sembolün üstüne binmesi düzeltildi (0.915w öteleme). Buna bağlı olarak
  ek (ledger) çizgiler ve ikili aralık (second) notabaşı ofsetleri yeni
  geometriyle hizalandı: ek çizgi her iki sap yönünde notabaşına ortalanır;
  ikili aralığın başı dik sapta sağa, ters sapta sola ofsetlenir. Ayrıca
  ikili aralığın ledger hesabında en tiz nota yerine yanlışlıkla en pes
  notayı kullanan kopyala-yapıştır hatası düzeltildi.
* `shouldRepaint` artık alanları karşılaştırıyor (eskiden her zaman `false`
  idi: tema/renk/nota değişimi repaint tetiklemiyordu).
* `horizontallyCenterNotes` içindeki sabit -37.5 px, boyutla orantılı hale
  getirildi (150 px yükseklikte eski davranışla birebir).
* Smoke testler eklendi (font yüklemeli render, dotted süre, shouldRepaint).

Bilinen sınırlar: ters saplı notalarda bayrak ayna görüntüsüdür ve başla sap
arasında küçük bir boşluk kalabilir; gravür kalitesi için uzun vadeli yol
SMuFL fontu (Bravura/Leland) + metadata tabanlı konumlandırmadır.

## 0.0.1

* İlk sürüm.
