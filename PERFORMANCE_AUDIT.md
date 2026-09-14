# Velnorr Performans Analizi ve İyileştirme Planı

Tarih: 14 Eylül 2026

Bu doküman, Velnorr projesinde herhangi bir kod değişikliği yapılmadan gerçekleştirilen statik kod analizi, build/test kontrolü ve çalışan uygulama üzerindeki kısa süreli runtime örneklemesi sonucunda hazırlanmıştır.

Dokümanın amacı, performans çalışmalarını gerçekleştirecek Codex GPT-5.6 Luna'ya dosya, sorun, gerekçe, uygulanacak çözüm ve kabul kriterleri açık bir backlog sağlamaktır.

## 1. Yönetici özeti

Projenin ana performans problemi uygulama veya paket boyutu değildir. Öncelikli problemler şunlardır:

1. Sistem ve medya servislerinin her ekran/pencere için yeniden oluşturulması.
2. Fare konumu için sürekli çalışan 10/30 Hz polling timer'ı.
3. Batarya bilgisinin ana thread üzerinde saniyede bir sorgulanması.
4. Waveform, progress ve marquee bileşenlerinin 30 Hz SwiftUI güncellemeleri.
5. Medya uygulaması çalışmasa bile devam eden sabit aralıklı media polling.
6. Artwork görsellerinin gösterim boyutundan çok daha büyük çözünürlükte decode edilmesi ve ekran başına ayrı cache tutulması.
7. `NSAppleScript` kullanımının Swift actor üzerinde çalıştırılması nedeniyle Apple'ın main-thread sözleşmesiyle çelişmesi.
8. Ayarlardan kapatılmış özelliklerin listener, event tap ve polling faaliyetlerinin devam etmesi.

Bu maddeler birlikte ele alındığında, aynı cihaz ve aynı senaryodaki CPU ve idle wakeup değerlerinde en az yüzde 50 azalma hedeflenmelidir.

## 2. Mevcut durum ve ölçümler

| Alan | Sonuç | Yorum |
|---|---:|---|
| Testler | 34/34 başarılı | Mevcut davranış için iyi regresyon tabanı |
| Test çalışma süresi | 1,95 sn; toplam 3,52 sn | Build cache kullanıldı |
| Release uygulama | 3,2 MB | Uygulama boyutu öncelikli sorun değil |
| DMG | 1,2 MB | Dağıtım paketi oldukça küçük |
| Harici Swift bağımlılığı | Yok | Dependency/bundle şişmesi bulunmuyor |
| Ölçülen pencere sayısı | 1 | Runtime ölçümü tek Velnorr penceresinde yapıldı |
| Debug CPU | Yaklaşık %6,4-%10,9 | Playing ve expanded görünüm çağrı yolları görüldü |
| Debug bellek | `top`: yaklaşık 86 MB | `vmmap` physical footprint 95,5 MB, peak 115 MB |
| Idle wakeup artışı | Yaklaşık 34-43/sn | 30 Hz timeline ve mouse polling ile uyumlu |
| Thread sayısı | 9 | Normal sınırda |
| Artwork disk cache | 19 görsel, yaklaşık 2,4 MB | Görseller çoğunlukla 640x640, biri 600x600 |

CPU ve bellek değerleri debug build'e aittir. Bunlar mutlak release hedefi olarak kullanılmamalıdır. Ancak örneklenen çağrı ağacında aşağıdaki yolların görülmesi darboğazların konumunu doğrulamaktadır:

- `TimelineView.UpdateFilter.updateValue`
- `ExpandedPlaybackProgress.body`
- `WaveformIcon.bars`
- SwiftUI layout ve AttributeGraph güncellemeleri
- `VelnorrWindow.mousePollingTimerDidFire`
- `VelnorrWindow.refreshMouseState`
- `BatteryChargeStore.readSnapshot`
- `MusicStatusStore.loadAndApplyNowPlaying`

## 3. Öncelikli uygulama backlog'u

### P0-1: Servisleri uygulama genelinde tekilleştir

#### Sorun

Her ekran için ayrı `VelnorrWindow`, her pencere içinde ayrı `VelnorrShellView` ve her shell içinde altı ayrı runtime servisi oluşturulmaktadır.

İlgili konumlar:

- `Sources/Velnorr/App/AppDelegate.swift:251`
- `Sources/Velnorr/Window/VelnorrWindow.swift:75`
- `Sources/Velnorr/Views/Velnorr/VelnorrShellView.swift:44`
- `Sources/Velnorr/Views/Velnorr/VelnorrShellView.swift:558`
- `Sources/Velnorr/Media/BluetoothConnectionStore.swift:31`

İki ekran olduğunda aşağıdaki işler ekran sayısıyla çarpılmaktadır:

- Media polling loop'ları ve AppleScript çağrıları
- Bir saniyelik batarya timer'ları
- Volume, brightness ve Caps Lock event tap'leri
- Bluetooth notification listener'ları
- Artwork cache ve decode işlemleri
- NotificationCenter abonelikleri
- Global/local mouse monitor'ları ve polling timer'ları

Bluetooth store içindeki yorum da bağlantı bildirimlerinin her Velnorr penceresi için ayrı teslim edilebildiğini açıkça belirtmektedir. Bu, mimari çoğalmanın doğrudan kod içi kanıtıdır.

#### Yapılacaklar

1. `@MainActor final class VelnorrRuntime` veya `VelnorrServices` oluştur.
2. Aşağıdaki servisleri bu runtime içinde tek instance olarak tut:

   - `MusicStatusStore`
   - `AudioVolumeStore`
   - `ScreenBrightnessStore`
   - `CapsLockStore`
   - `BatteryChargeStore`
   - `BluetoothConnectionStore`
   - `ArtworkService`

3. Runtime'ı `AppDelegate` yaşam döngüsünde bir kez oluştur ve başlat.
4. Shared store'ları her pencereye açık initializer parametreleri, `@ObservedObject` veya environment üzerinden geçir.
5. `VelnorrShellView` içinde yalnızca pencereye özgü interaction, hover ve layout state bırak.
6. Uygulama kapanırken bütün servisleri tek noktadan durdur.
7. Ayarlardan kapatılmış bir HUD için ilgili sensör/listener'ı çalıştırma.
8. Volume ve brightness için iki ayrı `systemDefined` event tap yerine ortak bir `SystemHUDEventTap` değerlendir.
9. Caps Lock maskesini de aynı permission/event-tap coordinator üzerinden yönet.
10. Permission alınmamışsa servis başına ve ekran başına oluşan retry task'larını tek bir permission coordinator'a indir.

#### Kabul kriterleri

