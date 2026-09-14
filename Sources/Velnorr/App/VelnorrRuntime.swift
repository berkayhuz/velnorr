import Foundation

@MainActor
final class VelnorrRuntime {
  let artworkService: ArtworkService
  let music: MusicStatusStore
  let audioVolume: AudioVolumeStore
  let screenBrightness: ScreenBrightnessStore
  let capsLock: CapsLockStore
  let batteryCharge: BatteryChargeStore
  let bluetoothConnection: BluetoothConnectionStore

  private var isStarted = false

  init() {
    let artworkService = ArtworkService()
    self.artworkService = artworkService
    music = MusicStatusStore(artworkService: artworkService)
    audioVolume = AudioVolumeStore()
    screenBrightness = ScreenBrightnessStore()
    capsLock = CapsLockStore()
    batteryCharge = BatteryChargeStore()
    bluetoothConnection = BluetoothConnectionStore()
  }

  func start() {
    guard !isStarted else { return }
    isStarted = true

    music.start()
    audioVolume.start()
    screenBrightness.start()
    capsLock.start()
    batteryCharge.start()
    bluetoothConnection.start()
  }

  func stop() {
    guard isStarted else { return }
    isStarted = false

    music.stop()
    audioVolume.stop()
    screenBrightness.stop()
    capsLock.stop()
    batteryCharge.stop()
    bluetoothConnection.stop()
  }
}
