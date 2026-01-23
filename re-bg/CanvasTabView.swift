//
//  CanvasTabView.swift
//  re-bg
//
//  Created by Photo Editor
//

import SwiftUI

enum AspectRatio: String, CaseIterable, Identifiable {
    case original = "Original"
    case square = "1:1"
    case fourThree = "4:3"
    case sixteenNine = "16:9"
    case custom = "Eigene"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .original: return "aspectratio"
        case .square: return "square"
        case .fourThree: return "rectangle"
        case .sixteenNine: return "rectangle.fill"
        case .custom: return "slider.horizontal.2.square"
        }
    }
    
    var ratio: CGFloat? {
        switch self {
        case .original: return nil
        case .square: return 1.0
        case .fourThree: return 4.0 / 3.0
        case .sixteenNine: return 16.0 / 9.0
        case .custom: return nil
        }
    }
}

struct CanvasTabView: View {
    @ObservedObject var viewModel: EditorViewModel
    @State private var customWidth: String = ""
    @State private var customHeight: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.selectedAspectRatio == .custom {
                // Custom Measurement View
                HStack(spacing: 20) {
                    Button(action: {
                        withAnimation(.spring()) {
                            viewModel.selectedAspectRatio = .original
                            viewModel.customSize = nil
                            viewModel.updateAdjustment()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    HStack(spacing: 15) {
                        customInputField(label: "B", value: $customWidth, placeholder: "Breite")
                        customInputField(label: "H", value: $customHeight, placeholder: "Höhe")
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 90)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            } else {
                // Presets Toolbar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(AspectRatio.allCases) { ratio in
                            VStack(spacing: 8) {
                                Button(action: {
                                    hapticFeedback()
                                    viewModel.saveState()
                                    withAnimation(.spring()) {
                                        viewModel.selectedAspectRatio = ratio
                                        if ratio != .custom {
                                            viewModel.customSize = nil
                                        }
                                        viewModel.updateAdjustment()
                                    }
                                }) {
                                    Image(systemName: ratio.iconName)
                                        .font(.system(size: 20))
                                        .foregroundColor(viewModel.selectedAspectRatio == ratio ? .blue : .white)
                                        .frame(width: 44, height: 44)
                                        .background(viewModel.selectedAspectRatio == ratio ? Color.blue.opacity(0.15) : Color.white.opacity(0.1))
                                        .cornerRadius(10)
                                }
                                
                                Text(ratio.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(viewModel.selectedAspectRatio == ratio ? .blue : .gray)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 100)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .padding(.vertical, 0)
        .onChange(of: customWidth) { _ in updateCustomSize() }
        .onChange(of: customHeight) { _ in updateCustomSize() }
    }
    
    private func customInputField(label: String, value: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
            
            TextField(placeholder, text: value)
                .keyboardType(.numberPad)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
                .foregroundColor(.white)
                .frame(width: 70)
                .font(.system(size: 14))
        }
    }
    
    private func updateCustomSize() {
        if let w = Double(customWidth), let h = Double(customHeight), w > 0, h > 0 {
            viewModel.customSize = CGSize(width: w, height: h)
            viewModel.updateAdjustment()
        }
    }
}
