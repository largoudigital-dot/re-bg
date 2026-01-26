import SwiftUI

enum SelectedLayer {
    case foreground
    case background
    case canvas
}

struct ZoomableImageView: View {
    let foreground: UIImage?
    let background: UIImage?
    let original: UIImage?
    let backgroundColor: Color?
    let gradientColors: [Color]?
    let activeLayer: SelectedLayer
    let rotation: CGFloat
    let isCropping: Bool
    let onCropCommit: ((CGRect) -> Void)?
    @Binding var stickers: [Sticker]
    @Binding var selectedStickerId: UUID?
    
    init(foreground: UIImage?, background: UIImage?, original: UIImage?, backgroundColor: Color?, gradientColors: [Color]?, activeLayer: SelectedLayer, rotation: CGFloat, isCropping: Bool = false, onCropCommit: ((CGRect) -> Void)? = nil, stickers: Binding<[Sticker]>, selectedStickerId: Binding<UUID?>) {
        self.foreground = foreground
        self.background = background
        self.original = original
        self.backgroundColor = backgroundColor
        self.gradientColors = gradientColors
        self.activeLayer = activeLayer
        self.rotation = rotation
        self.isCropping = isCropping
        self.onCropCommit = onCropCommit
        self._stickers = stickers
        self._selectedStickerId = selectedStickerId
    }
    
    // Foreground State
    @State private var fgScale: CGFloat = 1.0
    @State private var fgLastScale: CGFloat = 1.0
    @State private var fgOffset: CGSize = .zero
    @State private var fgLastOffset: CGSize = .zero
    
    // Background State
    @State private var bgScale: CGFloat = 1.0
    @State private var bgLastScale: CGFloat = 1.0
    @State private var bgOffset: CGSize = .zero
    @State private var bgLastOffset: CGSize = .zero
    
    // Canvas State (Affects both)
    @State private var canvasScale: CGFloat = 1.0
    @State private var canvasLastScale: CGFloat = 1.0
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasLastOffset: CGSize = .zero
    
    @State private var showVGuide = false
    @State private var showHGuide = false
    @State private var interactingLayer: SelectedLayer? = nil
    
    private let snapThreshold: CGFloat = 10
    
