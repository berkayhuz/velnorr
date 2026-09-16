import AppKit
@preconcurrency import AVFoundation
import Combine
import Foundation

/// Owns the camera permission state and capture session used by Mirror.
/// The capture session is started and stopped on its own serial queue because
/// `startRunning()` can block while the device is being configured.
@MainActor
final class VelnorrCameraStore: ObservableObject {
  @Published private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
  @Published private(set) var isAvailable = false
  @Published private(set) var isRunning = false
  @Published private(set) var previewLayer: AVCaptureVideoPreviewLayer?

  private let controller = CameraCaptureController()
  private var startIdentifier: UUID?

  deinit {
    controller.stop()
  }

  func start() {
    refreshAvailability()
    refreshAuthorizationStatus()
    guard authorizationStatus == .authorized else { return }
    let identifier = UUID()
    startIdentifier = identifier
    controller.start { [weak self] layer in
      guard let self, self.startIdentifier == identifier else { return }
      self.previewLayer = layer
      self.isRunning = layer != nil
      self.refreshAvailability()
    }
  }

  func stop() {
    startIdentifier = nil
    controller.stop()
    previewLayer = nil
    isRunning = false
  }

  func requestAccessAndStart() {
    refreshAuthorizationStatus()
    switch authorizationStatus {
    case .authorized:
      start()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        Task { @MainActor [weak self] in
          guard let self else { return }
          self.refreshAuthorizationStatus()
          if granted && self.authorizationStatus != .authorized {
            self.authorizationStatus = .authorized
          }
          if granted { self.start() }
        }
      }
    case .denied, .restricted:
      openPrivacySettings()
    @unknown default:
      break
    }
  }

  func requestAccess() {
    refreshAuthorizationStatus()
    switch authorizationStatus {
    case .authorized:
      return
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        Task { @MainActor [weak self] in
          guard let self else { return }
          self.refreshAuthorizationStatus()
          if granted && self.authorizationStatus != .authorized {
            self.authorizationStatus = .authorized
          }
        }
      }
    case .denied, .restricted:
      openPrivacySettings()
    @unknown default:
      break
    }
  }

  func openPrivacySettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
    else { return }
    NSWorkspace.shared.open(url)
  }

  private func refreshAuthorizationStatus() {
    authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
  }

  private func refreshAvailability() {
    isAvailable = !AVCaptureDevice.DiscoverySession(
      deviceTypes: Self.availableCameraDeviceTypes,
      mediaType: .video,
      position: .unspecified
    ).devices.isEmpty
  }

  private static var availableCameraDeviceTypes: [AVCaptureDevice.DeviceType] {
    if #available(macOS 14.0, *) {
      return [.builtInWideAngleCamera, .external]
    }
    return [.builtInWideAngleCamera]
  }
}

private final class CameraCaptureController: @unchecked Sendable {
  private let queue = DispatchQueue(
    label: "com.berkayhuz.velnorr.camera-session",
    qos: .userInitiated
  )
  private var session: AVCaptureSession?
  private var startRequested = false

  func start(
    onReady: @escaping @Sendable @MainActor (AVCaptureVideoPreviewLayer?) -> Void
  ) {
    queue.async { [weak self] in
      guard let self else { return }
      if let session, session.isRunning {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        DispatchQueue.main.async { onReady(layer) }
        return
      }
      guard !startRequested else { return }
      startRequested = true

      let discovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: Self.availableCameraDeviceTypes,
        mediaType: .video,
        position: .unspecified
      )
      guard let device = discovery.devices.first,
        let input = try? AVCaptureDeviceInput(device: device)
      else {
        startRequested = false
        DispatchQueue.main.async { onReady(nil) }
        return
      }

      let session = AVCaptureSession()
      session.beginConfiguration()
      session.sessionPreset = .high
      guard session.canAddInput(input) else {
        session.commitConfiguration()
        startRequested = false
        DispatchQueue.main.async { onReady(nil) }
        return
      }
      session.addInput(input)
      session.commitConfiguration()
      session.startRunning()
      guard session.isRunning else {
        startRequested = false
        DispatchQueue.main.async { onReady(nil) }
        return
      }
      self.session = session

      let layer = AVCaptureVideoPreviewLayer(session: session)
      layer.videoGravity = .resizeAspectFill
      DispatchQueue.main.async { onReady(layer) }
    }
  }

  func stop() {
    queue.async { [weak self] in
      guard let self else { return }
      self.startRequested = false
      guard let session = self.session else { return }
      if session.isRunning { session.stopRunning() }
      self.session = nil
    }
  }

  private static var availableCameraDeviceTypes: [AVCaptureDevice.DeviceType] {
    if #available(macOS 14.0, *) {
      return [.builtInWideAngleCamera, .external]
    }
    return [.builtInWideAngleCamera]
  }
}