- Bir ve iki ekran senaryosunda media polling loop sayısı `1` olmalı.
- Batarya observation kaynağı sayısı `1` olmalı.
- Bluetooth connect listener sayısı `1` olmalı.
- Her sistem tuşu için yalnızca bir event işleme zinciri çalışmalı.
- Paylaşılan state bütün Velnorr pencerelerinde doğru HUD'ı gösterebilmeli.
- İkinci ekran CPU, polling ve ağ işini iki katına çıkarmamalı.
- `swift test` tamamen başarılı olmalı.

### P0-2: Sürekli mouse polling'i kaldır veya gerçek fallback yap

#### Sorun

`Sources/Velnorr/Window/VelnorrWindow.swift:205` global ve local mouse monitor kurmaktadır. Buna rağmen global monitor başarıyla kurulsa bile ayrıca polling timer başlatılmaktadır.

Mevcut timer davranışı:

- Pointer uzaktayken 10 Hz
- Pointer pencereye yakınken 30 Hz
- Her pencere için ayrı timer
- Her tick'te `NSEvent.mouseLocation`, koordinat dönüşümü ve path hit-test
- Pill modunda her kontrolde yeni `CGPath` oluşturulması

İlgili kod:

- `Sources/Velnorr/Window/VelnorrWindow.swift:205`
- `Sources/Velnorr/Window/VelnorrWindow.swift:240`
- `Sources/Velnorr/Window/VelnorrWindow.swift:270`
- `Sources/Velnorr/Window/VelnorrWindow.swift:274`
- `Sources/Velnorr/Window/VelnorrWindow.swift:312`

Bu desen, ölçülen yaklaşık 34-43 wakeup/sn değerinin önemli kaynaklarından biridir.

Apple, olay bildirimi alınabilecek durumlarda polling timer'larının kullanılmamasını ve zorunlu timer'larda tolerance tanımlanmasını önermektedir:

- <https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html>

#### Yapılacaklar

1. Global mouse monitor başarıyla kurulursa fallback timer oluşturma.
2. Global monitor kurulamazsa polling'i fallback olarak devreye al.
3. Uygulama genelinde tek `MouseLocationCoordinator` kullanmayı değerlendir.
4. Local etkileşim için `NSTrackingArea` kullanmayı değerlendir.
5. `isMediaInteractive == true` iken pencere zaten event alacağı için fallback polling'i durdur.
6. Pill interaction path/rect değerini layout değiştiğinde bir kez hesapla ve cache'le.
7. `ignoresMouseEvents` değerini yalnızca yeni değer eskisinden farklıysa ata.
8. `.velnorrPointerInsideChanged` bildirimine `displayID` ekle veya state'i doğrudan ilgili pencereye gönder. Mevcut bildirimde ekran kimliği bulunmadığından bir pencerenin pointer state'i bütün shell'leri uyandırabilir.
9. Fallback timer zorunluysa idle frekansını 10 Hz yerine 2-4 Hz aralığında dene; yakın alanda 30 Hz korunabilir.

#### Kabul kriterleri

- Global monitor mevcutken `mouseTrackingTimer == nil` olmalı.
- Pointer hareket etmiyorken `refreshMouseState()` sürekli çağrılmamalı.
- Expanded media açıkken gereksiz mouse timer çalışmamalı.
- İki ekran mouse maliyetini iki katına çıkarmamalı.
- No-player/paused ve pointer uzakta release senaryosunda idle wakeup mümkünse `<5/sn` olmalı.
- Accessibility izni olmayan fallback senaryosu işlevsel kalmalı.

### P0-3: Batarya polling'ini event-driven hale getir

#### Sorun

`Sources/Velnorr/Media/BatteryChargeStore.swift:35` ana run loop üzerinde her saniye `IOPSCopyPowerSourcesInfo` çağırmaktadır. Timer tolerance tanımlanmamıştır.

Snapshot değişmemiş olsa bile her saniye aşağıdaki `@Published` alanlara tekrar atama yapılmaktadır:

```swift
level = snapshot.level
isCharging = snapshot.isPluggedIn
mode = ...
```

Bu atamalar eşit değerlerde bile `objectWillChange` ve SwiftUI invalidation üretebilir.

IOKit güç kaynağı değişiklikleri için `IOPSNotificationCreateRunLoopSource` sağlamaktadır:

- <https://developer.apple.com/documentation/iokit/1523868-iopsnotificationcreaterunloopsou?language=occ>

#### Yapılacaklar

1. İlk snapshot'ı uygulama başlatılırken bir kez oku.
2. `IOPSNotificationCreateRunLoopSource` ile güç kaynağı değişikliklerine abone ol.
3. Callback geldiğinde snapshot'ı yeniden oku.
4. Runtime kapanırken run-loop source'u kaldır ve release et.
5. Yalnızca gerçekten değişen alanları publish et.
6. Notification source oluşturulamazsa 30-60 saniyelik ve en az yüzde 10 tolerance içeren fallback timer kullan.
7. `isCharging = snapshot.isPluggedIn` atamasının semantik olarak doğru olup olmadığını ayrıca kontrol et. Snapshot içinde ayrı `isCharging` değeri zaten bulunmaktadır.

#### Kabul kriterleri

- Normal durumda bir saniyelik repeating battery timer bulunmamalı.
- Şarj bağlantısı, çıkarılması ve yüzde eşiği değişimleri HUD'ı doğru tetiklemeli.
- Batarya değişmiyorken SwiftUI update üretilmemeli.
- Store tekrar başlatılıp durdurulduğunda observer/run-loop source sızıntısı olmamalı.

### P1-4: 30 Hz SwiftUI güncellemelerini azalt

#### Sorunlu yerler

- `Sources/Velnorr/Views/NowPlaying/WaveformIcon.swift:17`
- `Sources/Velnorr/Views/NowPlaying/ExpandedNowPlayingView.swift:263`
- `Sources/Velnorr/Views/NowPlaying/NowPlayingInfoView.swift:74`

Expanded-playing durumda waveform ve progress iki ayrı 30 Hz `TimelineView` çalıştırmaktadır. Progress view her frame'de ayrıca:

- İki süre metnini formatlamakta,
- HStack ve GeometryReader ağacını değerlendirmekte,
- Progress genişliğini hesaplamakta,
- SwiftUI AttributeGraph ve layout çalışmasını tetiklemektedir.

SwiftUI `minimumInterval` değerini timeline güncellemeleri arasındaki alt sınır olarak kullanmaktadır:

- <https://developer.apple.com/documentation/swiftui/timelineschedule/animation%28minimuminterval%3Apaused%3A%29>

#### Yapılacaklar