                // --- BACKGROUND DESELECTION LAYER ---
                // This layer captures taps outside the stickers to deselect them
                // without letting the tap reach the image layers.
                if selectedStickerId != nil {
                    Color.black.opacity(0.001)
                        .onTapGesture {
                            print("DEBUG: Deselection area touched")
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedStickerId = nil
                            }
                        }
                        .zIndex(500)
                }
                
                // --- PHOTO CONTENT CONTAINER ---
                ZStack {
                    // 1. Background Layer (Bottom)
                    Group {
                        if let bgImage = background {
                            Image(uiImage: bgImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.blue, lineWidth: (interactingLayer == .background || (interactingLayer == .canvas && activeLayer == .canvas)) ? 3 : 0)
                                )
                                .scaleEffect(bgScale)
                                .offset(bgOffset)
                        } else if let colors = gradientColors {
                            LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.blue, lineWidth: (interactingLayer == .background || (interactingLayer == .canvas && activeLayer == .canvas)) ? 3 : 0)
                                )
                                .scaleEffect(bgScale)
                                .offset(bgOffset)
                        } else if let color = backgroundColor {
                            color
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.blue, lineWidth: (interactingLayer == .background || (interactingLayer == .canvas && activeLayer == .canvas)) ? 3 : 0)
                                )
                                .scaleEffect(bgScale)
                                .offset(bgOffset)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .gesture(layerGesture(for: .background))
                    
                    // 2. Foreground Layer (Middle)
                    if let displayImage = (foreground ?? original) {
                        ZStack {
                            Image(uiImage: displayImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            
                            if isCropping, let commit = onCropCommit {
                                CropOverlayView(onCommit: commit)
                            }
                        }
                        .overlay(
                            Rectangle()
                                .stroke(Color.blue, lineWidth: (interactingLayer == .foreground || (interactingLayer == .canvas && activeLayer == .canvas)) ? 3 : 0)
                        )
                        .scaleEffect(fgScale)
                        .offset(fgOffset)
                        .gesture(layerGesture(for: .foreground))
                    }
                }
                .rotationEffect(.degrees(rotation))
                .scaleEffect(canvasScale)
                .offset(canvasOffset)
                // Disable hit-testing for the photo when a sticker is selected
                // This prevents photo gestures from firing.
                .allowsHitTesting(selectedStickerId == nil)
                .zIndex(1)
                // --- END CANVAS CONTAINER ---
                
                // --- STICKER OVERLAY LAYER ---
                ZStack {
                    ForEach($stickers) { $sticker in
                        StickerView(
                            sticker: $sticker,
                            containerSize: geometry.size,
                            isSelected: selectedStickerId == sticker.id,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedStickerId = sticker.id
                                }
                            },
                            parentTransform: getCurrentPhotoTransform(geometry: geometry)
                        )
                    }
                }
                .zIndex(1000) // Ensure stickers are always on top (Z-index high)
                .allowsHitTesting(!isCropping)
                
                // 3. Guidelines (Top)
                if showVGuide || showHGuide {
                    ZStack {
                        if showVGuide {
                            Rectangle()
                                .fill(Color.blue.opacity(0.8))
                                .frame(width: 1.5)
                                .shadow(color: .blue.opacity(0.5), radius: 5)
                        }
                        
                        if showHGuide {
                            Rectangle()
                                .fill(Color.blue.opacity(0.8))
                                .frame(height: 1.5)
                                .shadow(color: .blue.opacity(0.5), radius: 5)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
    }
    
    // MARK: - Gesture Logic
    
    private func layerGesture(for layer: SelectedLayer) -> some Gesture {
        // If the Canvas tab is active, we force interactions to be Canvas-level 
        // unless the user specifically has a need for individual layers.
        // But the user said "leinwand soll an hintergrand und vordergrand zusammen betreffen",
        // so when activeLayer is .canvas, we should probably prefer canvas gestures.
        
        let targetLayer = (activeLayer == .canvas) ? .canvas : layer
        
        let drag = DragGesture(minimumDistance: 0)
            .onChanged { value in
                if interactingLayer == nil {
                    print("DEBUG: Photo Drag Start on \(targetLayer)")
                    interactingLayer = targetLayer
                    hapticFeedback()
                    
                    // Deselect stickers when starting to interact with any image layer
                    if selectedStickerId != nil {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedStickerId = nil
                        }
                    }
                }
                updatePosition(for: targetLayer, translation: value.translation)
            }
            .onEnded { _ in
                print("DEBUG: Photo Drag End on \(targetLayer)")
                finalizeOffset(for: targetLayer)
                interactingLayer = nil
                withAnimation(.easeOut(duration: 0.2)) {
                    showVGuide = false
                    showHGuide = false
                }
            }
            
        let zoom = MagnificationGesture()
            .onChanged { value in
                // If a sticker is selected, we do NOT allow zooming the background
                if selectedStickerId != nil { 
                    print("DEBUG: Photo Zoom BLOCKED (sticker selected)")
                    return 
                }
                
                if interactingLayer == nil {
                    print("DEBUG: Photo Zoom Start on \(targetLayer)")
                    interactingLayer = targetLayer
                    hapticFeedback()
                }
                updateScale(for: targetLayer, value: value)
            }
            .onEnded { _ in
                if selectedStickerId != nil { return }
                
                print("DEBUG: Photo Zoom End on \(targetLayer)")
                finalizeScale(for: targetLayer)
                interactingLayer = nil
            }
            
        let doubleTap = TapGesture(count: 2)
            .onEnded {
                resetTransform(for: targetLayer)
            }
            
        return drag.simultaneously(with: zoom).simultaneously(with: doubleTap)
    }
    
    private func updatePosition(for layer: SelectedLayer, translation: CGSize) {
        let newX: CGFloat
        let newY: CGFloat
        
        switch layer {
        case .foreground:
            newX = fgLastOffset.width + translation.width
            newY = fgLastOffset.height + translation.height
        case .background:
            newX = bgLastOffset.width + translation.width
            newY = bgLastOffset.height + translation.height
        case .canvas:
            newX = canvasLastOffset.width + translation.width
            newY = canvasLastOffset.height + translation.height
        }
        
        var finalX = newX
        var finalY = newY
        
        if abs(newX) < snapThreshold {
            if !showVGuide { hapticFeedback() }
            finalX = 0
            showVGuide = true
        } else {
            showVGuide = false
        }
        
        if abs(newY) < snapThreshold {
            if !showHGuide { hapticFeedback() }
            finalY = 0
            showHGuide = true
        } else {
            showHGuide = false
        }
        
        switch layer {
        case .foreground:
            fgOffset = CGSize(width: finalX, height: finalY)
        case .background:
            bgOffset = CGSize(width: finalX, height: finalY)
        case .canvas:
            canvasOffset = CGSize(width: finalX, height: finalY)
        }
    }
    
    private func finalizeOffset(for layer: SelectedLayer) {
        switch layer {
        case .foreground: fgLastOffset = fgOffset
        case .background: bgLastOffset = bgOffset
        case .canvas: canvasLastOffset = canvasOffset
        }
    }
    
    private func updateScale(for layer: SelectedLayer, value: CGFloat) {
        switch layer {
        case .foreground: fgScale = fgLastScale * value
        case .background: bgScale = bgLastScale * value
        case .canvas: canvasScale = canvasLastScale * value
        }
    }
    
    private func finalizeScale(for layer: SelectedLayer) {
        switch layer {
        case .foreground: fgLastScale = fgScale
        case .background: bgLastScale = bgScale
        case .canvas: canvasLastScale = canvasScale
        }
    }
    
    private func resetTransform(for layer: SelectedLayer) {
        withAnimation(.spring()) {
            switch layer {
            case .foreground:
                fgScale = 1.0; fgLastScale = 1.0; fgOffset = .zero; fgLastOffset = .zero
            case .background:
                bgScale = 1.0; bgLastScale = 1.0; bgOffset = .zero; bgLastOffset = .zero
            case .canvas:
                canvasScale = 1.0; canvasLastScale = 1.0; canvasOffset = .zero; canvasLastOffset = .zero
            }
            showVGuide = false
            showHGuide = false
        }
        hapticFeedback()
    }
    
    // Helper to calculate the current transformation state of the photo content
    private func getCurrentPhotoTransform(geometry: GeometryProxy) -> PhotoTransform {
        // Combined transformation: Rotation -> Canvas Scale/Offset -> FG Scale/Offset
        // For positions, we need to know how a normalized (0-1) point in the PHOTO 
        // maps to the SCREEN.
        
        return PhotoTransform(
            canvasOffset: canvasOffset,
            canvasScale: canvasScale,
            fgOffset: fgOffset,
            fgScale: fgScale,
            rotation: rotation
        )
    }
}

