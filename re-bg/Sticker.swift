
import Foundation
import SwiftUI

struct Sticker: Identifiable, Equatable {
    let id: UUID
    let content: String // Emoji string
    var position: CGPoint
    var scale: CGFloat
    var rotation: Angle
    
    init(id: UUID = UUID(), content: String, position: CGPoint = CGPoint(x: 0.5, y: 0.5), scale: CGFloat = 1.0, rotation: Angle = .zero) {
        self.id = id
        self.content = content
        self.position = position
        self.scale = scale
        self.rotation = rotation
    }
}