1. Süre etiketlerini ayrı bir view'a çıkar ve yalnızca saniyede bir güncelle.
2. Progress bar için ilk aşamada 10 Hz kullan; görsel kalite yeterliyse 5-10 Hz aralığında bırak.
3. Alternatif olarak provider snapshot'ları arasında progress width'e linear animation uygula.
4. Waveform'u 15 Hz'e düşür.
5. Beş ayrı `Capsule` yerine tek `Canvas` veya `Path` çizimini değerlendir.
6. Waveform yalnızca görünür ve medya gerçekten çalıyorken çalışmalı.
7. Marquee için sürekli body evaluation yerine compositor-dostu linear offset animation değerlendir.
8. Reduce Motion veya animations-off durumunda timeline'lar yalnızca sabit çizim üretmeli.
9. Timeline tick'lerinin parent `VelnorrShellView` body hesaplamasını tetiklemediğini Instruments ile doğrula.
10. Metin ölçümünü yalnızca text, font veya kullanılabilir genişlik değiştiğinde yap.

#### Kabul kriterleri

- Expanded-playing release ölçümünde CPU ve wakeup değerleri aynı cihazda en az yüzde 50 azalmalı.
- Süre etiketleri saniyede en fazla bir kez formatlanmalı.
- Timeline görünür değilken tick üretmemeli.
- Paused durumda waveform/progress timeline'ı durmuş olmalı.
- Animasyon akıcılığında belirgin görsel regresyon olmamalı.

### P1-5: Media polling'i adaptif hale getir

#### Sorun

`Sources/Velnorr/Media/MusicStatusStore.swift:44` uygulama açık kaldığı sürece iki saniyede bir bütün provider'ları sırayla kontrol etmektedir.

Oynatıcı çalışmıyorken bile `NSRunningApplication.runningApplications` sorguları devam eder. Spotify ve Music birlikte açıksa iki AppleScript okuması yapılır.

İlgili konumlar:

- `Sources/Velnorr/Media/MusicStatusStore.swift:44`
- `Sources/Velnorr/Media/MusicStatusStore.swift:185`
- `Sources/Velnorr/Media/MusicStatusStore.swift:201`
- `Sources/Velnorr/Media/SpotifyNowPlayingProvider.swift:121`
- `Sources/Velnorr/Media/AppleMusicNowPlayingProvider.swift:128`

#### Yapılacaklar

1. `NSWorkspace.didLaunchApplicationNotification` ve `didTerminateApplicationNotification` ile Spotify/Music çalışma durumunu cache'le.
2. Hiçbir provider çalışmıyorsa polling'i durdur.
3. Provider launch bildirimi geldiğinde polling'i ve anlık refresh'i yeniden başlat.
4. Önerilen başlangıç polling aralıkları:

   - Expanded ve playing: 1-2 sn
   - Collapsed ve playing: 3-5 sn
   - Paused: 5-10 sn
   - Hiçbir player çalışmıyor: polling yok
   - Kullanıcı komutu veya sistem wake: anında refresh

5. `applicationURL` ve statik provider icon'larını cache'le.
6. Polling sleep için tolerance tanımla.
7. Provider'ları körlemesine paralelleştirme; AppleScript serialization korunmalı.
8. Provider çağrılarına süre ölçümü ekle.
9. Takılan Apple Event'in polling zincirini süresiz durdurmaması için AppleScript `with timeout` veya eşdeğer timeout tasarla.
10. Hızlı kullanıcı komutlarında aynı türde bekleyen seek/playback komutlarını coalesce etmeyi değerlendir.

#### NSAppleScript thread-safety uyarısı

`Sources/Velnorr/Media/AppleScriptExecutor.swift:4` normal bir Swift actor'dür. Bu yaklaşım komutları serialize eder fakat main-thread garantisi sağlamaz.

Apple'ın Cocoa thread-safety dokümantasyonu `NSAppleScript` sınıfını main-thread-only olarak listeler:

- <https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/ThreadSafetySummary/ThreadSafetySummary.html>

Uygulama sırası:

1. Önce AppleScript çağrı sayısını azalt ve servisleri tekilleştir.
2. `NSAppleScript` kullanımını `@MainActor` sözleşmesine uygun hale getir.
3. `OSSignposter` ile execution sürelerini ölç.
4. Main-thread stall oluşursa desteklenmeyen background `NSAppleScript` kullanımına dönme. Ayrı helper/XPC veya açıkça thread-safe bir Apple Event çözümü tasarla.

#### Kabul kriterleri

- Player kapalıyken periyodik AppleScript çağrısı olmamalı.
- İki ekran AppleScript çağrı sayısını artırmamalı.
- User command sonrasında anlık refresh korunmalı.
- AppleScript p95 süresi ve timeout sayısı ölçülebilmeli.
- Swift concurrency/thread-safety kontrolleri başarılı olmalı.

### P1-6: Artwork pipeline'ını gösterim boyutuna göre decode et

#### Sorun

`Sources/Velnorr/Media/ArtworkService.swift:37` içindeki mevcut akış:

- 600-640 px artwork indirir.
- Dominant color için `CGImageSourceCreateImageAtIndex` ile tam resmi decode eder.
- Main actor üzerinde `NSImage(data:)` ile tekrar image oluşturur.
- Görsel UI'da maksimum yaklaşık 54 pt gösterilir.
- Her shell ayrı `ArtworkService` ve ayrı 50 MB cache taşır.
- Cache cost yalnızca sıkıştırılmış `Data.count` değerini hesaba katar; decoded pixel maliyetini yansıtmaz.

ImageIO, source'tan doğrudan thumbnail oluşturmayı desteklemektedir:

- <https://developer.apple.com/documentation/imageio/cgimagesourcecreatethumbnailatindex%28_%3A_%3A_%3A%29>

#### Yapılacaklar

1. `ArtworkService` uygulama genelinde shared olmalı.
2. Image source'tan yaklaşık 128-160 px thumbnail üret.
3. Aşağıdaki seçenekleri kullan:

   - `kCGImageSourceCreateThumbnailFromImageAlways`
   - `kCGImageSourceThumbnailMaxPixelSize`
   - `kCGImageSourceCreateThumbnailWithTransform`
   - Gerekirse `kCGImageSourceShouldCacheImmediately`

4. Dominant color'ı thumbnail üzerinden çıkar.
5. Cache'e raw büyük data yerine hazırlanmış/downsample edilmiş görsel ve color koy.
6. Cache cost'u `bytesPerRow * height` üzerinden hesapla.
7. Aynı URL için eşzamanlı cache miss'leri `[URL: Task]` tablosuyla coalesce et.
8. Görsel oluşturulduktan sonra gereksiz raw `Data` retention'ını kaldır.
9. Yanlış veya eksik `Content-Length` durumunda indirme tamamlandıktan sonra kontrol etmek yerine akış sırasında üst sınır uygulamayı değerlendir.

