import AppKit
import CoreFoundation
import Darwin

/// Moves lock-screen windows into the system Space used for lock-screen
/// widgets. SkyLight is private, so this adapter is dynamically loaded and
/// fails closed when the expected symbols are unavailable.
@MainActor
final class VelnorrLockScreenSpaceManager {
  static let lockScreenSpaceLevel: Int32 = 400
  static let skyLightFrameworkPaths: [String] = [
    "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
    "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",
  ]

  private typealias MainConnectionID = @convention(c) () -> Int32
  private typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
  private typealias SpaceDestroy = @convention(c) (Int32, Int32) -> Int32
  private typealias SpaceSetAbsoluteLevel = @convention(c) (Int32, Int32, Int32) -> Int32
  private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
  private typealias HideSpaces = @convention(c) (Int32, CFArray) -> Int32
  private typealias AddWindowAndRemoveFromSpaces = @convention(c) (
    Int32, Int32, CFArray, Int32
  ) -> Int32

  private let frameworkHandle: UnsafeMutableRawPointer
  private let connection: Int32
  private let space: Int32
  private let spaceDestroy: SpaceDestroy
  private let hideSpaces: HideSpaces
  private let addWindowAndRemoveFromSpaces: AddWindowAndRemoveFromSpaces
  private var isActive = true

  init?() {
    guard let frameworkHandle = Self.skyLightFrameworkPaths.lazy.compactMap({ path in
      dlopen(path, RTLD_NOW)
    }).first else { return nil }

    guard let mainConnectionPointer = dlsym(frameworkHandle, "SLSMainConnectionID"),
      let spaceCreatePointer = dlsym(frameworkHandle, "SLSSpaceCreate"),
      let spaceDestroyPointer = dlsym(frameworkHandle, "SLSSpaceDestroy"),
      let spaceSetAbsoluteLevelPointer = dlsym(frameworkHandle, "SLSSpaceSetAbsoluteLevel"),
      let showSpacesPointer = dlsym(frameworkHandle, "SLSShowSpaces"),
      let hideSpacesPointer = dlsym(frameworkHandle, "SLSHideSpaces"),
      let addWindowPointer = dlsym(
        frameworkHandle,
        "SLSSpaceAddWindowsAndRemoveFromSpaces"
      )
    else {
      dlclose(frameworkHandle)
      return nil
    }

    // SkyLight is a private C ABI; each symbol is cast only to its known
    // function signature from the dynamically loaded framework.
    let mainConnectionID = unsafeBitCast(
      mainConnectionPointer,
      to: MainConnectionID.self
    )
    let spaceCreate = unsafeBitCast(spaceCreatePointer, to: SpaceCreate.self)
    let spaceDestroy = unsafeBitCast(spaceDestroyPointer, to: SpaceDestroy.self)
    let spaceSetAbsoluteLevel = unsafeBitCast(
      spaceSetAbsoluteLevelPointer,
      to: SpaceSetAbsoluteLevel.self
    )
    let showSpaces = unsafeBitCast(showSpacesPointer, to: ShowSpaces.self)
    let hideSpaces = unsafeBitCast(hideSpacesPointer, to: HideSpaces.self)
    let addWindowAndRemoveFromSpaces = unsafeBitCast(
      addWindowPointer,
      to: AddWindowAndRemoveFromSpaces.self
    )

    let connection = mainConnectionID()
    let space = spaceCreate(connection, 1, 0)
    guard space != 0 else {
      dlclose(frameworkHandle)
      return nil
    }

    let spaces = [space] as CFArray
    let setLevelResult = spaceSetAbsoluteLevel(
      connection,
      space,
      Self.lockScreenSpaceLevel
    )
    let showResult = showSpaces(connection, spaces)
    guard setLevelResult == 0, showResult == 0 else {
      _ = hideSpaces(connection, spaces)
      _ = spaceDestroy(connection, space)
      dlclose(frameworkHandle)
      return nil
    }

    self.frameworkHandle = frameworkHandle
    self.connection = connection
    self.space = space
    self.spaceDestroy = spaceDestroy
    self.hideSpaces = hideSpaces
    self.addWindowAndRemoveFromSpaces = addWindowAndRemoveFromSpaces
  }

  func moveToLockScreen(_ window: NSWindow) {
    guard isActive, window.windowNumber > 0 else { return }
    _ = addWindowAndRemoveFromSpaces(
      connection,
      space,
      [window.windowNumber] as CFArray,
      7
    )
  }

  // AppDelegate owns this manager and calls stop before releasing it on
  // unlock and application termination. Keeping teardown explicit avoids
  // invoking MainActor-isolated SkyLight calls from a nonisolated deinit.
  func stop() {
    guard isActive else { return }
    isActive = false

    let spaces = [space] as CFArray
    _ = hideSpaces(connection, spaces)
    _ = spaceDestroy(connection, space)
    dlclose(frameworkHandle)
  }
}
