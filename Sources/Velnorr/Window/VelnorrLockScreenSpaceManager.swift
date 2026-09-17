import AppKit
import CoreFoundation
import Darwin

/// Owns the private SkyLight Space that hosts Velnorr's lock-screen windows.
/// The adapter is dynamically loaded and safely becomes unavailable when the
/// expected symbols cannot be resolved.
@MainActor
final class VelnorrLockScreenSpaceManager {

  static let lockScreenSpaceLevel: Int32 = 400

  static let skyLightFrameworkPaths: [String] = [
    "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
    "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",
  ]

  // MARK: - SkyLight Types

  private typealias MainConnectionID =
    @convention(c) () -> Int32

  private typealias SetLoginwindowConnection =
    @convention(c) (Int32) -> Int32

  // SkyLight represents Space identifiers as unsigned 64-bit values.
  private typealias SpaceCreate =
    @convention(c) (Int32, Int32, Int32) -> UInt64

  private typealias SpaceDestroy =
    @convention(c) (Int32, UInt64) -> Int32

  private typealias SpaceSetAbsoluteLevel =
    @convention(c) (Int32, UInt64, Int32) -> Int32

  private typealias ShowSpaces =
    @convention(c) (Int32, CFArray) -> Int32

  private typealias HideSpaces =
    @convention(c) (Int32, CFArray) -> Int32

  private typealias AddWindowsToSpaces =
    @convention(c) (
      Int32,
      CFArray,
      CFArray
    ) -> Int32

  private typealias RemoveWindowsFromSpaces =
    @convention(c) (
      Int32,
      CFArray,
      CFArray
    ) -> Int32

  private typealias CopySpacesForWindows =
    @convention(c) (
      Int32,
      Int32,
      CFArray
    ) -> Unmanaged<CFArray>?

  // MARK: - Stored Properties

  private let frameworkHandle: UnsafeMutableRawPointer

  private let connection: Int32
  private let space: UInt64

  private let setLoginwindowConnection: SetLoginwindowConnection
  private let spaceDestroy: SpaceDestroy
  private let hideSpaces: HideSpaces

  private let addWindowsToSpaces: AddWindowsToSpaces
  private let removeWindowsFromSpaces: RemoveWindowsFromSpaces
  private let copySpacesForWindows: CopySpacesForWindows?

  private var isActive = true

  // MARK: - Init