#### Kabul kriterleri

- 640x640 artwork UI için 128-160 px civarında decode edilmeli.
- Aynı URL tek kez indirilmeli ve tek kez decode edilmeli.
- İki ekran ayrı artwork cache oluşturmamalı.
- 100 track değişimi sonrasında bellek belirli seviyede plato yapmalı.
- Artwork geçişleri ve dominant color davranışı korunmalı.

### P2-7: Statik SVG ve NSImage yüklemelerini cache'le

#### Sorun

`Sources/Velnorr/Views/Velnorr/BatteryHUDView.swift:100` `Battery.svg` dosyasını body hesaplanırken yüklemektedir. Aynı `svgImage` ZStack içinde iki kez kullanıldığı için aynı render sırasında iki ayrı `NSImage(contentsOf:)` oluşabilir.

Benzer tekrarlar şu alanlarda bulunmaktadır:

- `Sources/Velnorr/Media/SpotifyNowPlayingProvider.swift:15`
- `Sources/Velnorr/Media/AppleMusicNowPlayingProvider.swift:15`
- `Sources/Velnorr/Views/Settings/VelnorrSettingsView.swift:858`
- `Sources/Velnorr/Views/Onboarding/VelnorrOnboardingView.swift:258`

#### Yapılacaklar

1. Statik görselleri `ResourceImages` namespace'i altında `static let` olarak bir kez yükle.
2. Mümkünse asset catalog veya native SwiftUI resource kullan.
3. Battery HUD render'ında dosya I/O veya SVG parse yapılmadığını File Activity ile doğrula.
4. Provider application icon cache'ini shared runtime'a bağla.

#### Kabul kriterleri

- HUD render sırasında `NSImage(contentsOf:)` çağrısı yapılmamalı.
- Static image instance'ları pencereler arasında paylaşılmalı.
- Görsel kalite ve template rendering davranışı korunmalı.

### P2-8: Bluetooth `system_profiler` çağrısını kontrollü hale getir

#### Sorun

`Sources/Velnorr/Media/BluetoothConnectionStore.swift:264` uygun Bluetooth bağlantısından sonra aşağıdaki ağır process'i çalıştırmaktadır:

```text
/usr/sbin/system_profiler SPBluetoothDataType -json
```

Actor üzerinde senkron `readDataToEndOfFile` ve `waitUntilExit` kullanılmaktadır. İşlem saniyeler sürebilir; Swift task cancellation child process'i durdurmaz.

#### Yapılacaklar

1. Önce shared runtime ile aynı bağlantı için birden fazla process açılmasını engelle.
2. `Process` çalışmasını gerçek async wrapper'a al.
3. 3-5 saniyelik timeout ekle.
4. Parent task cancel edilirse child process'i terminate et.
5. Utility QoS kullan.
6. Aynı cihaz için kısa süreli battery-result cache ekle.
7. `recentConnectionEvents` sözlüğündeki süresi geçmiş kayıtları temizle ve sözlüğü sınırla.
8. İleride `system_profiler` yerine daha hafif bir IOKit/IORegistry yolu araştır; davranışı doğrulamadan private API ekleme.

#### Kabul kriterleri

- Aynı bağlantı olayı yalnızca bir `system_profiler` process'i oluşturmalı.
- Timeout/cancellation durumunda child process yaşamaya devam etmemeli.
- Bluetooth battery lookup UI main thread'ini bloklamamalı.
- Lookup başarısız olduğunda HUD mevcut sessiz-failure davranışını korumalı.

### P2-9: SwiftUI ve UserDefaults invalidation alanını daralt

#### Bulgular

- `VelnorrShellView`: 34 adet `@AppStorage`
- `AdditionalSettingsPage`: 54 adet `@AppStorage`
- Proje genelinde: 107 adet `@AppStorage`

Her slider hareketi UserDefaults değişikliği, shell invalidation ve `AppDelegate` içindeki `UserDefaults.didChangeNotification` kontrolü üretebilir.

İlgili konumlar:

- `Sources/Velnorr/Views/Velnorr/VelnorrShellView.swift:10`
- `Sources/Velnorr/Views/Settings/VelnorrSettingsView.swift:370`
- `Sources/Velnorr/App/AppDelegate.swift:53`
- `Sources/Velnorr/App/AppDelegate.swift:212`

#### Yapılacaklar

1. Önce Instruments SwiftUI template ile geniş invalidation gerçekten oluşuyor mu ölç.
2. Doğrulanırsa ayarları section bazlı observable configuration modellerine ayır.
3. Shell'e yalnızca render için gereken configuration snapshot'ını geçir.
4. Slider değerlerini geçici UI state'inde tutup drag sonunda veya debounce sonrasında UserDefaults'a yazmayı değerlendir.
5. `AppDelegate` yalnızca pencere yönetimini etkileyen ayarları gözlemlemeli.
6. Büyük shell body'yi stabil input alan küçük subview'lara böl.
7. Uygun ve ölçülmüş yerlerde `Equatable`/`.equatable()` kullan.
8. Profil import/reset içindeki `UserDefaults.synchronize()` çağrılarını kaldır.

Bu madde P0/P1 tamamlanmadan geniş bir mimari refaktora dönüştürülmemelidir.

#### Kabul kriterleri

- Bir settings slider'ı yalnızca ilgili UI alt ağacını invalid etmeli.
- Normal runtime'da UserDefaults değişikliği bulunmadığında ek iş oluşmamalı.
- Settings import/profile davranışı korunmalı.

### P2-10: Onboarding timer'ını yalnızca gerektiğinde çalıştır

#### Sorun

`Sources/Velnorr/Views/Onboarding/VelnorrOnboardingView.swift:89` onboarding'in bütün sayfalarında saniyede bir permission kontrolü yapmaktadır.

#### Yapılacaklar

1. Permission polling yalnızca `.permissions` sayfasındayken çalışmalı.
2. İki izin de verildiğinde polling durmalı.
3. `NSApplication.didBecomeActiveNotification` geldiğinde bir kez permission kontrolü yap.
4. Permission gerektiren store'ları onboarding tamamlanmadan başlatmamayı değerlendir.
5. Unstructured timer publisher yerine yaşam döngüsü açıkça yönetilen cancellable task veya observer kullan.

#### Kabul kriterleri

- Welcome ve indicators sayfalarında bir saniyelik timer çalışmamalı.
- İzinler tamamlandığında permission polling bitmeli.
- Onboarding kapanınca task/subscription yaşamaya devam etmemeli.

