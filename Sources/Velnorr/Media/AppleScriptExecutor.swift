import Foundation
import OSLog

actor AppleScriptExecutor {
  static let shared = AppleScriptExecutor()

  private let logger = Logger(subsystem: "Velnorr", category: "AppleScript")

  func execute(_ source: String, operation: String) -> String? {
    guard !Task.isCancelled else { return nil }
    guard let script = NSAppleScript(source: source) else {
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
