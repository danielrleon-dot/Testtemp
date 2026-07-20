import SwiftUI

struct TargetFramePreferenceKey: PreferenceKey {
    static var defaultValue: [PileLocation: CGRect] = [:]

    static func reduce(value: inout [PileLocation: CGRect], nextValue: () -> [PileLocation: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Reports this view's frame (in the "board" coordinate space) so drops can be hit-tested against it.
    func reportFrame(_ location: PileLocation) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TargetFramePreferenceKey.self,
                    value: [location: proxy.frame(in: .named("board"))]
                )
            }
        )
    }
}
