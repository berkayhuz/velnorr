import SwiftUI

struct OutwardTopVelnorrShape: Shape {
  var topRadius: CGFloat
  var bottomRadius: CGFloat
  var isPill = false

  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(topRadius, bottomRadius) }
    set {
      topRadius = newValue.first
      bottomRadius = newValue.second
    }
  }

  func path(in rect: CGRect) -> Path {
    Path(
      VelnorrShapePath.make(
        in: rect,
        topRadius: topRadius,
        bottomRadius: bottomRadius,
        isPill: isPill
      )
    )
  }
}
