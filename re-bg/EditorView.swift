//
//  EditorView.swift
//  re-bg
//
//  Created by Photo Editor
//

import SwiftUI

enum EditorTab: String, CaseIterable, Identifiable {
    case crop = "Schnitt"
    case filter = "Filter"
    case colors = "Farben"
    case adjust = "Anpassen"
    case unsplash = "Fotos"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .crop: return "crop"
        case .filter: return "camera.filters"
        case .colors: return "paintpalette"
        case .adjust: return "slider.horizontal.3"
        case .unsplash: return "photo.on.rectangle"
        }
    }
}

enum ColorPickerTab: String, CaseIterable, Identifiable {
    case presets = "Presets"
    case gradients = "Verläufe"
    case transparent = "Transparent"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .presets: return "circle.grid.2x2"
        case .gradients: return "slider.horizontal.2.square"
        case .transparent: return "circle.dotted"
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
    @State private var showingExitAlert = false
    @State private var isShowingOriginal = false
    @State private var tempTextItem: TextItem? = nil
    @Environment(\.dismiss) private var dismiss
    
    let selectedImage: UIImage
    
    init(image: UIImage) {
        self.selectedImage = image
    }
    
    var body: some View {
        ZStack {
            photoArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 1) // 1px horizontal padding as requested
                .safeAreaInset(edge: .top, spacing: 0) {
                    navigationBar
                        .opacity(viewModel.showingTextEditor ? 0 : 1)
                        .allowsHitTesting(!viewModel.showingTextEditor)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomBar
                        .opacity(viewModel.showingTextEditor ? 0 : 1)
                        .allowsHitTesting(!viewModel.showingTextEditor)
                }
                .background(Color.white.ignoresSafeArea())
                .ignoresSafeArea(.keyboard)
                .navigationBarHidden(true)
                .preferredColorScheme(.light)
                .onAppear {
                    viewModel.setImage(selectedImage)
                }
            
            if viewModel.showingTextEditor, let item = tempTextItem {
                TextEditorOverlay(
                    textItem: Binding(
                        get: { tempTextItem ?? item },
                        set: { tempTextItem = $0 }
                    ),
                    onDone: {
                        if let updated = tempTextItem {
                            if viewModel.textItems.contains(where: { $0.id == updated.id }) {
                                viewModel.updateTextItem(updated)
                            } else if !updated.text.isEmpty {
                                viewModel.addTextItem(updated)
                            }
                        }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showingTextEditor = false
                        }
                        tempTextItem = nil
                    },
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showingTextEditor = false
                        }
                        tempTextItem = nil
                    }
                )
                .transition(.opacity)
                .zIndex(2000)
            }
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
            .alert("Änderungen verwerfen?", isPresented: $showingExitAlert) {
                Button("Abbrechen", role: .cancel) { }
                Button("Verwerfen", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("Möchten Sie alle Änderungen an diesem Foto wirklich verwerfen?")
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
                                if selectedTab == .crop {
                                    viewModel.cancelCropping()
                                }
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
                    if viewModel.hasChanges {
                        showingExitAlert = true
                    } else {
                        dismiss()
                    }
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
            
            // Base image aspect ratio (stable, using original image)
            let rawOriginalAspectRatio = (viewModel.originalImage?.size ?? CGSize(width: 1, height: 1)).width / (viewModel.originalImage?.size ?? CGSize(width: 1, height: 1)).height
            let originalImageAspectRatio = (Int(viewModel.rotation) % 180 != 0) ? (1.0 / rawOriginalAspectRatio) : rawOriginalAspectRatio

            // Current display image (might be cropped)
            // Use fullProcessedImage specifically when CROPPING to allow boundary adjustments
            let displayImage: UIImage? = {
                if isShowingOriginal { return viewModel.originalImage }
                // Always use the FULL processed image in the editor display
                // to keep dimensions stable. ZoomableImageView will mask it.
                return viewModel.fullProcessedImage ?? viewModel.processedImage ?? viewModel.originalImage
            }() ?? viewModel.originalImage
            
            // Determine the target aspect ratio for the CANVAS container
            let targetAspectRatio: CGFloat = {
                if let ratio = viewModel.selectedAspectRatio.ratio {
                    return ratio
                }
                // Use the ORIGINAL image aspect ratio as the base for the canvas
                // to prevent it from resizing when the processed image (crop) changes.
                return originalImageAspectRatio
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
                            foreground: displayImage, // Show the processed foreground (without background baked in)
                            background: viewModel.backgroundImage,
                            original: original,
                            backgroundColor: viewModel.backgroundColor,
                            gradientColors: viewModel.gradientColors,
                            activeLayer: .foreground, // Treat as single layer
                            rotation: viewModel.rotation,
                            isCropping: viewModel.isCropping,
                            appliedCropRect: viewModel.appliedCropRect,
                            onCropCommit: { rect in
                                viewModel.applyCrop(rect)
                            },
                            stickers: $viewModel.stickers,
                            selectedStickerId: $viewModel.selectedStickerId,
                            onDeleteSticker: { id in
                                viewModel.removeSticker(id: id)
                            },
                            textItems: $viewModel.textItems,
                            selectedTextId: $viewModel.selectedTextId,
                            onDeleteText: { id in
                                viewModel.removeTextItem(id: id)
                            },
                            onEditText: { item in
                                tempTextItem = item
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.showingTextEditor = true
                                }
                            },
                            isEditingText: viewModel.showingTextEditor
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
                    .opacity(viewModel.showingTextEditor ? 0 : 1)
                    .allowsHitTesting(!viewModel.showingTextEditor)
            }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    compareButton
                    textButton
                    stickerButton
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
                .opacity(viewModel.showingTextEditor ? 0 : 1)
                .allowsHitTesting(!viewModel.showingTextEditor)
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
    
    private var textButton: some View {
        Button(action: {
            hapticFeedback()
            tempTextItem = TextItem()
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.showingTextEditor = true
            }
        }) {
            Image(systemName: "textformat")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.7))
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
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
        case .filter: return viewModel.isFilterActive
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
        case .filter:
            FilterTabView(viewModel: viewModel)
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
