
import Foundation
import SwiftUI

enum TextAlignment: String, CaseIterable, Identifiable {
    case left, center, right
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .right: return "text.alignright"
        }
    }
}

enum TextBackgroundStyle: String, CaseIterable, Identifiable {
    case none, solid, semiTransparent
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .none: return "textformat"
        case .solid: return "a.square.fill"
        case .semiTransparent: return "a.square"
        }
    }
}

struct TextItem: Identifiable, Equatable {
    let id: UUID
    var text: String
    var fontName: String
    var color: Color
    var backgroundColor: Color
    var backgroundStyle: TextBackgroundStyle
    var alignment: TextAlignment
    var position: CGPoint // Normalized 0-1
    var scale: CGFloat
    var rotation: Angle
    
    init(
        id: UUID = UUID(),
        text: String = "",
        fontName: String = "Inter-Bold",
        color: Color = .white,
        backgroundColor: Color = .black,
        backgroundStyle: TextBackgroundStyle = .none,
        alignment: TextAlignment = .center,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        scale: CGFloat = 1.0,
        rotation: Angle = .zero
    ) {
        self.id = id
        self.text = text
        self.fontName = fontName
        self.color = color
        self.backgroundColor = backgroundColor
        self.backgroundStyle = backgroundStyle
        self.alignment = alignment
        self.position = position
        self.scale = scale
        self.rotation = rotation
    }
}
