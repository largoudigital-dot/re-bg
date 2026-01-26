
import SwiftUI

struct CropOverlayView: View {
    let onCommit: (CGRect) -> Void
    
    @State private var cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    
    // Minimum crop size (normalized)
    private let minCropSize: CGFloat = 0.1
    
    // To track drag deltas
    @State private var initialRect: CGRect? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
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
                    // Add blend mode to make it visible against all backgrounds? 
                    // White is usually fine.
                
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
                        if initialRect == nil {
                            initialRect = cropRect
                            hapticFeedback()
                        }
                        
                        guard let startRect = initialRect else { return }
                        updateCrop(corner: corner, translation: value.translation, size: size, startRect: startRect)
                    }
                    .onEnded { _ in
                        commit()
                        initialRect = nil
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
        // Reset to full because the image will be updated to the cropped version
        cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        hapticFeedback()
    }
}