## 4. Ölçüm ve performans regresyon altyapısı

İlk üretim değişikliğinden önce `OSSignposter` ile aşağıdaki interval/event noktaları eklenmelidir:

- `media.refresh`
- `applescript.execute`
- `artwork.download`
- `artwork.decode`
- `battery.read`
- `bluetooth.system_profiler`
- `window.mouse.refresh`
- `shell.presentation.transition`

Apple signpost interval'larının Instruments call tree ile birlikte kullanılmasını önermektedir:

- <https://developer.apple.com/documentation/os/recording-performance-data>
- <https://developer.apple.com/documentation/xcode/analyzing-cpu-profiles-with-call-tree-views>

### Release ölçüm matrisi

Her performans aşaması aşağıdaki senaryolarla ölçülmelidir:

1. Tek ekran, player kapalı, pointer uzakta.
2. Tek ekran, paused medya.
3. Tek ekran, playing/collapsed.
4. Tek ekran, playing/expanded.
5. Uzun marquee metni.
6. İki ekran ile aynı senaryolar.
7. Settings açık ve slider sürükleniyor.
8. Artwork değişimi.
9. Bluetooth cihaz bağlantısı.
10. Accessibility/Input Monitoring izni bulunmayan fallback durumu.
11. Sistem sleep/wake geçişi.
12. Uygulamanın cold launch senaryosu.

### Kaydedilecek metrikler

- Ortalama ve p95 CPU
- Idle wakeups/sn
- Physical footprint ve peak memory
- Main-thread hitch/hang
- Dakika başına AppleScript çağrısı
- Provider başına AppleScript p50/p95 süresi
- Artwork download/decode sayısı
- Artwork cache hit/miss oranı
- Çalıştırılan `system_profiler` process sayısı
- Bir ve iki ekran arasındaki CPU/wakeup farkı

Performans regresyon testleri için uygun XCTest metrikleri:

- `XCTCPUMetric`
- `XCTMemoryMetric`
- `XCTHitchMetric`
- `XCTOSSignpostMetric`
- `XCTApplicationLaunchMetric`

Kaynak:

- <https://developer.apple.com/documentation/xctest/xctapplicationlaunchmetric>

## 5. AI Quality Gate: Zorunlu kalite ve teslimat protokolü

Bu bölüm, bu dokümandaki işleri uygulayacak bütün yapay zeka ajanları için bağlayıcıdır. Ajanın modeli, bağlam kapasitesi veya kodlama kabiliyeti ne olursa olsun aşağıdaki kapılar atlanamaz.

Repository kökündeki `AGENTS.md` genel mühendislik kalite sözleşmesidir ve bütün görevlerde ayrıca bağlayıcıdır. Çelişki bulunursa iki belgeden daha sıkı olan kural uygulanmalıdır; hiçbir kural sessizce devre dışı bırakılamaz.

Bir iş ancak bütün zorunlu kapılar geçildiğinde tamamlanmış sayılır. Kodun derlenmesi tek başına başarı değildir. Bir testin geçmesi performansın iyileştiğini kanıtlamaz. Kod değişmiş olması da problemin çözüldüğü anlamına gelmez.

### 5.1 Değiştirilemez çalışma ilkeleri

Her yapay zeka ajanı aşağıdaki kurallara uymalıdır:

1. Önce problemi ve mevcut davranışı doğrula, sonra kod değiştir.
2. Ölçülmemiş performans varsayımını gerçek bulgu gibi sunma.
3. Bir seferde yalnızca tek mantıksal performans problemini çöz.
4. İlgisiz refactor, yeniden adlandırma veya biçimlendirme yapma.
5. Mevcut kullanıcı değişikliklerini silme, geri alma veya üzerine yazma.
6. Public davranışı, görsel tasarımı ve ayar anlamlarını açık gereklilik olmadan değiştirme.
7. Yeni concurrency eklerken Swift 6 isolation ve cancellation kurallarını açıkça doğrula.
8. Timer, observer, event tap, task, process ve callback için sahiplik ve cleanup yolu tanımla.
9. Her optimizasyon için before/after kanıtı üret.
10. Kanıt bulunmuyorsa `tamamlandı` deme; `uygulandı fakat etkisi henüz doğrulanmadı` de.
11. Testleri kapatarak, assertion silerek veya başarı eşiğini gevşeterek kalite kapısını geçmeye çalışma.
12. Hata yutmayı performans iyileştirmesi olarak kullanma.
13. Cache eklerken invalidation, üst sınır, maliyet hesabı ve memory pressure davranışını tanımla.
14. Polling kaldırılırken event kaybı ve fallback senaryosunu test et.
15. Debug build sonucunu release performans sonucu gibi raporlama.
16. Bir araç çalışmıyorsa sonucu tahmin etme; eksik ölçümü ve nedenini açıkça yaz.
17. Aynı işi yapan ikinci bir mimari yol bırakma. Yeni yol doğrulandıktan sonra eski yol güvenli biçimde kaldırılmalı.
18. Kod yorumlarını yapılan davranışla senkron tut.
19. Geçici debug log, profile dosyası, kişisel medya verisi veya build artifact commit etme.
20. Sonuç raporunda yalnızca gerçekten çalıştırılan test ve ölçümleri belirt.

### 5.2 Gate 0: Repository ve kapsam güvenliği

Kod değişikliğinden önce aşağıdakiler zorunludur:

- Repository talimatlarını ve ilgili dokümantasyonu oku.
- `git status --short` ile mevcut kullanıcı değişikliklerini kaydet.
- Değiştirilecek dosyaları ve nedenlerini listele.
- İlgili servis, view, test ve lifecycle kodunu uçtan uca oku.
- Değişikliğin hangi public davranışları koruması gerektiğini yaz.
- Risk sınıfını belirle: düşük, orta veya yüksek.
- Rollback sınırını belirle: hangi dosyalar geri alınırsa değişiklik tamamen kaldırılmış olur?

#### Gate 0 başarısızlık koşulları

Aşağıdaki durumlardan biri varsa ajan uygulamaya başlamamalıdır:

- Kullanıcının mevcut değişiklikleriyle güvenli biçimde ayrıştırılamayan bir çakışma bulunması.
- Gereksinimin kullanıcı davranışını değiştiren bir karar gerektirmesi ve bu kararın dokümanda tanımlı olmaması.
- Ölçülecek baseline senaryosunun çalıştırılamaması ve hiçbir güvenilir alternatif kanıt bulunmaması.
- Değişikliğin gerekli izin, entitlement veya packaging etkisinin anlaşılmamış olması.

#### Gate 0 çıkış kanıtı

