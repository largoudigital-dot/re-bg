//
//  EffectTabView.swift
//  re-bg
//
//  Created by Photo Editor
//

import SwiftUI

enum EffectType: String, CaseIterable, Identifiable {
    case none = "Original"
    case vignette = "Vignette"
    case bloom = "Bloom"
    case noir = "Noir"
    case crystal = "Kristall"
    case blur = "Unschärfe"
    case edges = "Kanten"
    case posterize = "Poster"
    case grain = "Körnung"
    
    var id: String { rawValue }
}

struct EffectTabView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    // Cache for preview images to avoid re-calculating on every redraw
    @State private var previewImages: [String: UIImage] = [:]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(EffectType.allCases) { effect in
                    VStack(spacing: 8) {
                        ZStack {
                            if let preview = previewImages[effect.id] {
                                Image(uiImage: preview)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    )
                            }
                            
                            if viewModel.selectedEffect == effect {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(hex: "#3B82F6"), lineWidth: 2)
                                    .frame(width: 56, height: 56)
                            }
                        }
                        
                        Text(effect.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(viewModel.selectedEffect == effect ? Color(hex: "#3B82F6") : .white)
                    }
                    .onTapGesture {
                        viewModel.saveState()
                        withAnimation {
                            viewModel.selectedEffect = effect
                            viewModel.updateAdjustment()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 90)
        .onAppear {
            generatePreviews()
        }
        .onChange(of: viewModel.foregroundImage) { _ in generatePreviews() }
        .onChange(of: viewModel.backgroundImage) { _ in generatePreviews() }
    }
    
    private func generatePreviews() {
        guard let foreground = viewModel.foregroundImage ?? viewModel.originalImage else { return }
        let background = viewModel.backgroundImage
        
        DispatchQueue.global(qos: .userInitiated).async {
            let thumbSize = CGSize(width: 140, height: 140)
            let processor = ImageProcessor()
            
            for effect in EffectType.allCases {
                // 1. Process foreground with effect
                let effectedForeground = processor.applyEffect(effect, to: foreground) ?? foreground
                
                // 2. Composite with background
                UIGraphicsBeginImageContextWithOptions(thumbSize, false, 0)
                let rect = CGRect(origin: .zero, size: thumbSize)
                
                if let bg = background {
                    bg.draw(in: rect)
                }
                
                effectedForeground.draw(in: rect)
                
                let result = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                DispatchQueue.main.async {
                    self.previewImages[effect.id] = result
                }
            }
        }
    }
}