struct PhotoTransform: Equatable {
    let canvasOffset: CGSize
    let canvasScale: CGFloat
    let fgOffset: CGSize
    let fgScale: CGFloat
    let rotation: CGFloat
}

struct StickerView: View {
    @Binding var sticker: Sticker
    let containerSize: CGSize
    let isSelected: Bool
    let onSelect: () -> Void
    let parentTransform: PhotoTransform
    
    @State private var dragOffset: CGSize = .zero
    @State private var currentScale: CGFloat = 1.0
    @State private var currentRotation: Angle = .zero
    
    // Calculate the actual screen position based on photo transformation
    private var screenPosition: CGPoint {
        // 1. Center of the container
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2
        
        // 2. Relative position of the sticker on the photo (0...1) converted to -0.5...0.5
        let rx = sticker.position.x - 0.5
        let ry = sticker.position.y - 0.5
        
        // 3. Apply scales (photo's own scale and canvas scale)
        let totalScale = parentTransform.canvasScale * parentTransform.fgScale
        let sx = rx * containerSize.width * totalScale
        let sy = ry * containerSize.height * totalScale
        
        // 4. Apply rotation (if the parent content is rotated)
        let angle = parentTransform.rotation * .pi / 180
        let cosA = cos(angle)
        let sinA = sin(angle)
        
        let rotatedX = sx * cosA - sy * sinA
        let rotatedY = sx * sinA + sy * cosA
        
        // 5. Apply offsets (fgOffset and canvasOffset)
        // We need to account for the fact that offsets are scaled by the canvasScale? 
        // Actually, ZoomableImageView applies offset(canvasOffset).scaleEffect(canvasScale).
        // So canvasOffset is in unscaled points.
        
        let tx = centerX + rotatedX + parentTransform.fgOffset.width * parentTransform.canvasScale + parentTransform.canvasOffset.width + dragOffset.width
        let ty = centerY + rotatedY + parentTransform.fgOffset.height * parentTransform.canvasScale + parentTransform.canvasOffset.height + dragOffset.height
        
        return CGPoint(x: tx, y: ty)
    }
    
