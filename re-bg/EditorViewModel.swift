//
//  EditorViewModel.swift
//  re-bg
//
//  Created by Photo Editor
//

import SwiftUI
import Photos

struct EditorState: Equatable {
    var selectedFilter: FilterType
    var brightness: Double
    var contrast: Double
    var saturation: Double
    var blur: Double
    var rotation: CGFloat
    var selectedAspectRatio: AspectRatio
    var customSize: CGSize?
    var backgroundColor: Color?
    var gradientColors: [Color]?
    var backgroundImage: UIImage?
    var cropRect: CGRect? // Normalized applied crop
    var stickers: [Sticker]
    var textItems: [TextItem]
    
    static func == (lhs: EditorState, rhs: EditorState) -> Bool {
        return lhs.selectedFilter == rhs.selectedFilter &&
            lhs.brightness == rhs.brightness &&
            lhs.contrast == rhs.contrast &&
            lhs.saturation == rhs.saturation &&
            lhs.blur == rhs.blur &&
            lhs.rotation == rhs.rotation &&
            lhs.selectedAspectRatio == rhs.selectedAspectRatio &&
            lhs.customSize == rhs.customSize &&
            lhs.backgroundColor == rhs.backgroundColor &&
            lhs.gradientColors == rhs.gradientColors &&
            lhs.backgroundImage === rhs.backgroundImage &&
            lhs.cropRect == rhs.cropRect &&
            lhs.stickers == rhs.stickers &&
            lhs.textItems == rhs.textItems
    }
}

enum ImageFormat {
    case png
    case jpg
}

class EditorViewModel: ObservableObject {
    @Published var originalImage: UIImage?
    @Published var foregroundImage: UIImage? // The image with background removed
    @Published var backgroundImage: UIImage?
    @Published var processedImage: UIImage?
    @Published var fullProcessedImage: UIImage? // The image with all adjustments but NO CROP
    
    @Published var selectedFilter: FilterType = .none
    // ... rest of properties
    @Published var brightness: Double = 1.0
    @Published var contrast: Double = 1.0
    @Published var saturation: Double = 1.0
    @Published var blur: Double = 0.0
    @Published var rotation: CGFloat = 0.0
    @Published var isRemovingBackground = false
    @Published var selectedAspectRatio: AspectRatio = .original
    @Published var customSize: CGSize? = nil
    @Published var backgroundColor: Color? = nil
    @Published var gradientColors: [Color]? = nil
    
    // Crop State
    @Published var isCropping = false
    @Published var appliedCropRect: CGRect? = nil
    
    // Sticker State
    @Published var stickers: [Sticker] = []
    @Published var selectedStickerId: UUID? = nil
    @Published var showingEmojiPicker = false
    
    // Text State
    @Published var textItems: [TextItem] = []
    @Published var selectedTextId: UUID? = nil
    @Published var showingTextEditor = false
    
    // Undo/Redo Stacks
    private var undoStack: [EditorState] = []
    private var redoStack: [EditorState] = []
    private var isApplyingState = false
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    // Status indicators
    var isCanvasActive: Bool {
        selectedAspectRatio != .original || rotation != 0 || customSize != nil || isCropping || !textItems.isEmpty
    }
    
    var isFilterActive: Bool {
        selectedFilter != .none
    }
    
    var isAdjustActive: Bool {
        brightness != 1.0 || contrast != 1.0 || saturation != 1.0 || blur != 0.0
    }
    
    var isColorActive: Bool {
        backgroundColor != nil || gradientColors != nil
    }
    
    var isBackgroundTransparent: Bool {
        backgroundColor == nil && gradientColors == nil && backgroundImage == nil
    }
    
    var hasChanges: Bool {
        // Any undo history or active non-default state indicates changes
        return !undoStack.isEmpty || 
               selectedFilter != .none || 
               brightness != 1.0 || 
               contrast != 1.0 || 
               saturation != 1.0 || 
               blur != 0.0 || 
               rotation != 0 || 
               selectedAspectRatio != .original || 
               !stickers.isEmpty ||
               backgroundColor != nil ||
               gradientColors != nil ||
               backgroundImage != nil ||
               appliedCropRect != nil
    }
    
    private let imageProcessor = ImageProcessor()
    private let removalService = BackgroundRemovalService()
    
    func setImage(_ image: UIImage) {
        self.originalImage = image
        self.foregroundImage = nil
        self.backgroundImage = nil
        updateProcessedImage()
        removeBackgroundFromCurrent()
        
        // Initial state
        undoStack.removeAll()
        redoStack.removeAll()
    }
    
    private func currentState() -> EditorState {
        EditorState(
            selectedFilter: selectedFilter,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            blur: blur,
            rotation: rotation,
            selectedAspectRatio: selectedAspectRatio,
            customSize: customSize,
            backgroundColor: backgroundColor,
            gradientColors: gradientColors,
            backgroundImage: backgroundImage,
            cropRect: appliedCropRect,
            stickers: stickers,
            textItems: textItems
        )
    }
    
