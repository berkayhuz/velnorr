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
  let screenLock: ScreenLockStore
  let calendar: VelnorrCalendarStore
  let shelf: VelnorrShelfStore
  let shelfActions: VelnorrShelfActionService
  let camera: VelnorrCameraStore

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
    screenLock = ScreenLockStore()
    calendar = VelnorrCalendarStore()
    shelf = VelnorrShelfStore()
    shelfActions = VelnorrShelfActionService()
    camera = VelnorrCameraStore()
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
    screenLock.start()
    calendar.start()
    shelf.start()
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
    screenLock.stop()
    calendar.stop()
    shelf.stop()
    shelfActions.stop()
    camera.stop()
  }
}