    var body: some View {
        ZStack {
            // Selection Handles (only visible when selected)
            if isSelected {
                selectionHandles
            }
            
            Text(sticker.content)
                .font(.system(size: 60))
                .padding(15)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.white : Color.clear, style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
                        .shadow(color: .black.opacity(0.3), radius: 2)
                )
        }
        .scaleEffect(sticker.scale * currentScale)
        .rotationEffect(sticker.rotation + currentRotation)
        .position(screenPosition)
        .highPriorityGesture(
            DragGesture()
                .onChanged { value in
                    if dragOffset == .zero {
                        print("DEBUG: Sticker Drag Start (\(sticker.content))")
                        onSelect()
                        hapticFeedback()
                    }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    print("DEBUG: Sticker Drag End (\(sticker.content))")
                    // Convert screen-space translation back to normalized photo coordinates
                    let totalScale = parentTransform.canvasScale * parentTransform.fgScale
                    let angle = -parentTransform.rotation * .pi / 180
                    
                    let dx = value.translation.width / (containerSize.width * totalScale)
                    let dy = value.translation.height / (containerSize.height * totalScale)
                    
                    let rotatedDX = dx * cos(angle) - dy * sin(angle)
                    let rotatedDY = dx * sin(angle) + dy * cos(angle)
                    
                    sticker.position.x += rotatedDX
                    sticker.position.y += rotatedDY
                    dragOffset = .zero
                }
        )
        .highPriorityGesture(
            isSelected ? MagnificationGesture()
                .onChanged { value in
                    if currentScale == 1.0 { print("DEBUG: Sticker Zoom Start (\(sticker.content))") }
                    currentScale = value
                }
                .onEnded { value in
                    print("DEBUG: Sticker Zoom End (\(sticker.content))")
                    sticker.scale *= value
                    currentScale = 1.0
                } : nil
        )
        .highPriorityGesture(
            isSelected ? RotationGesture()
                .onChanged { value in
                    if currentRotation == .zero { print("DEBUG: Sticker Rotation Start (\(sticker.content))") }
                    currentRotation = value
                }
                .onEnded { value in
                    print("DEBUG: Sticker Rotation End (\(sticker.content))")
                    sticker.rotation += value
                    currentRotation = .zero
                } : nil
        )
    }
    
    private var selectionHandles: some View {
        // This would normally be 4 small circles at corners, 
        // but for now, we rely on the pinch/rotate gestures.
        // Let's add simple visual cues for professional look.
        ZStack {
            Circle().fill(.white).frame(width: 10, height: 10).offset(x: -40, y: -40)
            Circle().fill(.white).frame(width: 10, height: 10).offset(x: 40, y: -40)
            Circle().fill(.white).frame(width: 10, height: 10).offset(x: -40, y: 40)
            Circle().fill(.white).frame(width: 10, height: 10).offset(x: 40, y: 40)
        }
    }
}
