import AppKit
import CoreGraphics
import Foundation

@MainActor
final class ScreenLockStore: ObservableObject {
  static let screenLockedNotification = Notification.Name("com.apple.screenIsLocked")
  static let screenUnlockedNotification = Notification.Name("com.apple.screenIsUnlocked")

  @Published private(set) var isLocked = false

  private var lockObserver: NSObjectProtocol?
  private var unlockObserver: NSObjectProtocol?
  private var hasStarted = false

  func start() {
    guard !hasStarted else { return }
    hasStarted = true

    let center = DistributedNotificationCenter.default()
    lockObserver = center.addObserver(
      forName: Self.screenLockedNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.setLocked(true)
      }
    }
    unlockObserver = center.addObserver(
      forName: Self.screenUnlockedNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.setLocked(false)
      }
    }

    // Register before the initial read so a lock transition cannot slip
    // between the snapshot and observer installation.
    setLocked(Self.currentSessionIsLocked())
  }

  func stop() {
    guard hasStarted else { return }
    hasStarted = false

    let center = DistributedNotificationCenter.default()
    if let lockObserver {
      center.removeObserver(lockObserver)
    }
    if let unlockObserver {
      center.removeObserver(unlockObserver)
    }
    self.lockObserver = nil
    self.unlockObserver = nil
    isLocked = false
  }

  static func isLocked(in sessionInfo: [String: Any]) -> Bool {
    // The lock flag is not exposed as a public CGSession constant. Keep the
    // private key in one place and fail safe to unlocked when it is absent.
    if let value = sessionInfo["CGSSessionScreenIsLocked"] as? Bool {
      return value
    }
    if let value = sessionInfo["kCGSessionScreenIsLocked"] as? Bool {
      return value
    }
    return false
  }

  private static func currentSessionIsLocked() -> Bool {
    guard let sessionInfo = CGSessionCopyCurrentDictionary() as? [String: Any] else {
      return false
    }
    return isLocked(in: sessionInfo)
  }

  private func setLocked(_ locked: Bool) {
    guard isLocked != locked else { return }
    isLocked = locked
    NotificationCenter.default.post(
      name: .velnorrScreenLockChanged,
      object: nil,
      userInfo: ["isLocked": locked]
    )
  }
}