```text
Kapsam:
Değiştirilecek dosyalar:
Korunacak davranışlar:
Mevcut kullanıcı değişiklikleri:
Risk sınıfı:
Rollback sınırı:
Baseline senaryosu:
```

### 5.3 Gate 1: Baseline ve hipotez

Her optimizasyon başlamadan önce tek cümlelik test edilebilir hipotez yazılmalıdır.

Doğru örnek:

```text
Global mouse monitor kurulmuşken fallback timer'ın durdurulması,
pointer sabitken idle wakeup değerini en az yüzde 20 azaltacaktır.
```

Yanlış örnek:

```text
Mouse kodunu optimize edeceğim.
```

Baseline aşağıdakileri içermelidir:

- Kullanılan build türü: Debug veya Release
- Cihaz, macOS sürümü ve ekran sayısı
- Senaryo ve senaryo süresi
- CPU ortalama/p95 veya örnek aralığı
- Idle wakeups/sn
- Physical footprint ve peak memory, ilgiliyse
- İşlem/çağrı sayısı: AppleScript, artwork decode, `system_profiler` vb.
- Ölçüm aracı ve komut/yöntem

Baseline alınamıyorsa ajan koddan çıkarım yapabilir, ancak bunu `statik analiz bulgusu` olarak etiketlemeli ve performans kazanımı yüzdesi iddia etmemelidir.

### 5.4 Gate 2: Tasarım onayı kontrol listesi

Uygulamadan önce ajan aşağıdaki soruları cevaplamalıdır:

- Bu değişiklik problemi kökten mi çözüyor, yalnızca semptomu mu gizliyor?
- Yeni bir timer, task, observer, cache veya global state ekleniyor mu?
- Ekleniyorsa sahibi kim ve ne zaman temizleniyor?
- Çoklu ekran davranışı nasıl korunuyor?
- Uygulama sleep/wake sonrasında nasıl davranıyor?
- Permission yokken fallback nedir?
- Feature ayarlardan kapatıldığında ilgili iş gerçekten duruyor mu?
- Task cancellation child operation'a kadar ulaşıyor mu?
- MainActor üzerinde bloklayıcı I/O veya CPU işi kalıyor mu?
- Cache için count/cost limit ve invalidation stratejisi var mı?
- Event-driven çözüm olayı kaçırırsa ilk state nasıl kuruluyor?
- Değişiklik eski macOS minimum sürümüyle uyumlu mu?
- Packaging, entitlement ve privacy açıklamalarına etkisi var mı?
- Yeni abstraction gerçekten birden fazla tüketici tarafından kullanılıyor mu?

Bu sorulardan cevapsız kalan varsa implementation başlamamalıdır.

### 5.5 Gate 3: Implementation disiplini

Kod yazarken aşağıdaki kurallar uygulanmalıdır:

1. Değişikliği mümkün olan en küçük diff ile yap.
2. Önce production kodu değil, mümkünse davranışı tanımlayan test veya ölçüm kancasını ekle.
3. Her lifecycle kaynağı için simetrik başlangıç ve bitiş yolu oluştur:

   - `start` / `stop`
   - add observer / remove observer
   - create run-loop source / remove ve release
   - create event tap / disable ve remove
   - spawn process / timeout ve terminate
   - create task / cancel ve reference temizleme

4. `weak self` kullanımının işi sessizce düşürüp düşürmediğini kontrol et.
5. Cancellation sonrasında state güncellemesi yapılmadığını doğrula.
6. Aynı state'i eşit değerle tekrar publish etme.
7. MainActor'a yalnızca UI/state mutation taşı; bloklayıcı iş taşımama kuralını platform API sözleşmeleriyle birlikte değerlendir.
8. Performans uğruna thread-safety sözleşmesini ihlal etme.
9. Çoklu ekran için instance sayısını log/signpost veya test spy ile kanıtla.
10. Magic number ekleniyorsa gerekçesini ve ölçüm bağlamını kod yorumunda belirt.
11. Geçici fallback kalıyorsa hangi koşulda çalıştığını açıkça kodla ve test et.
12. Mevcut testleri değiştirmek gerekiyorsa davranış değişikliğinin neden gerekli olduğunu raporla.

### 5.6 Gate 4: Zorunlu doğrulama piramidi

Bir değişiklik aşağıdaki sırayla doğrulanmalıdır.

#### A. Statik kontrol

- Derleyici warning ve error bulunmamalı.
- Swift 6 concurrency warning bulunmamalı.
- Yeni force unwrap veya kontrolsüz type cast eklenmemeli.
- Yeni sonsuz task/timer oluşturulmamalı.
- Observer ve callback retain cycle kontrol edilmeli.

#### B. Unit test

- İlgili mevcut testler çalışmalı.
- Yeni davranış için focused test eklenmeli.
- Başarı, failure, cancellation ve restart yolu kapsanmalı.
- Çoklu instance oluşturma riski varsa spy/counter testi bulunmalı.

#### C. Tam test paketi

```sh
swift test
```

Bütün testler geçmeden iş tamamlanmış sayılmaz.

#### D. Release build

```sh
swift build -c release
```

Yalnızca debug build alan değişiklik production-ready kabul edilmez.

#### E. Runtime smoke test

En azından ilgili özelliğin gerçek veya preview akışı çalıştırılmalıdır. Ajan aşağıdakileri kontrol etmelidir:

- Uygulama açılıyor.
- HUD doğru görünür ve kapanır.
- Mouse passthrough çalışır.
- Player yokken uygulama stabil kalır.
- Permission yokken crash veya sonsuz retry oluşmaz.
- Sleep/wake sonrasında servisler çalışmaya devam eder.
- Uygulama kapanırken child process veya orphan task kalmaz.

#### F. Before/after performans ölçümü

Baseline ile aynı build, cihaz, ekran sayısı, state ve süre kullanılmalıdır. Senaryo değiştiyse sonuçlar karşılaştırılmamalıdır.

### 5.7 Gate 5: Regresyon ve olumsuz senaryo testi

Her değişiklik yalnızca mutlu yolu değil aşağıdaki olumsuz yolları da kontrol etmelidir:

- Spotify kurulu değil.
- Apple Music çalışmıyor.
- İki player aynı anda açık.
- Ağ yok veya artwork isteği başarısız.
- Artwork çok büyük veya geçersiz.
- Accessibility/Input Monitoring izni yok.
- İzin uygulama çalışırken veriliyor.
- Bluetooth sorgusu timeout oluyor.
- Task tam callback öncesinde cancel ediliyor.
- İkinci ekran ekleniyor veya çıkarılıyor.
- Uygulama sleep/wake geçiriyor.
- Reduce Motion açık.
- İlgili HUD ayarlardan kapalı.
- Settings slider'ı hızlı biçimde değiştiriliyor.
- Uygulama arka arkaya start/stop yaşam döngüsü geçiriyor.

