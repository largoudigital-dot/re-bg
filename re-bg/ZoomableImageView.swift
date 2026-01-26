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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Tap Area for Canvas manipulation and Deselection
                Color.black.opacity(0.001)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedStickerId = nil
                        }
                    }
                    .gesture(layerGesture(for: .canvas))
                
                // --- CANVAS CONTAINER ---
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
                            
                            // Sticker Layer
                            ForEach($stickers) { $sticker in
                                StickerView(
                                    sticker: $sticker,
                                    containerSize: geometry.size,
                                    isSelected: selectedStickerId == sticker.id,
                                    onSelect: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedStickerId = sticker.id
                                        }
                                    }
                                )
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
                // --- END CANVAS CONTAINER ---
                
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
                    interactingLayer = targetLayer
                    hapticFeedback()
                }
                updatePosition(for: targetLayer, translation: value.translation)
            }
            .onEnded { _ in
                finalizeOffset(for: targetLayer)
                interactingLayer = nil
                withAnimation(.easeOut(duration: 0.2)) {
                    showVGuide = false
                    showHGuide = false
                }
            }
            
        let zoom = MagnificationGesture()
            .onChanged { value in
                if interactingLayer == nil {
                    interactingLayer = targetLayer
                    hapticFeedback()
                }
                updateScale(for: targetLayer, value: value)
            }
            .onEnded { _ in
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
}

struct StickerView: View {
    @Binding var sticker: Sticker
    let containerSize: CGSize
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var currentScale: CGFloat = 1.0
    @State private var currentRotation: Angle = .zero
    
    var body: some View {
        Text(sticker.content)
            .font(.system(size: 60))
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white : Color.clear, style: StrokeStyle(lineWidth: 2, dash: [5]))
            )
            .scaleEffect(sticker.scale * currentScale)
            .rotationEffect(sticker.rotation + currentRotation)
            .position(
                x: sticker.position.x * containerSize.width + dragOffset.width,
                y: sticker.position.y * containerSize.height + dragOffset.height
            )
            .onTapGesture {
                onSelect()
            }
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        sticker.position.x += value.translation.width / containerSize.width
                        sticker.position.y += value.translation.height / containerSize.height
                        dragOffset = .zero
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        currentScale = value
                    }
                    .onEnded { value in
                        sticker.scale *= value
                        currentScale = 1.0
                    }
            )
            .simultaneousGesture(
                RotationGesture()
                    .onChanged { value in
                        currentRotation = value
                    }
                    .onEnded { value in
                        sticker.rotation += value
                        currentRotation = .zero
                    }
            )
    }
}
