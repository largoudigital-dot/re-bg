
import Foundation
import SwiftUI

struct AppFont: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let displayName: String
}

struct TextEditorStyles {
    static let fonts: [AppFont] = [
        AppFont(name: "Inter-Bold", displayName: "Modern"),
        AppFont(name: "Inter-Regular", displayName: "Classic"),
        AppFont(name: "Avenir-Black", displayName: "Bold"),
        AppFont(name: "Georgia", displayName: "Serif"),
        AppFont(name: "SavoyeLetPlain", displayName: "Signature"),
        AppFont(name: "CourierNewPS-BoldMT", displayName: "Typewriter"),
        AppFont(name: "Futura-Bold", displayName: "Geometric"),
        AppFont(name: "SnellRoundhand-Bold", displayName: "Script")
    ]
    
    static let colors: [Color] = [
        .white, .black, .red, .orange, .yellow, .green, 
        .blue, .indigo, .purple, .pink, .gray
    ]
}
