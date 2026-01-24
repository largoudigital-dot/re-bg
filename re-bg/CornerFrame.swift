
import SwiftUI

struct CornerFrame: View {
    let color: Color = .white
    let length: CGFloat = 20
    let thickness: CGFloat = 3
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Top Left
                path(from: CGPoint(x: 0, y: length), to: .zero, then: CGPoint(x: length, y: 0))
                
                // Top Right
                path(from: CGPoint(x: geometry.size.width - length, y: 0), to: CGPoint(x: geometry.size.width, y: 0), then: CGPoint(x: geometry.size.width, y: length))
                
                // Bottom Left
                path(from: CGPoint(x: 0, y: geometry.size.height - length), to: CGPoint(x: 0, y: geometry.size.height), then: CGPoint(x: length, y: geometry.size.height))
                
                // Bottom Right
                path(from: CGPoint(x: geometry.size.width - length, y: geometry.size.height), to: CGPoint(x: geometry.size.width, y: geometry.size.height), then: CGPoint(x: geometry.size.width, y: geometry.size.height - length))
            }
        }
    }
    
    private func path(from start: CGPoint, to corner: CGPoint, then end: CGPoint) -> some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: corner)
            path.addLine(to: end)
        }
        .stroke(color, lineWidth: thickness)
    }
}
