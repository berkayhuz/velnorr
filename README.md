# Velnorr for MacBook

Velnorr, fiziksel çentik ölçüsünü `NSScreen` üzerinden okuyarak üst merkeze sabitlenen, saydam AppKit penceresi içinde çalışan SwiftUI kabuğudur. Pencere yalnızca görünür siyah şeklin hit-test alanını tüketir; şeklin dışındaki menü çubuğu ve diğer uygulamalar tıklanabilir kalır.

Desteklenen temel akışlar:

- Çökmüş fiziksel çentik veya çentiksiz ekranda kapsül (pill) görünümü.
- Hover için 240×44pt hızlı önizleme; albüm kapağı üzerinde 300×74pt Now Playing şeridi.
- Çentik güvenli alanına tıklayınca üst kenarı sabit kalan 350×175pt medya paneli.
- Spotify ve Apple Music üzerinden gerçek medya durumu, artwork, seek ve oynatma kontrolleri.
- Reduce Motion, hover genişletme, tam ekranda gösterme ve harici ekran pill/simulated-notch ayarları.
- Pencere çoğalmasını engelleyen tekil uygulama koruması ve hover çıkışında 110ms histerezis.

Ses/parlaklık HUD'ları, Bluetooth pil ayrıntıları, bildirim ve EventKit takvimi bu bağımsız SwiftPM hedefinde henüz bağlanmadı; macOS izinleri ve uygulama-özel veri kaynakları gerektiği için medya çekirdeği bunlardan ayrı tutuldu.

## Çalıştırma

```sh
swift run
```

Uygulama menü çubuğunda görünmeden çalışır ve tüm Spaces üzerinde üstte konumlanan saydam bir pencere kullanır. Gerçek çentik aralığı `NSScreen.auxiliaryTopLeftArea` ve `NSScreen.auxiliaryTopRightArea` ile hesaplanır; çentiksiz ekranlarda ayarlanabilir pill veya simulated-notch geometrisi seçilir.

## Proje yapısı

Kaynak kod, sorumlulukların birbirine karışmaması için özellik ve katman bazında ayrılmıştır:

- `App/`: uygulama giriş noktası, yaşam döngüsü, bildirimler ve kalıcı ayar anahtarları.
- `Domain/`: arayüz veya altyapıya bağlı olmayan durum ve medya modelleri.
- `Media/`: Spotify/Apple Music entegrasyonları ve arayüze sunulan medya durum deposu.
- `Window/`: saydam AppKit penceresi, hit-test ve mouse passthrough davranışı.
- `Layout/`: ekran/çentik ölçümleri ile sunum durumundan görünür geometri üretimi.
- `Views/`: velnorr kabuğu, ayarlar ve yeniden kullanılabilir Now Playing bileşenleri.
- `DesignSystem/`: animasyon değerleri ve özel velnorr şekli.

Yeni bir medya kaynağı `Media/` altında, yeni bir görsel özellik ise kendi `Views/` alt klasöründe eklenmelidir. Paylaşılan iş kuralları `Domain/` içinde tutulmalı; platforma özel AppKit kodu view modellerine taşınmamalıdır.

## UI önizleme modu

Şarj HUD tasarımını gerçek kablo takıp çıkarmadan sabit görmek için:

```sh
swift run Velnorr --preview-battery
```

Bu mod simüle edilmiş `%64` şarj durumunu sürekli gösterir. Gerçek pil davranışına dönmek için uygulamayı argümansız başlatın.

Şarj kablosu çıkarılmış görünümü sabitlemek için:

```sh
swift run Velnorr --preview-unplugged
```

Diğer test görünümleri:

```sh
swift run Velnorr --preview-low-battery
swift run Velnorr --preview-full-charge
swift run Velnorr --preview-battery-threshold
swift run Velnorr --preview-airpods
swift run Velnorr --preview-keyboard
swift run Velnorr --preview-mouse
swift run Velnorr --preview-speaker
```
