import SwiftUI
import UIKit

/// Minimal palette: system off-white background, white cards with a hairline border,
/// black and dark-gray text, one blue accent (AccentColor in the asset catalog).
/// System colors also adapt to Dark Mode.
enum Theme {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let border = Color(uiColor: .separator)
    static let cornerRadius: CGFloat = 14
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                Theme.card,
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 0.5)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardBackground())
    }
}
