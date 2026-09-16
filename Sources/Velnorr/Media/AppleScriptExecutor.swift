import Foundation
import OSLog

final class AppleScriptExecutor: @unchecked Sendable {
  static let shared = AppleScriptExecutor()
  private static let timeoutSeconds = 5

  private let logger = Logger(subsystem: "Velnorr", category: "AppleScript")

  @MainActor
  func execute(_ source: String, operation: String) -> String? {
    let signpost = VelnorrPerformance.begin(.appleScriptExecute)
    defer { VelnorrPerformance.end(.appleScriptExecute, signpost) }

    guard !Task.isCancelled else { return nil }
    // NSAppleScript is documented as main-thread-only. Keep the API call on
    // MainActor and bound Apple Event execution so one unresponsive player
    // cannot stall the serialized refresh chain indefinitely.
    let boundedSource = """
      with timeout of \(Self.timeoutSeconds) seconds
      \(source)
      end timeout
      """
    guard let script = NSAppleScript(source: boundedSource) else {
      logger.error("Could not create AppleScript for \(operation, privacy: .public)")
      return nil
    }

    var error: NSDictionary?
    let result = script.executeAndReturnError(&error)
    if let error {
      logger.error(
        "AppleScript \(operation, privacy: .public) failed: \(String(describing: error), privacy: .private)"
      )
      return nil
    }
    return result.stringValue
  }
}