  init?() {
    guard
      let frameworkHandle = Self.skyLightFrameworkPaths.lazy.compactMap({
        dlopen($0, RTLD_NOW)
      }).first
    else {
      return nil
    }

    guard
      let mainConnectionPointer = dlsym(
        frameworkHandle,
        "SLSMainConnectionID"
      ),
      let loginwindowPointer = dlsym(
        frameworkHandle,
        "SLSSetLoginwindowConnection"
      ),
      let spaceCreatePointer = dlsym(
        frameworkHandle,
        "SLSSpaceCreate"
      ),
      let spaceDestroyPointer = dlsym(
        frameworkHandle,
        "SLSSpaceDestroy"
      ),
      let setLevelPointer = dlsym(
        frameworkHandle,
        "SLSSpaceSetAbsoluteLevel"
      ),
      let showSpacesPointer = dlsym(
        frameworkHandle,
        "SLSShowSpaces"
      ),
      let hideSpacesPointer = dlsym(
        frameworkHandle,
        "SLSHideSpaces"
      ),
      let addWindowsPointer = dlsym(
        frameworkHandle,
        "SLSAddWindowsToSpaces"
      ),
      let removeWindowsPointer = dlsym(
        frameworkHandle,
        "SLSRemoveWindowsFromSpaces"
      )
    else {
      dlclose(frameworkHandle)
      return nil
    }

    // MARK: Cast

    let mainConnectionID = unsafeBitCast(
      mainConnectionPointer,
      to: MainConnectionID.self
    )

    let setLoginwindowConnection = unsafeBitCast(
      loginwindowPointer,
      to: SetLoginwindowConnection.self
    )

    let spaceCreate = unsafeBitCast(
      spaceCreatePointer,
      to: SpaceCreate.self
    )

    let spaceDestroy = unsafeBitCast(
      spaceDestroyPointer,
      to: SpaceDestroy.self
    )

    let spaceSetAbsoluteLevel = unsafeBitCast(
      setLevelPointer,
      to: SpaceSetAbsoluteLevel.self
    )

    let showSpaces = unsafeBitCast(
      showSpacesPointer,
      to: ShowSpaces.self
    )

    let hideSpaces = unsafeBitCast(
      hideSpacesPointer,
      to: HideSpaces.self
    )

    let addWindowsToSpaces = unsafeBitCast(
      addWindowsPointer,
      to: AddWindowsToSpaces.self
    )

    let removeWindowsFromSpaces = unsafeBitCast(
      removeWindowsPointer,
      to: RemoveWindowsFromSpaces.self
    )

    // Optional — available on most current systems.
    let copySpacesForWindows: CopySpacesForWindows?

    if let pointer = dlsym(
      frameworkHandle,
      "SLSCopySpacesForWindows"
    ) {
      copySpacesForWindows = unsafeBitCast(
        pointer,
        to: CopySpacesForWindows.self
      )
    } else if let pointer = dlsym(
      frameworkHandle,
      "CGSCopySpacesForWindows"
    ) {
      copySpacesForWindows = unsafeBitCast(
        pointer,
        to: CopySpacesForWindows.self
      )
    } else {
      copySpacesForWindows = nil
    }

    // MARK: Connection

    let connection = mainConnectionID()

    // Must happen before creating the lock-screen Space.
    _ = setLoginwindowConnection(
      connection
    )

    // MARK: Create Space

    let space = spaceCreate(
      connection,
      1,
      0
    )

    guard space != 0 else {
      dlclose(frameworkHandle)
      return nil
    }

    _ = spaceSetAbsoluteLevel(
      connection,
      space,
      Self.lockScreenSpaceLevel
    )

    let spaces =
      [
        NSNumber(value: space)
      ] as CFArray

    _ = showSpaces(
      connection,
      spaces
    )

    // MARK: Store

    self.frameworkHandle = frameworkHandle

    self.connection = connection
    self.space = space

    self.setLoginwindowConnection = setLoginwindowConnection

    self.spaceDestroy = spaceDestroy
    self.hideSpaces = hideSpaces

    self.addWindowsToSpaces = addWindowsToSpaces
    self.removeWindowsFromSpaces = removeWindowsFromSpaces
    self.copySpacesForWindows = copySpacesForWindows
  }

  // MARK: - Move Windows

  func moveToLockScreen(_ windows: [NSWindow]) {
    guard isActive else {
      return
    }

    let windowNumbers =
      windows
      .map(\.windowNumber)
      .filter { $0 > 0 }

    guard !windowNumbers.isEmpty else {
      return
    }

    // Refresh loginwindow association.
    _ = setLoginwindowConnection(
      connection
    )

    let windowsCF =
      windowNumbers.map {
        NSNumber(value: $0)
      } as CFArray

    // Remove window from its current spaces first.
    if let copySpacesForWindows,
      let unmanagedSpaces = copySpacesForWindows(
        connection,
        7,
        windowsCF
      )
    {
      let currentSpaces = unmanagedSpaces.takeRetainedValue()

      if CFArrayGetCount(currentSpaces) > 0 {
        _ = removeWindowsFromSpaces(
          connection,
          windowsCF,
          currentSpaces
        )
      }
    }

    let targetSpaces =
      [
        NSNumber(value: space)
      ] as CFArray

    _ = addWindowsToSpaces(
      connection,
      windowsCF,
      targetSpaces
    )

    // Do not destroy the manager based on undocumented result semantics that
    // vary across macOS releases. AppKit remains the bounded fallback.
  }

  // MARK: - Stop

  func stop() {
    guard isActive else {
      return
    }

    isActive = false

    let spaces =
      [
        NSNumber(value: space)
      ] as CFArray

    _ = hideSpaces(
      connection,
      spaces
    )

    _ = spaceDestroy(
      connection,
      space
    )

    dlclose(frameworkHandle)
  }
}
