//
//  EditorView.swift
//  re-bg
//
//  Created by Photo Editor
//

import SwiftUI

enum EditorTab: String, CaseIterable, Identifiable {
    case crop = "Schnitt"
    case colors = "Farben"
    case adjust = "Anpassen"
    case unsplash = "Fotos"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .crop: return "crop"
        case .colors: return "paintpalette"
        case .adjust: return "slider.horizontal.3"
        case .unsplash: return "photo.on.rectangle"
        }
    }
}

enum ColorPickerTab: String, CaseIterable, Identifiable {
    case presets = "Presets"
    case gradients = "Verläufe"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .presets: return "circle.grid.2x2"
        case .gradients: return "slider.horizontal.2.square"
        }
    }
}

struct EditorView: View {
    @StateObject private var viewModel = EditorViewModel()
    @State private var selectedTab: EditorTab?
    @State private var selectedAdjustmentParameter: AdjustmentParameter? = nil
    @State private var selectedColorPicker: ColorPickerTab? = nil
    @State private var showingSaveAlert = false
    @State private var saveMessage = ""
    @State private var showingUnsplashPicker = false
    @State private var isShowingOriginal = false
    @Environment(\.dismiss) private var dismiss
    
    let selectedImage: UIImage
    
    init(image: UIImage) {
        self.selectedImage = image
    }
    