    func saveState() {
        guard !isApplyingState else { return }
        let state = currentState()
        if undoStack.last != state {
            undoStack.append(state)
            redoStack.removeAll()
            // Keep stack size reasonable
            if undoStack.count > 20 {
                undoStack.removeFirst()
            }
        }
    }
    
    func undo() {
        guard undoStack.count > 1 else { return }
        isApplyingState = true
        
        // Current state goes to redo
        if let current = undoStack.popLast() {
            redoStack.append(current)
        }
        
        // Previous state becomes current
        if let previous = undoStack.last {
            applyState(previous)
        }
        
        isApplyingState = false
        updateProcessedImage()
    }
    
    func redo() {
        guard let next = redoStack.popLast() else { return }
        isApplyingState = true
        
        undoStack.append(next)
        applyState(next)
        
        isApplyingState = false
        updateProcessedImage()
    }
    
    private func applyState(_ state: EditorState) {
        selectedFilter = state.selectedFilter
        brightness = state.brightness
        contrast = state.contrast
        saturation = state.saturation
        blur = state.blur
        rotation = state.rotation
        selectedAspectRatio = state.selectedAspectRatio
        customSize = state.customSize
        backgroundColor = state.backgroundColor
        gradientColors = state.gradientColors
        backgroundImage = state.backgroundImage
        appliedCropRect = state.cropRect
        stickers = state.stickers
        textItems = state.textItems
    }
    
    func setBackgroundImage(_ image: UIImage) {
        saveState()
        self.backgroundImage = image
        self.backgroundColor = nil
        self.gradientColors = nil
        updateProcessedImage()
    }
    
    // MARK: - Crop Management
    
    func startCropping() {
        // Just enter mode, no state save yet
        isCropping = true
    }
    
    func cancelCropping() {
        isCropping = false
    }
    
    func applyCrop(_ rect: CGRect) {
        // Now "rect" is relative to the FULL processed image,
        // because we show the full image in crop mode.
        saveState()
        appliedCropRect = rect
        isCropping = false // Exit crop mode so the cropped image becomes visible
        updateProcessedImage()
    }
    
    // MARK: - Sticker Management
    
    func addSticker(_ content: String) {
        saveState()
        let newSticker = Sticker(content: content)
        stickers.append(newSticker)
        updateProcessedImage()
    }
    
    func updateSticker(_ sticker: Sticker) {
        if let index = stickers.firstIndex(where: { $0.id == sticker.id }) {
            // We don't save state on every drag update, but we might want to on end
            stickers[index] = sticker
            updateProcessedImage()
        }
    }
    
    func finalizeStickerUpdate() {
        saveState()
    }
    
    func removeSticker(id: UUID) {
        saveState()
        if selectedStickerId == id {
            selectedStickerId = nil
        }
        stickers.removeAll(where: { $0.id == id })
        updateProcessedImage()
    }
    
    // MARK: - Text Management
    
    func addTextItem(_ item: TextItem) {
        saveState()
        textItems.append(item)
        updateProcessedImage()
    }
    
    func updateTextItem(_ item: TextItem) {
        if let index = textItems.firstIndex(where: { $0.id == item.id }) {
            textItems[index] = item
            updateProcessedImage()
        }
    }
    
    func removeTextItem(id: UUID) {
        saveState()
        if selectedTextId == id {
            selectedTextId = nil
        }
        textItems.removeAll(where: { $0.id == id })
        updateProcessedImage()
    }
    
    func selectTextItem(id: UUID) {
        selectedTextId = id
        selectedStickerId = nil // Exclusivity
    }
    
    func deselectTextItem() {
        selectedTextId = nil
    }
    
    func finalizeTextUpdate() {
        saveState()
    }
    
    func selectSticker(id: UUID) {
        selectedStickerId = id
    }
    
    func deselectSticker() {
        selectedStickerId = nil
    }
    
    func removeBackgroundFromCurrent() {
        guard let image = originalImage else { return }
        
        isRemovingBackground = true
        
        Task {
            do {
                if let processed = try await removalService.removeBackground(from: image) {
                    await MainActor.run {
                        self.foregroundImage = processed
                        self.updateProcessedImage()
                        self.isRemovingBackground = false
                    }
                } else {
                    await MainActor.run {
                        self.isRemovingBackground = false
                    }
                }
            } catch {
                print("❌ EditorViewModel: Background removal failed - \(error.localizedDescription)")
                await MainActor.run {
                    self.isRemovingBackground = false
                }
            }
        }
    }
    
    func applyFilter(_ filter: FilterType) {
        saveState()
        selectedFilter = filter
        updateProcessedImage()
    }
    
