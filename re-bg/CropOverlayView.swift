
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
                // Dimmed background with hole - Only show while dragging
                if isDragging {
                    DimmedBackgroundWithHole(hole: CGRect(
                        x: cropRect.minX * geometry.size.width,
                        y: cropRect.minY * geometry.size.height,
                        width: cropRect.width * geometry.size.width,
                        height: cropRect.height * geometry.size.height
                    ))
                    .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                    .transition(.opacity)
                }
                
                // Border
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
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
        
        return CropHandle(position: mapCorner(corner))
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
    
    private func mapCorner(_ c: Corner) -> CropHandle.Position {
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

struct DimmedBackgroundWithHole: Shape {
    let hole: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRect(hole)
        return path
    }
}
