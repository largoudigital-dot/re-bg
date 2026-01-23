//
//  EditorView.swift
//  re-bg
//
//  Created by Photo Editor
//

import SwiftUI

enum EditorTab: String, CaseIterable, Identifiable {
    case canvas = "Leinwand"
    case colors = "Farben"
    case adjust = "Anpassen"
    case unsplash = "Fotos"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .canvas: return "square.on.square"
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
    @Environment(\.dismiss) private var dismiss
    
    let selectedImage: UIImage
    
    init(image: UIImage) {
        self.selectedImage = image
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top Navigation Bar
                navigationBar
                
                // Photo Display Area
                photoArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom Bar Area (Main or Detail)
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
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 90)
                                    .background(Color.black)
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
                .frame(height: bottomBarHeight)
                .background(Color.black.opacity(0.8))
                .background(.ultraThinMaterial)
            }
            .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 10)
            .background(Color.black)
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
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
    }
    
    private var bottomBarHeight: CGFloat {
        return 90 // Minimal height for all color pickers now
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
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
                
                Button(action: {
                    hapticFeedback()
                    viewModel.saveToGallery { success, message in
                        saveMessage = message
                        showingSaveAlert = true
                    }
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
            }
            
            Text("Bearbeiten")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
    
    private var photoArea: some View {
        ZStack {
            Color.clear
            
            if let original = viewModel.originalImage {
                ZoomableImageView(
                    foreground: viewModel.foregroundImage,
                    background: viewModel.backgroundImage,
                    original: original,
                    backgroundColor: viewModel.backgroundColor,
                    gradientColors: viewModel.gradientColors,
                    activeLayer: selectedTab == .canvas ? .canvas : ((selectedTab == .unsplash || selectedTab == .colors) ? .background : .foreground)
                )
                .id("photo-\(viewModel.rotation)")
            }
            
            if viewModel.isRemovingBackground {
                ZStack {
                    Color.black.opacity(0.4)
                    
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                        
                        Text("Hintergrund wird entfernt...")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            }
        }
        .background(Color.black)
        .clipped()
        .overlay(alignment: .bottom) {
            rotationControls
                .padding(.bottom, 24)
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
                        .foregroundColor(viewModel.canUndo ? .white : .white.opacity(0.3))
                        .frame(width: 44, height: 44)
                }
                .disabled(!viewModel.canUndo)
                
                Divider()
                    .frame(height: 20)
                    .background(Color.white.opacity(0.2))
                
                Button(action: {
                    hapticFeedback()
                    withAnimation { viewModel.redo() }
                }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(viewModel.canRedo ? .white : .white.opacity(0.3))
                        .frame(width: 44, height: 44)
                }
                .disabled(!viewModel.canRedo)
            }
            .background(Color.black.opacity(0.5))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            
            // Rotation Group
            HStack(spacing: 0) {
                Button(action: {
                    hapticFeedback()
                    viewModel.rotateLeft()
                }) {
                    Image(systemName: "rotate.left")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                
                Divider()
                    .frame(height: 20)
                    .background(Color.white.opacity(0.2))
                
                Button(action: {
                    hapticFeedback()
                    viewModel.rotateRight()
                }) {
                    Image(systemName: "rotate.right")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
            }
            .background(Color.black.opacity(0.5))
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
        case .canvas: return viewModel.isCanvasActive
        case .adjust: return viewModel.isAdjustActive
        case .colors: return viewModel.isColorActive
        case .unsplash: return false
        }
    }
    
    @ViewBuilder
    private func tabContent(for tab: EditorTab) -> some View {
        switch tab {
        case .canvas:
            CanvasTabView(viewModel: viewModel)
        case .adjust:
            AdjustmentTabView(viewModel: viewModel, selectedParameter: $selectedAdjustmentParameter)
        case .colors:
            ColorsTabView(viewModel: viewModel, selectedPicker: $selectedColorPicker)
        case .unsplash:
            EmptyView()
        }
    }
    
    private func calculatePhotoHeight(geometry: GeometryProxy) -> CGFloat {
        let navigationHeight: CGFloat = 44
        let rotationControlsHeight: CGFloat = 66
        let bottomBarHeight: CGFloat = 90
        
        return geometry.size.height - navigationHeight - rotationControlsHeight - bottomBarHeight
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
            .foregroundColor(isSelected ? .blue : .gray)
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

// Haptic Feedback Helper
func hapticFeedback() {
    let generator = UISelectionFeedbackGenerator()
    generator.selectionChanged()
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
