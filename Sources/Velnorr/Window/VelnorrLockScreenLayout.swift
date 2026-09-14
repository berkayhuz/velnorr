import CoreGraphics

enum VelnorrLockScreenLayout {
  static let widgetSize = CGSize(width: 360, height: 170)
  static let profilePhotoGap: CGFloat = 36

  // loginwindow does not expose the avatar frame to third-party apps. This
  // ratio follows the standard macOS lock-screen layout and keeps the card
  // anchored to the avatar instead of drifting with the available frame.
  static let profilePhotoTopRatioFromBottom: CGFloat = 0.176

  static func profilePhotoTop(in screenFrame: CGRect) -> CGFloat {
    screenFrame.minY + screenFrame.height * profilePhotoTopRatioFromBottom
  }

  static func widgetFrame(for screenFrame: CGRect) -> CGRect {
    let profilePhotoTop = profilePhotoTop(in: screenFrame)
    return CGRect(
      x: screenFrame.midX - widgetSize.width / 2,
      y: profilePhotoTop + profilePhotoGap,
      width: widgetSize.width,
      height: widgetSize.height
    )
  }
}
