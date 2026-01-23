import SwiftUI

enum SelectedLayer {
    case foreground
    case background
}

struct ZoomableImageView: View {
    let foreground: UIImage?
    let background: UIImage?
    let original: UIImage?
    let backgroundColor: Color?
    let gradientColors: [Color]?
    let activeLayer: SelectedLayer
    
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
    
    @State private var showVGuide = false
    @State private var showHGuide = false
    @State private var interactingLayer: SelectedLayer? = nil
    
    private let snapThreshold: CGFloat = 10
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Background Layer (Bottom)
                Group {
                    if let bgImage = background {
                        Image(uiImage: bgImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.blue, lineWidth: (interactingLayer == .background) ? 3 : 0)
                            )
                            .scaleEffect(bgScale)
                            .offset(bgOffset)
                    } else if let colors = gradientColors {
                        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.blue, lineWidth: (interactingLayer == .background) ? 3 : 0)
                            )
                            .scaleEffect(bgScale)
                            .offset(bgOffset)
                    } else if let color = backgroundColor {
                        color
                            .overlay(
                                Rectangle()
                                    .stroke(Color.blue, lineWidth: (interactingLayer == .background) ? 3 : 0)
                            )
                            .scaleEffect(bgScale)
                            .offset(bgOffset)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .gesture(layerGesture(for: .background))
                
                // 2. Foreground Layer (Middle)
                if let displayImage = (foreground ?? original) {
                    Image(uiImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            Rectangle()
                                .stroke(Color.blue, lineWidth: (interactingLayer == .foreground) ? 3 : 0)
                        )
                        .scaleEffect(fgScale)
                        .offset(fgOffset)
                        .gesture(layerGesture(for: .foreground))
                }
                
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
        let drag = DragGesture(minimumDistance: 0)
            .onChanged { value in
                if interactingLayer == nil {
                    interactingLayer = layer
                    hapticFeedback()
                }
                updatePosition(for: layer, translation: value.translation)
            }
            .onEnded { _ in
                finalizeOffset(for: layer)
                interactingLayer = nil
                withAnimation(.easeOut(duration: 0.2)) {
                    showVGuide = false
                    showHGuide = false
                }
            }
            
        let zoom = MagnificationGesture()
            .onChanged { value in
                if interactingLayer == nil {
                    interactingLayer = layer
                    hapticFeedback()
                }
                updateScale(for: layer, value: value)
            }
            .onEnded { _ in
                finalizeScale(for: layer)
                interactingLayer = nil
            }
            
        let doubleTap = TapGesture(count: 2)
            .onEnded {
                resetTransform(for: layer)
            }
            
        return drag.simultaneously(with: zoom).simultaneously(with: doubleTap)
    }
    
    private func updatePosition(for layer: SelectedLayer, translation: CGSize) {
        let newX: CGFloat
        let newY: CGFloat
        
        if layer == .foreground {
            newX = fgLastOffset.width + translation.width
            newY = fgLastOffset.height + translation.height
        } else {
            newX = bgLastOffset.width + translation.width
            newY = bgLastOffset.height + translation.height
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
        
        if layer == .foreground {
            fgOffset = CGSize(width: finalX, height: finalY)
        } else {
            bgOffset = CGSize(width: finalX, height: finalY)
        }
    }
    
    private func finalizeOffset(for layer: SelectedLayer) {
        if layer == .foreground {
            fgLastOffset = fgOffset
        } else {
            bgLastOffset = bgOffset
        }
    }
    
    private func updateScale(for layer: SelectedLayer, value: CGFloat) {
        if layer == .foreground {
            fgScale = fgLastScale * value
        } else {
            bgScale = bgLastScale * value
        }
    }
    
    private func finalizeScale(for layer: SelectedLayer) {
        if layer == .foreground {
            fgLastScale = fgScale
        } else {
            bgLastScale = bgScale
        }
    }
    
    private func resetTransform(for layer: SelectedLayer) {
        withAnimation(.spring()) {
            if layer == .foreground {
                fgScale = 1.0
                fgLastScale = 1.0
                fgOffset = .zero
                fgLastOffset = .zero
            } else {
                bgScale = 1.0
                bgLastScale = 1.0
                bgOffset = .zero
                bgLastOffset = .zero
            }
            showVGuide = false
            showHGuide = false
        }
        hapticFeedback()
    }
}
