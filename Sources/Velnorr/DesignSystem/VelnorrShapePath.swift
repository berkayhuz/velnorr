import CoreGraphics

enum VelnorrShapePath {
  static func make(
    in rect: CGRect,
    topRadius: CGFloat,
    bottomRadius: CGFloat,
    isPill: Bool
  ) -> CGPath {
    if isPill {
      let radius = min(
        min(topRadius, bottomRadius),
        min(rect.width, rect.height) / 2
      )
      return CGPath(
        roundedRect: rect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
      )
    }

    let top = min(topRadius, rect.height / 2)
    let bottom = min(bottomRadius, rect.height / 2)
    let minX = rect.minX
    let minY = rect.minY
    let maxX = rect.maxX
    let maxY = rect.maxY
    let path = CGMutablePath()

    path.move(to: CGPoint(x: minX, y: minY))
    path.addLine(to: CGPoint(x: maxX, y: minY))
    path.addQuadCurve(
      to: CGPoint(x: maxX - top, y: minY + top),
      control: CGPoint(x: maxX - top, y: minY)
    )
    path.addLine(to: CGPoint(x: maxX - top, y: maxY - bottom))
    path.addQuadCurve(
      to: CGPoint(x: maxX - top - bottom, y: maxY),
      control: CGPoint(x: maxX - top, y: maxY)
    )
    path.addLine(to: CGPoint(x: minX + top + bottom, y: maxY))
    path.addQuadCurve(
      to: CGPoint(x: minX + top, y: maxY - bottom),
      control: CGPoint(x: minX + top, y: maxY)
    )
    path.addLine(to: CGPoint(x: minX + top, y: minY + top))
    path.addQuadCurve(
      to: CGPoint(x: minX, y: minY),
      control: CGPoint(x: minX + top, y: minY)
    )
    path.closeSubpath()
    return path
  }
}