Bir olumsuz senaryo otomatikleştirilemiyorsa manuel test adımı ve beklenen sonuç açıkça raporlanmalıdır.

### 5.8 Gate 6: Performans başarı eşiği

Bir performans değişikliği aşağıdaki koşullardan en az birini kanıtlamalıdır:

- İlgili CPU metriğinde anlamlı ve tekrar üretilebilir azalma.
- Idle wakeup sayısında anlamlı azalma.
- Main-thread hitch veya bloklama süresinde azalma.
- Peak/steady-state memory değerinde azalma.
- Aynı iş için çağrı/process/decode sayısında doğrulanmış azalma.
- Çoklu ekran maliyetinin `O(ekran sayısı)` davranışından shared sabit maliyete düşmesi.

Ölçüm gürültüsü içindeki yüzde 1-3 fark başarı olarak sunulmamalıdır. En az üç karşılaştırmalı run alınmalı; medyan değer raporlanmalıdır.

Bu proje için ana hedefler:

- P0 ve P1 toplamından sonra playing/expanded CPU'da en az yüzde 50 azalma.
- Global monitor mevcut, player kapalı ve pointer uzaktayken idle wakeup `<5/sn` hedefi.
- İki ekrana geçişte media, battery, Bluetooth ve event tap iş sayısının artmaması.
- Aynı artwork URL'si için bir download ve bir decode.
- Player kapalıyken periyodik AppleScript çağrısı olmaması.

Hedef karşılanmıyorsa ajan:

1. Değişikliği başarılı ilan etmemeli.
2. Ölçüm sonuçlarını saklamadan raporlamalı.
3. Hipotezin neden yanlış çıktığını açıklamalı.
4. Değişikliğin korunması veya geri alınması için teknik gerekçe sunmalı.

### 5.9 Gate 7: Kod inceleme kontrolü

Teslimden önce ajan kendi diff'ini reviewer gibi yeniden okumalıdır:

- Diff yalnızca görev kapsamındaki dosyaları mı içeriyor?
- Davranış değişikliği yanlışlıkla yapılmış mı?
- Aynı servis hâlâ başka bir yerde ikinci kez oluşturuluyor mu?
- Yeni code path eski code path ile birlikte çift çalışıyor mu?
- Stop/deinit yolu bütün kaynakları temizliyor mu?
- Error path state'i tutarsız bırakıyor mu?
- `Task.isCancelled` kontrolleri sonuç uygulamadan önce mevcut mu?
- Timeout child işi gerçekten sonlandırıyor mu?
- State mutation doğru actor üzerinde mi?
- Yeni cache memory pressure altında boşaltılabiliyor mu?
- Test yalnızca implementation detayını mı test ediyor, gerçek davranışı mı?
- Comment ve dokümantasyon kodla aynı şeyi mi söylüyor?
- Log içinde kişisel track, artist, URL, cihaz adı/adresi veya artwork verisi var mı?
- Performance signpost yüksek frekansta gereksiz string allocation yapıyor mu?

Bu kontrolden sonra `git diff --check` çalıştırılmalı ve final diff okunmalıdır.

### 5.10 Gate 8: Definition of Done

Bir madde yalnızca aşağıdaki şartların tamamı sağlandığında `tamamlandı` olarak işaretlenebilir:

- [ ] Problem kod veya runtime ölçümüyle doğrulandı.
- [ ] Test edilebilir hipotez yazıldı.
- [ ] Baseline kaydedildi veya neden alınamadığı açıkça belirtildi.
- [ ] Değişiklik görev kapsamıyla sınırlı kaldı.
- [ ] Lifecycle ve cleanup yolları uygulandı.
- [ ] Focused test eklendi veya neden gerekmediği açıklandı.
- [ ] `swift test` başarılı.
- [ ] `swift build -c release` başarılı.
- [ ] İlgili runtime smoke test başarılı.
- [ ] Olumsuz senaryolar kontrol edildi.
- [ ] Before/after aynı koşullarda ölçüldü.
- [ ] Ölçüm hedefi karşılandı veya sonuç dürüstçe başarısız olarak raporlandı.
- [ ] Çoklu ekran davranışı kontrol edildi.
- [ ] Accessibility ve Reduce Motion davranışı korundu.
- [ ] Final diff reviewer gözüyle incelendi.
- [ ] `git diff --check` başarılı.
- [ ] Geçici log, artifact ve kişisel veri bırakılmadı.
- [ ] Kalan riskler ve takip işleri raporlandı.

Kutulardan biri boşsa görev tamamlanmış değildir.

### 5.11 Yasak tamamlanma ifadeleri

Aşağıdaki ifadeler tek başına teslim kanıtı değildir ve kullanılmamalıdır:

- "Kod optimize edildi."
- "Daha performanslı hale getirildi."
- "Muhtemelen CPU kullanımı düştü."
- "Test yazmaya gerek yok."
- "Derlendiği için çalışacaktır."
- "Basit bir değişiklik olduğu için release test etmedim."
- "Aynı davranışı koruyor gibi görünüyor."
- "Instruments kullanamadım ama sorun çözüldü."

Doğru teslim dili ölçülebilir olmalıdır:

```text
Release build üzerinde aynı 60 saniyelik playing/expanded senaryosunda
median CPU %8,4'ten %3,6'ya, idle wakeup 38/sn'den 14/sn'ye düştü.
Üç run gerçekleştirildi. 34 mevcut ve 6 yeni test başarılı.
İki ekran testinde media polling sayısı değişmedi.
```

### 5.12 Zorunlu teslim raporu şablonu

Her ajan final yanıtında aşağıdaki yapıyı kullanmalıdır:

```text
Görev:
Durum: Tamamlandı / Kısmen doğrulandı / Başarısız / Bloke

Kök neden:

Değiştirilen dosyalar:
- Dosya: yapılan değişiklik ve gerekçesi

Korunan davranışlar:

Testler:
- Komut:
- Sonuç:
- Yeni testler:

Runtime doğrulaması:
- Senaryo:
- Sonuç:

Performans ölçümü:
- Build:
- Cihaz/macOS/ekran:
- Süre ve run sayısı:
- Before:
- After:
- Değişim:

Kalite kapıları:
- Gate 0: geçti/geçmedi
- Gate 1: geçti/geçmedi
- Gate 2: geçti/geçmedi
- Gate 3: geçti/geçmedi
- Gate 4: geçti/geçmedi
- Gate 5: geçti/geçmedi
- Gate 6: geçti/geçmedi
- Gate 7: geçti/geçmedi
- Gate 8: geçti/geçmedi

Kalan riskler:

Takip işleri:
```

