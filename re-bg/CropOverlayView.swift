
import SwiftUI

struct CropOverlayView: View {
    let initialRect: CGRect
    let onCommit: (CGRect) -> Void
    
    @State private var cropRect: CGRect
    
    init(initialRect: CGRect, onCommit: @escaping (CGRect) -> Void) {
        self.initialRect = initialRect
        self.onCommit = onCommit
        self._cropRect = State(initialValue: initialRect)
    }
    
    // Minimum crop size (normalized)
    private let minCropSize: CGFloat = 0.1
    
    // To track if user is interacting
    @State private var isDragging: Bool = false
    
    // To track drag deltas
    @State private var dragStartRect: CGRect? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background with hole - ALWAYS visible when in crop mode
                DimmedBackgroundWithHole(hole: CGRect(
                    x: cropRect.minX * geometry.size.width,
                    y: cropRect.minY * geometry.size.height,
                    width: cropRect.width * geometry.size.width,
                    height: cropRect.height * geometry.size.height
                ))
                .fill(Color.black.opacity(0.4), style: FillStyle(eoFill: true))
                
                // Rule of Thirds Grid - Only show while dragging for guidance
                if isDragging {
                    GridView(rect: cropRect, geometry: geometry)
                        .transition(.opacity)
                }
                
                // Border
                Rectangle()
                    .stroke(Color.white, lineWidth: 2.5) // Slightly thicker for better visibility
                    .frame(
                        width: cropRect.width * geometry.size.width,
                        height: cropRect.height * geometry.size.height
                    )
                    .position(
                        x: (cropRect.minX + cropRect.width/2) * geometry.size.width,
                        y: (cropRect.minY + cropRect.height/2) * geometry.size.height
                    )
                
                // Handles
                handle(corner: .topLeft, geometry: geometry)
                handle(corner: .topRight, geometry: geometry)
                handle(corner: .bottomLeft, geometry: geometry)
                handle(corner: .bottomRight, geometry: geometry)
            }
        }
    }
    
    private func handle(corner: Corner, geometry: GeometryProxy) -> some View {
        let size = geometry.size
        
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        switch corner {
        case .topLeft:
            x = cropRect.minX * size.width
            y = cropRect.minY * size.height
        case .topRight:
            x = (cropRect.minX + cropRect.width) * size.width
            y = cropRect.minY * size.height
        case .bottomLeft:
            x = cropRect.minX * size.width
            y = (cropRect.minY + cropRect.height) * size.height
        case .bottomRight:
            x = (cropRect.minX + cropRect.width) * size.width
            y = (cropRect.minY + cropRect.height) * size.height
        }
        
        return EnhancedCropHandle(position: mapCorner(corner))
            .position(x: x, y: y)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartRect == nil {
                            dragStartRect = cropRect
                            hapticFeedback()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDragging = true
                            }
                        }
                        
                        guard let startRect = dragStartRect else { return }
                        updateCrop(corner: corner, translation: value.translation, size: size, startRect: startRect)
                    }
                    .onEnded { _ in
                        commit()
                        dragStartRect = nil
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDragging = false
                        }
                    }
            )
    }
    
    private enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    private func mapCorner(_ c: Corner) -> EnhancedCropHandle.Position {
        switch c {
        case .topLeft: return .topLeft
        case .topRight: return .topRight
        case .bottomLeft: return .bottomLeft
        case .bottomRight: return .bottomRight
        }
    }
    
    private func updateCrop(corner: Corner, translation: CGSize, size: CGSize, startRect: CGRect) {
        let xChange = translation.width / size.width
        let yChange = translation.height / size.height
        
        var newRect = startRect
        
        switch corner {
        case .topLeft:
            newRect.origin.x += xChange
            newRect.origin.y += yChange
            newRect.size.width -= xChange
            newRect.size.height -= yChange
        case .topRight:
            newRect.size.width += xChange
            newRect.origin.y += yChange
            newRect.size.height -= yChange
        case .bottomLeft:
            newRect.origin.x += xChange
            newRect.size.width -= xChange
            newRect.size.height += yChange
        case .bottomRight:
            newRect.size.width += xChange
            newRect.size.height += yChange
        }
        
        // Normalize and constrain
        if newRect.width < minCropSize {
            if corner == .topLeft || corner == .bottomLeft {
                newRect.origin.x = startRect.maxX - minCropSize
            }
            newRect.size.width = minCropSize
        }
        
        if newRect.height < minCropSize {
            if corner == .topLeft || corner == .topRight {
                newRect.origin.y = startRect.maxY - minCropSize
            }
            newRect.size.height = minCropSize
        }
        
        // Bounds 0-1
        newRect.origin.x = max(0, min(newRect.origin.x, 1 - newRect.width))
        newRect.origin.y = max(0, min(newRect.origin.y, 1 - newRect.height))
        newRect.size.width = min(newRect.width, 1 - newRect.origin.x)
        newRect.size.height = min(newRect.height, 1 - newRect.origin.y)
        
        self.cropRect = newRect
    }
    
    private func commit() {
        onCommit(cropRect)
        hapticFeedback()
    }
}

struct EnhancedCropHandle: View {
    enum Position {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    let position: Position
    
    var body: some View {
        ZStack {
            // Larger outer circle for better hit target visibility
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
                .shadow(color: Color.black.opacity(0.3), radius: 3)
            
            // Inner icon
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
        }
    }
    
    var iconName: String {
        switch position {
        case .topLeft: return "arrow.up.left.and.arrow.down.right"
        case .topRight: return "arrow.up.right.and.arrow.down.left"
        case .bottomLeft: return "arrow.up.right.and.arrow.down.left"
        case .bottomRight: return "arrow.up.left.and.arrow.down.right"
        }
    }
}

struct DimmedBackgroundWithHole: Shape {
    let hole: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRect(hole)
        return path
    }
}

struct GridView: View {
    let rect: CGRect
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Horizontal lines
            Path { path in
                let x = rect.minX * geometry.size.width
                let width = rect.width * geometry.size.width
                let y1 = (rect.minY + rect.height / 3) * geometry.size.height
                let y2 = (rect.minY + 2 * rect.height / 3) * geometry.size.height
                
                path.move(to: CGPoint(x: x, y: y1))
                path.addLine(to: CGPoint(x: x + width, y: y1))
                
                path.move(to: CGPoint(x: x, y: y2))
                path.addLine(to: CGPoint(x: x + width, y: y2))
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 1)
            
            // Vertical lines
            Path { path in
                let y = rect.minY * geometry.size.height
                let height = rect.height * geometry.size.height
                let x1 = (rect.minX + rect.width / 3) * geometry.size.width
                let x2 = (rect.minX + 2 * rect.width / 3) * geometry.size.width
                
                path.move(to: CGPoint(x: x1, y: y))
                path.addLine(to: CGPoint(x: x1, y: y + height))
                
                path.move(to: CGPoint(x: x2, y: y))
                path.addLine(to: CGPoint(x: x2, y: y + height))
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
    }
}
