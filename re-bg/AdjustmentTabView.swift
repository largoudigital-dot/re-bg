//
//  AdjustmentTabView.swift
//  re-bg
//
//  Created by Photo Editor
//

import SwiftUI

enum AdjustmentParameter: String, CaseIterable, Identifiable {
    case brightness = "Helligkeit"
    case contrast = "Kontrast"
    case saturation = "Sättigung"
    case sharpness = "Schärfe"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .brightness: return "sun.max.fill"
        case .contrast: return "circle.lefthalf.filled"
        case .saturation: return "drop.fill"
        case .sharpness: return "triangle.fill"
        }
    }
}

struct AdjustmentTabView: View {
    @ObservedObject var viewModel: EditorViewModel
    @Binding var selectedParameter: AdjustmentParameter?
    
    var body: some View {
        ZStack {
            if let parameter = selectedParameter {
                // Slider Detail View
                HStack(spacing: 12) {
                    // Center Slider Area
                    VStack(spacing: 4) {
                        Text(parameter.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        
                        SliderView(parameter: parameter, viewModel: viewModel)
                        
                        Text(String(format: "%.0f%%", getParameterValue(parameter) * 100))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#3B82F6"))
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Reset Button (stays visible)
                    Button(action: {
                        hapticFeedback()
                        viewModel.resetAdjustments()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Text("Reset")
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                        }
                        .frame(width: 44, height: 90)
                    }
                }
                .padding(.horizontal, 16)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                // Main Tool List View
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AdjustmentParameter.allCases) { parameter in
                            Button(action: {
                                hapticFeedback()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedParameter = parameter
                                }
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: parameter.iconName)
                                        .font(.system(size: 22))
                                        .foregroundColor(.white)
                                    
                                    Text(parameter.rawValue)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 70, height: 70)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Main Reset Button
                        Button(action: {
                            hapticFeedback()
                            viewModel.resetAdjustments()
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise.circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                Text("Reset")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 70, height: 70)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
            }
        }
        .frame(height: 90)
    }
    
    private func getParameterValue(_ parameter: AdjustmentParameter) -> Double {
        switch parameter {
        case .brightness: return viewModel.brightness
        case .contrast: return viewModel.contrast
        case .saturation: return viewModel.saturation
        case .sharpness: return viewModel.blur / 20.0
        }
    }
}

struct SliderView: View {
    let parameter: AdjustmentParameter
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        switch parameter {
        case .brightness:
            Slider(value: $viewModel.brightness, in: 0...2, onEditingChanged: { editing in
                if !editing { viewModel.finishAdjustment() }
            })
                .accentColor(Color(hex: "#3B82F6"))
                .onChange(of: viewModel.brightness) { _ in viewModel.updateAdjustment() }
        case .contrast:
            Slider(value: $viewModel.contrast, in: 0...2, onEditingChanged: { editing in
                if !editing { viewModel.finishAdjustment() }
            })
                .accentColor(Color(hex: "#3B82F6"))
                .onChange(of: viewModel.contrast) { _ in viewModel.updateAdjustment() }
        case .saturation:
            Slider(value: $viewModel.saturation, in: 0...2, onEditingChanged: { editing in
                if !editing { viewModel.finishAdjustment() }
            })
                .accentColor(Color(hex: "#3B82F6"))
                .onChange(of: viewModel.saturation) { _ in viewModel.updateAdjustment() }
        case .sharpness:
            Slider(value: $viewModel.blur, in: 0...20, onEditingChanged: { editing in
                if !editing { viewModel.finishAdjustment() }
            })
                .accentColor(Color(hex: "#3B82F6"))
                .onChange(of: viewModel.blur) { _ in viewModel.updateAdjustment() }
        }
    }
}