    func updateAdjustment() {
        updateProcessedImage()
    }
    
    func finishAdjustment() {
        saveState()
    }
    
    func rotateLeft() {
        saveState()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            rotation -= 90
            if rotation < 0 {
                rotation += 360
            }
            updateProcessedImage()
        }
    }
    
    func rotateRight() {
        saveState()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            rotation += 90
            if rotation >= 360 {
                rotation -= 360
            }
            updateProcessedImage()
        }
    }
    
    func resetAdjustments() {
        saveState()
        brightness = 1.0
        contrast = 1.0
        saturation = 1.0
        blur = 0.0
        backgroundColor = nil
        gradientColors = nil
        backgroundImage = nil // Also reset background if needed
        updateProcessedImage()
    }
    
    private func updateProcessedImage() {
        // Use foreground if available, otherwise original
        guard let foreground = foregroundImage ?? originalImage else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Generate FULL processed image (no crop)
            let full = self.imageProcessor.processImageWithCrop(
                original: foreground,
                filter: self.selectedFilter,
                brightness: self.brightness,
                contrast: self.contrast,
                saturation: self.saturation,
                blur: self.blur,
                rotation: self.rotation,
                aspectRatio: nil, // No aspect ratio crop here
                customSize: nil,   // No custom size crop here
                backgroundColor: nil,
                gradientColors: nil,
                backgroundImage: nil,
                cropRect: nil,     // No free crop here
                stickers: []
            )
            
            // 2. Generate CROPPED processed image
            let cropped = self.imageProcessor.processImageWithCrop(
                original: foreground,
                filter: self.selectedFilter,
                brightness: self.brightness,
                contrast: self.contrast,
                saturation: self.saturation,
                blur: self.blur,
                rotation: self.rotation,
                aspectRatio: self.selectedAspectRatio.ratio,
                customSize: self.customSize,
                backgroundColor: nil,
                gradientColors: nil,
                backgroundImage: nil,
                cropRect: self.appliedCropRect,
                stickers: [],
                textItems: self.textItems // Render text items in preview
            )
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.fullProcessedImage = full ?? foreground
                    self.processedImage = cropped ?? foreground
                }
            }
        }
    }
    
    func saveToGallery(format: ImageFormat = .png, completion: @escaping (Bool, String) -> Void) {
        guard let foreground = foregroundImage ?? originalImage else {
            completion(false, "Kein Bild zum Speichern")
            return
        }
        
        // Generate final image with stickers burned in
        let finalImage = self.imageProcessor.processImageWithCrop(
            original: foreground,
            filter: self.selectedFilter,
            brightness: self.brightness,
            contrast: self.contrast,
            saturation: self.saturation,
            blur: self.blur,
            rotation: self.rotation,
            aspectRatio: self.selectedAspectRatio.ratio,
            customSize: self.customSize,
            backgroundColor: self.backgroundColor,
            gradientColors: self.gradientColors,
            backgroundImage: self.backgroundImage,
            cropRect: self.appliedCropRect,
            stickers: self.stickers, // Burn them in here
            textItems: self.textItems // Burn text items in final image
        ) ?? foreground

        let data: Data?
        switch format {
        case .png:
            data = finalImage.pngData()
        case .jpg:
            data = finalImage.jpegData(compressionQuality: 0.8)
        }
        
        guard let finalData = data, let finalImage = UIImage(data: finalData) else {
            completion(false, "Fehler bei der Bildverarbeitung")
            return
        }
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    completion(false, "Keine Berechtigung für Fotobibliothek")
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: finalImage)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(true, "Foto als \(format == .png ? "PNG" : "JPG") gespeichert")
                    } else {
                        completion(false, error?.localizedDescription ?? "Fehler beim Speichern")
                    }
                }
            }
        }
    }
    
    func shareImage() {
        guard let foreground = foregroundImage ?? originalImage else { return }
        
        let finalImage = self.imageProcessor.processImageWithCrop(
            original: foreground,
            filter: self.selectedFilter,
            brightness: self.brightness,
            contrast: self.contrast,
            saturation: self.saturation,
            blur: self.blur,
            rotation: self.rotation,
            aspectRatio: self.selectedAspectRatio.ratio,
            customSize: self.customSize,
            backgroundColor: self.backgroundColor,
            gradientColors: self.gradientColors,
            backgroundImage: self.backgroundImage,
            cropRect: self.appliedCropRect,
            stickers: self.stickers,
            textItems: self.textItems
        ) ?? foreground
        
        // Use PNG if there's transparency, JPG otherwise for sharing
        let data = isBackgroundTransparent ? finalImage.pngData() : finalImage.jpegData(compressionQuality: 0.8)
        guard let finalData = data, let finalImage = UIImage(data: finalData) else { return }
        
        let activityVC = UIActivityViewController(activityItems: [finalImage], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            // For iPad support
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }
}