    var body: some View {
        photoArea
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 1) // 1px horizontal padding as requested
            .safeAreaInset(edge: .top, spacing: 0) {
                navigationBar
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarHidden(true)
            .preferredColorScheme(.light)
            .onAppear {
                viewModel.setImage(selectedImage)
            }
            .alert("Speichern", isPresented: $showingSaveAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveMessage)
            }
            .sheet(isPresented: $showingUnsplashPicker) {
                UnsplashPickerView { newImage in
                    viewModel.setBackgroundImage(newImage)
                }
            }
            .sheet(isPresented: $viewModel.showingEmojiPicker) {
                EmojiPickerView { emoji in
                    viewModel.addSticker(emoji)
                    viewModel.showingEmojiPicker = false
                }
                .presentationDetents([.medium, .large])
            }
    }
    
    private var bottomBar: some View {
        ZStack {
            if let tab = selectedTab {
                // Detail Bar
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if let _ = selectedAdjustmentParameter {
                                selectedAdjustmentParameter = nil
                            } else if let _ = selectedColorPicker {
                                selectedColorPicker = nil
                            } else {
                                selectedTab = nil
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 50, height: 90)
                            .background(Color.white)
                    }
                    
                    tabContent(for: tab)
                        .frame(maxWidth: .infinity)
                        .transition(.move(edge: .trailing))
                }
            } else {
                // Main Tab Bar
                tabBar
                    .transition(.move(edge: .leading))
            }
        }
        .frame(height: 90)
        .background(Color.white.opacity(0.8).ignoresSafeArea(edges: .bottom))
        .background(.ultraThinMaterial, ignoresSafeAreaEdges: .bottom)
    }
    
    private var navigationBar: some View {
        ZStack {
            HStack {
                Button(action: {
                    hapticFeedback()
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
                
                Button(action: {
                    hapticFeedback()
                    viewModel.shareImage()
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                
                Menu {
                    Button(action: {
                        hapticFeedback()
                        viewModel.saveToGallery(format: .png) { success, message in
                            saveMessage = message
                            showingSaveAlert = true
                        }
                    }) {
                        Label("Als PNG speichern\(viewModel.isBackgroundTransparent ? " (Empfohlen)" : "")", systemImage: "doc.richtext")
                    }
                    
                    Button(action: {
                        hapticFeedback()
                        viewModel.saveToGallery(format: .jpg) { success, message in
                            saveMessage = message
                            showingSaveAlert = true
                        }
                    }) {
                        Label("Als JPG speichern\(!viewModel.isBackgroundTransparent ? " (Empfohlen)" : "")", systemImage: "photo")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
            }
            
            Text("Bearbeiten")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial, ignoresSafeAreaEdges: .top)
    }
    
    private var photoArea: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - 2 // Considering horizontal padding
            let availableHeight = geometry.size.height
            
            // Use processedImage size if available to match the visible result (crucial for crop handling)
            let displayImage = (isShowingOriginal ? viewModel.originalImage : viewModel.processedImage) ?? viewModel.originalImage
            let imageSize = displayImage?.size ?? CGSize(width: 1, height: 1)
            let rawAspectRatio = imageSize.width / imageSize.height
            
            // If rotated 90 or 270, swap aspect ratio
            let imageAspectRatio = (Int(viewModel.rotation) % 180 != 0) ? (1.0 / rawAspectRatio) : rawAspectRatio
            
            // Determine the target aspect ratio based on user selection
            let targetAspectRatio: CGFloat = {
                if let ratio = viewModel.selectedAspectRatio.ratio {
                    return ratio
                }
                return imageAspectRatio // Default to original image ratio for .free, .original, etc.
            }()
            
            let containerAspectRatio = availableWidth / availableHeight
            
            let fitSize: CGSize = {
                if targetAspectRatio > containerAspectRatio {
                    // Width is limiting
                    return CGSize(width: availableWidth, height: availableWidth / targetAspectRatio)
                } else {
                    // Height is limiting
                    return CGSize(width: availableHeight * targetAspectRatio, height: availableHeight)
                }
            }()
            
            ZStack {
                Color.clear
                
                ZStack {
                    if let original = viewModel.originalImage {
                        ZoomableImageView(
                            foreground: displayImage, // Show the full processed result (or original)
                            background: nil, // Background is already composited in processedImage
                            original: original,
                            backgroundColor: nil, // Encoded in processedImage
                            gradientColors: nil, // Encoded in processedImage
                            activeLayer: .foreground, // Treat as single layer
                            rotation: viewModel.rotation,
                            isCropping: viewModel.isCropping,
                            onCropCommit: { rect in
                                viewModel.applyCrop(rect)
                            },
                            stickers: $viewModel.stickers,
                            selectedStickerId: $viewModel.selectedStickerId
                        )
                        .id("photo-\(viewModel.rotation)-\(viewModel.originalImage?.hashValue ?? 0)")
                    }
                    
                    if viewModel.isRemovingBackground {
                        ZStack {
                            Color.white.opacity(0.7)
                            
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                    .scaleEffect(1.2)
                                
                                Text("Hintergrund wird entfernt...")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                    }
                }
                .frame(width: fitSize.width, height: fitSize.height)
                .background(Color(white: 0.95))
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                rotationControls
                    .padding(.bottom, 24)
            }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    compareButton
                    
                    stickerButton
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
            }
        }
    }
    
    private var rotationControls: some View {
        HStack(spacing: 8) {
            // History Group
            HStack(spacing: 0) {
                Button(action: {
                    hapticFeedback()
                    withAnimation { viewModel.undo() }
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(viewModel.canUndo ? .primary : .primary.opacity(0.3))
                        .frame(width: 44, height: 44)
                }
                .disabled(!viewModel.canUndo)
                
                Divider()
                    .frame(height: 20)
                    .background(Color.primary.opacity(0.2))
                
                Button(action: {
                    hapticFeedback()
                    withAnimation { viewModel.redo() }
                }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(viewModel.canRedo ? .primary : .primary.opacity(0.3))
                        .frame(width: 44, height: 44)
                }
                .disabled(!viewModel.canRedo)
            }
            .background(Color.white.opacity(0.7))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            // Rotation Group
            HStack(spacing: 0) {
                Button(action: {
                    hapticFeedback()
                    viewModel.rotateLeft()
                }) {
                    Image(systemName: "rotate.left")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                
                Divider()
                    .frame(height: 20)
                    .background(Color.primary.opacity(0.2))
                
                Button(action: {
                    hapticFeedback()
                    viewModel.rotateRight()
                }) {
                    Image(systemName: "rotate.right")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
            }
            .background(Color.white.opacity(0.7))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var compareButton: some View {
        ZStack {
            Image(systemName: "square.split.2x1")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isShowingOriginal ? .blue : .primary)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.7))
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isShowingOriginal {
                        hapticFeedback()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingOriginal = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingOriginal = false
                    }
                }
        )
    }
    
    private var stickerButton: some View {
        Button(action: {
            hapticFeedback()
            viewModel.showingEmojiPicker = true
        }) {
            Image(systemName: "face.smiling")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.7))
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(EditorTab.allCases) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    isActive: isTabActive(tab),
                    action: {
                        hapticFeedback()
                        viewModel.cancelCropping() // Reset crop mode on tab change
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if tab == .unsplash {
                                showingUnsplashPicker = true
                            } else {
                                selectedTab = tab
                            }
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    
    
    private func isTabActive(_ tab: EditorTab) -> Bool {
        switch tab {
        case .crop: return viewModel.isCanvasActive
        case .adjust: return viewModel.isAdjustActive
        case .colors: return viewModel.isColorActive
        case .unsplash: return false
        }
    }
    
    @ViewBuilder
    private func tabContent(for tab: EditorTab) -> some View {
        switch tab {
        case .crop:
            CanvasTabView(viewModel: viewModel)
        case .adjust:
            AdjustmentTabView(viewModel: viewModel, selectedParameter: $selectedAdjustmentParameter)
        case .colors:
            ColorsTabView(viewModel: viewModel, selectedPicker: $selectedColorPicker)
        case .unsplash:
            EmptyView()
        }
    }


    

}

struct TabButton: View {
    let tab: EditorTab
    let isSelected: Bool
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.iconName)
                        .font(.system(size: 26, weight: .regular))
                        .frame(width: 28, height: 28)
                    
                    if isActive {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -4)
                    }
                }
                
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isSelected ? .blue : .primary.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

struct PlaceholderTabView: View {
    let tabName: String
    
    var body: some View {
        VStack {
            Text("\(tabName) - Bald verfügbar")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#9CA3AF"))
                .padding()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(Color(hex: "#374151"))
    }
}
