
import SwiftUI

struct CropEditorView: View {
    let image: UIImage
    let onApply: (CGRect) -> Void
    let onCancel: () -> Void
    
    @State private var cropRect: CGRect = .zero // Normalized 0-1
    @State private var viewSize: CGSize = .zero
    @State private var imageFrame: CGRect = .zero
    
    // Minimum crop size (normalized)
    private let minCropSize: CGFloat = 0.1
    
    var body: some View {
        ZStack {
            // Dark background for modal experience
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    Button(action: {
                        hapticFeedback()
                        onCancel()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    Text("Zuschneiden")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        hapticFeedback()
                        onApply(cropRect)
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                .padding(.top, 40) // Status bar padding
                
                // Content
                GeometryReader { geometry in
                    ZStack {
                        // 1. The Image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .background(GeometryReader { imgGeo in
                                Color.clear.onAppear {
                                    updateFrame(imgGeo: imgGeo, proxy: geometry)
                                }
                                .onChange(of: imgGeo.size) { _ in
                                    updateFrame(imgGeo: imgGeo, proxy: geometry)
                                }
                            })
                            .padding(20)
                        
                        // 2. The Crop Overlay
                        if imageFrame != .zero {
                            ZStack {
                                // Dimmed outer area
                                Color.black.opacity(0.5)
                                    .mask(
                                        Rectangle()
                                            .overlay(
                                                Rectangle()
                                                    .frame(
                                                        width: cropRect.width * imageFrame.width,
                                                        height: cropRect.height * imageFrame.height
                                                    )
                                                    .position(
                                                        x: imageFrame.minX + (cropRect.minX + cropRect.width/2) * imageFrame.width,
                                                        y: imageFrame.minY + (cropRect.minY + cropRect.height/2) * imageFrame.height
                                                    )
                                                    .blendMode(.destinationOut)
                                            )
                                            .compositingGroup()
                                    )
                                    .allowsHitTesting(false) // Let drags pass through
                                
                                // Crop Frame Border
                                Rectangle()
                                    .stroke(Color.white, lineWidth: 1)
                                    .frame(
                                        width: cropRect.width * imageFrame.width,
                                        height: cropRect.height * imageFrame.height
                                    )
                                    .position(
                                        x: imageFrame.minX + (cropRect.minX + cropRect.width/2) * imageFrame.width,
                                        y: imageFrame.minY + (cropRect.minY + cropRect.height/2) * imageFrame.height
                                    )
                                
                                // 3. Handles
                                Group {
                                    // Top Left
                                    CropHandle(position: .topLeft)
                                        .gesture(dragGesture(corner: .topLeft))
                                        .position(
                                            x: imageFrame.minX + cropRect.minX * imageFrame.width,
                                            y: imageFrame.minY + cropRect.minY * imageFrame.height
                                        )
                                    
                                    // Top Right
                                    CropHandle(position: .topRight)
                                        .gesture(dragGesture(corner: .topRight))
                                        .position(
                                            x: imageFrame.minX + (cropRect.minX + cropRect.width) * imageFrame.width,
                                            y: imageFrame.minY + cropRect.minY * imageFrame.height
                                        )
                                    
                                    // Bottom Left
                                    CropHandle(position: .bottomLeft)
                                        .gesture(dragGesture(corner: .bottomLeft))
                                        .position(
                                            x: imageFrame.minX + cropRect.minX * imageFrame.width,
                                            y: imageFrame.minY + (cropRect.minY + cropRect.height) * imageFrame.height
                                        )
                                    
                                    // Bottom Right
                                    CropHandle(position: .bottomRight)
                                        .gesture(dragGesture(corner: .bottomRight))
                                        .position(
                                            x: imageFrame.minX + (cropRect.minX + cropRect.width) * imageFrame.width,
                                            y: imageFrame.minY + (cropRect.minY + cropRect.height) * imageFrame.height
                                        )
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            // Start with full crop
            cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
    }
    
    private func updateFrame(imgGeo: GeometryProxy, proxy: GeometryProxy) {
        let frame = imgGeo.frame(in: .local)
        // Convert to global space roughly or parent space
        // Better: get frame in named coordinate space
        
        // Simple approach: The ZStack centers everything. 
        // We know the image is aspect fit in the geometry.
        
        let containerSize = proxy.size
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        var renderWidth: CGFloat
        var renderHeight: CGFloat
        
        // Account for padding (20 on each side -> 40 total)
        let paddedContainerWidth = containerSize.width - 40
        let paddedContainerHeight = containerSize.height - 40
        
        if imageAspect > containerAspect {
            // Width constrained
            renderWidth = paddedContainerWidth
            renderHeight = paddedContainerWidth / imageAspect
        } else {
            // Height constrained
            renderHeight = paddedContainerHeight
            renderWidth = paddedContainerHeight * imageAspect
        }
        
        let x = (containerSize.width - renderWidth) / 2
        let y = (containerSize.height - renderHeight) / 2
        
        imageFrame = CGRect(x: x, y: y, width: renderWidth, height: renderHeight)
    }
    
    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    private func dragGesture(corner: Corner) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = value.translation
                let xChange = translation.width / imageFrame.width
                let yChange = translation.height / imageFrame.height
                
                var newRect = cropRect
                
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
                // Check min dimensions
                if newRect.width < minCropSize {
                    if corner == .topLeft || corner == .bottomLeft {
                        newRect.origin.x = cropRect.maxX - minCropSize
                    }
                    newRect.size.width = minCropSize
                }
                
                if newRect.height < minCropSize {
                    if corner == .topLeft || corner == .topRight {
                        newRect.origin.y = cropRect.maxY - minCropSize
                    }
                    newRect.size.height = minCropSize
                }
                
                // Check bounds 0-1
                newRect.origin.x = max(0, min(newRect.origin.x, 1 - newRect.width))
                newRect.origin.y = max(0, min(newRect.origin.y, 1 - newRect.height))
                newRect.size.width = min(newRect.width, 1 - newRect.origin.x)
                newRect.size.height = min(newRect.height, 1 - newRect.origin.y)
                
                self.cropRect = newRect
            }
    }
}

struct CropHandle: View {
    enum Position {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    let position: Position
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 24, height: 24)
            .shadow(color: Color.black.opacity(0.3), radius: 2)
            .overlay(
                // Corner Icon
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
            )
    }
    
    var iconName: String {
        switch position {
        case .topLeft: return "arrow.up.left.and.arrow.down.right" // Best approx
        case .topRight: return "arrow.up.right.and.arrow.down.left" // Inverted
        case .bottomLeft: return "arrow.up.right.and.arrow.down.left"
        case .bottomRight: return "arrow.up.left.and.arrow.down.right" // Inverted
        }
    }
}