### 5.13 AI ajanına verilecek üst seviye zorunlu talimat

Aşağıdaki blok, herhangi bir performans maddesi başka bir yapay zekaya devredilirken görev metninin başına aynen eklenmelidir:

```text
Bu görev production-grade ve enterprise kalite kapılarıyla yürütülecektir.
Önce repository kökündeki AGENTS.md dosyasının tamamını oku ve uygula.
PERFORMANCE_AUDIT.md içindeki "AI Quality Gate" bölümünün tamamı ayrıca bağlayıcıdır.
İki belgede farklı sıkılıkta kurallar varsa daha sıkı olanı uygula.

Kod yazmadan önce Gate 0-2 çıktılarını hazırla. Ardından tek bir mantıksal değişiklik
uygula. Gate 3-8 tamamlanmadan işi bitmiş sayma. Test veya ölçüm çalıştırmadıysan
çalıştırmış gibi yazma. Before/after kanıtı olmadan performans kazanımı iddia etme.
Kullanıcının mevcut değişikliklerini silme veya üzerine yazma. İlgisiz refactor yapma.

Bir kapıyı geçemiyorsan problemi gizleme: görevi Kısmen doğrulandı veya Bloke olarak
raporla; eksik kapıyı, nedeni ve tamamlamak için gereken somut adımı belirt.
```

## 6. GPT-5.6 Luna için uygulama talimatı

Aşağıdaki metin doğrudan uygulama görevi olarak kullanılabilir:

```text
Velnorr performans çalışmasını görsel tasarımı ve mevcut kullanıcı davranışını
değiştirmeden gerçekleştir. Bu dosyanın "AI Quality Gate" bölümündeki bütün kapılar
ve teslimat kuralları bağlayıcıdır. Kod yazmadan önce repository kökündeki
AGENTS.md dosyasının tamamını oku; genel kalite kapılarını da eksiksiz uygula.

Uygulama sırası:
1. OSSignposter ve ölçüm altyapısı
2. Servisleri AppDelegate/VelnorrRuntime seviyesinde tekilleştirme
3. Mouse monitor ve fallback polling düzeltmesi
4. Battery polling yerine IOPS notification
5. 30 Hz TimelineView optimizasyonları
6. Adaptif media polling ve NSAppleScript thread-safety
7. Artwork downsampling ve shared cache
8. Statik resource cache
9. Bluetooth system_profiler timeout/cancellation
10. Yalnızca ölçümle doğrulanırsa UserDefaults/SwiftUI invalidation refaktoru

Kurallar:
- Her maddeyi ayrı ve küçük bir değişiklik olarak uygula.
- Önce before ölçümü, sonra kod değişikliği, ardından aynı senaryoda after ölçümü al.
- Her adımdan sonra swift test çalıştır.
- Tek ve iki ekran davranışını doğrula.
- Volume, brightness, Caps Lock, battery, Bluetooth ve media HUD davranışını koru.
- Swift 6 concurrency kurallarını ihlal etme.
- NSAppleScript çağrılarını körlemesine paralelleştirme.
- Debug ölçümlerini release başarı kriteri olarak kullanma.
- Uygulama boyutunu değil; idle wakeup, sürekli CPU, main-thread responsiveness,
  memory plateau ve çoklu ekran ölçeklenmesini önceliklendir.
- Bir optimizasyon ölçülebilir iyileşme sağlamıyorsa değişikliği büyütme.

Her aşamanın sonunda şunları raporla:
- Değiştirilen dosyalar
- Çözülen performans problemi
- Before/after CPU
- Before/after idle wakeups/sn
- Before/after physical footprint
- Test sonucu
- Kalan riskler
```

## 7. Uygulama sırası ve bağımlılıklar

Önerilen fazlar:

### Faz A: Ölçülebilirlik ve mimari temel

1. Signpost altyapısı
2. Shared `VelnorrRuntime`
3. Store lifecycle ve feature enable/disable yönetimi

Bu faz tamamlanmadan diğer optimizasyonların çoklu ekran etkisi doğru ölçülemez.

### Faz B: Sürekli wakeup kaynakları

1. Mouse polling fallback düzeltmesi
2. IOPS battery notification
3. Permission retry coordinator
4. Player yokken media polling'in durdurulması

### Faz C: Render maliyeti

1. Progress label ve bar güncellemelerini ayırma
2. Waveform frekansı ve Canvas değerlendirmesi
3. Marquee compositor animation
4. Reduce Motion/hidden state pause kontrolleri

### Faz D: I/O ve bellek

1. Artwork downsampling
2. Shared/in-flight artwork cache
3. Statik SVG cache
4. Bluetooth process timeout ve cancellation

### Faz E: Ölçülürse ileri SwiftUI düzenlemeleri

1. UserDefaults/configuration model
2. View invalidation sınırlandırması
3. Settings slider debounce
4. Performance regression testleri

## 8. Öncelik verilmeyecek alanlar

Mevcut verilere göre aşağıdaki alanlar şu anda performans çalışmasının odağı olmamalıdır:

- Binary veya DMG küçültme: uygulama zaten yaklaşık 3,2 MB, DMG yaklaşık 1,2 MB.
- Dependency temizliği: harici Swift package bağımlılığı yok.
- Layout resolver mikro-optimizasyonları: mevcut maliyet sürekli timer ve timeline işlerine göre çok düşük.
- Provider parse fonksiyonları: basit string ayrıştırma ve iki saniyelik polling içinde ihmal edilebilir maliyette.
- Kısa süreli HUD hide task'ları: doğru şekilde cancel ediliyor ve kalıcı per-frame iş oluşturmuyor.

Önce P0 ve P1 maddeleri uygulanmalı; mikro-optimizasyon ancak yeni Instruments ölçümünde görünürse yapılmalıdır.

## 9. Sonuç

Velnorr küçük ve bağımlılıksız bir uygulama olmasına rağmen sürekli açık kalan bir menü çubuğu aracı olduğu için performans başarısı yalnızca anlık hızla değil, CPU'nun ne kadar süre uyuyabildiğiyle ölçülmelidir.

En büyük kazanım şu üç değişiklikten beklenmektedir:

1. Ekran başına çoğalan servislerin shared runtime altında tekilleştirilmesi.
2. Mouse ve battery polling'in event-driven modele geçirilmesi.
3. 30 Hz SwiftUI timeline işinin görünürlük ve ihtiyaç kadar çalıştırılması.

Bu üç alan düzeltilmeden artwork, settings veya küçük allocation optimizasyonlarına geçilmemelidir.
