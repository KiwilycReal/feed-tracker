#if canImport(SwiftUI) && (os(iOS) || os(watchOS))
import SwiftUI

enum FeedTrackerPalette {
    static let accent = Color(red: 0.95, green: 0.36, blue: 0.62)
    static let pageBackground = Color(red: 0.98, green: 0.97, blue: 0.99)
    static let cardBackground = Color.white
    static let cardBorder = Color(red: 0.91, green: 0.88, blue: 0.96)
    static let primaryText = Color(red: 0.20, green: 0.16, blue: 0.27)
    static let secondaryText = Color(red: 0.47, green: 0.42, blue: 0.56)
    static let leftSide = Color(red: 0.54, green: 0.67, blue: 0.96)
    static let rightSide = Color(red: 0.98, green: 0.69, blue: 0.42)
    static let success = Color(red: 0.34, green: 0.73, blue: 0.56)
}

extension View {
    func feedTrackerCardStyle() -> some View {
        self
            .padding(16)
            .background(FeedTrackerPalette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FeedTrackerPalette.cardBorder, lineWidth: 1)
            )
    }
}
#endif
