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
    var selectedEffect: EffectType
    var backgroundImage: UIImage?
}

class EditorViewModel: ObservableObject {
    @Published var originalImage: UIImage?
    @Published var foregroundImage: UIImage? // The image with background removed
    @Published var backgroundImage: UIImage?
    @Published var processedImage: UIImage?
    
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
    @Published var selectedEffect: EffectType = .none
    
    // Undo/Redo Stacks
    private var undoStack: [EditorState] = []
    private var redoStack: [EditorState] = []
    private var isApplyingState = false
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    // Status indicators
    var isCanvasActive: Bool {
        selectedAspectRatio != .original || rotation != 0 || customSize != nil
    }
    
    var isFilterActive: Bool {
        selectedFilter != .none
    }
    
    var isAdjustActive: Bool {
        brightness != 1.0 || contrast != 1.0 || saturation != 1.0 || blur != 0.0
    }
    
    var isEffectActive: Bool {
        selectedEffect != .none
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
            selectedEffect: selectedEffect,
            backgroundImage: backgroundImage
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
        selectedEffect = state.selectedEffect
        backgroundImage = state.backgroundImage
    }
    
    func setBackgroundImage(_ image: UIImage) {
        saveState()
        self.backgroundImage = image
        updateProcessedImage()
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
        backgroundImage = nil // Also reset background if needed
        updateProcessedImage()
    }
    
    private func updateProcessedImage() {
        // Use foreground if available, otherwise original
        guard let foreground = foregroundImage ?? originalImage else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let processed = self.imageProcessor.processImageWithCrop(
                original: foreground,
                filter: self.selectedFilter,
                brightness: self.brightness,
                contrast: self.contrast,
                saturation: self.saturation,
                blur: self.blur,
                rotation: self.rotation,
                aspectRatio: self.selectedAspectRatio.ratio,
                customSize: self.customSize,
                effect: self.selectedEffect,
                backgroundImage: self.backgroundImage
            )
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.processedImage = processed ?? foreground
                }
            }
        }
    }
    
    func saveToGallery(completion: @escaping (Bool, String) -> Void) {
        guard let image = processedImage else {
            completion(false, "Kein Bild zum Speichern")
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
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(true, "Foto gespeichert")
                    } else {
                        completion(false, error?.localizedDescription ?? "Fehler beim Speichern")
                    }
                }
            }
        }
    }
}
