//
//  CanvasTabView.swift
//  re-bg
//
//  Created by Photo Editor
//

import SwiftUI

enum AspectRatio: String, CaseIterable, Identifiable {
    case free = "Frei"
    case square = "1:1"
    case fourFive = "4:5"
    case nineSixteen = "9:16"
    case sixteenNine = "16:9"
    case apple55 = "5.5''"
    case apple58 = "5.8''"
    case fourThree = "4:3"
    case original = "Original"
    case custom = "Eigene"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .free: return "crop"
        case .square, .fourFive: return "instagram"
        case .nineSixteen: return "tiktok"
        case .sixteenNine: return "rectangle.ratio.16.to.9"
        case .apple55, .apple58: return "apple-icon"
        case .fourThree: return "facebook"
        case .original: return "aspectratio"
        case .custom: return "slider.horizontal.2.square"
        }
    }
    
    var displayLabel: String {
        switch self {
        case .fbHorizontal: return "" // No label for horizontal FB as in photo
        default: return self.rawValue
        }
    }
    
    var usesCustomImage: Bool {
        switch self {
        case .square, .fourFive, .nineSixteen, .fourThree:
            return true
        default:
            return false
        }
    }
    
    var ratio: CGFloat? {
        switch self {
        case .free: return nil
        case .original: return nil
        case .square: return 1.0
        case .fourFive: return 4.0 / 5.0
        case .fourThree: return 4.0 / 3.0
        case .apple55: return 9.0 / 16.0
        case .apple58: return 1125.0 / 2436.0
        case .custom: return nil
        }
    }
}

struct CanvasTabView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Schnitt (Crop) Options - Only show aspect ratio scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AspectRatio.allCases) { ratio in
                        Button(action: {
                            hapticFeedback()
                            viewModel.saveState()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectedAspectRatio = ratio
                                if ratio != .custom {
                                    viewModel.customSize = nil
                                }
                                viewModel.updateAdjustment()
                            }
                        }) {
                            VStack(spacing: 6) {
                                AspectRatioIcon(ratio: ratio, isSelected: viewModel.selectedAspectRatio == ratio)
                                
                                if !ratio.displayLabel.isEmpty {
                                    Text(ratio.displayLabel)
                                        .font(.system(size: 9, weight: .medium))
                                }
                            }
                            .foregroundColor(viewModel.selectedAspectRatio == ratio ? .black : .primary)
                            .frame(width: 52, height: 60)
                            .background(viewModel.selectedAspectRatio == ratio ? Color.white : Color(white: 0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 80)
            .padding(.bottom, 10)
        }
    }
}

struct AspectRatioIcon: View {
    let ratio: AspectRatio
    let isSelected: Bool
    
    var body: some View {
        let size: CGFloat = 20
        let displayRatio: CGFloat = {
            if let r = ratio.ratio {
                return r
            }
            return 1.0 // Default for Original/Free/Custom
        }()
        
        // Calculate icon dimensions to fit within a 20x20 bounding box
        let iconWidth: CGFloat = displayRatio > 1 ? size : size * displayRatio
        let iconHeight: CGFloat = displayRatio > 1 ? size / displayRatio : size
        
        ZStack {
            if ratio.usesCustomImage {
                Image(ratio.iconName)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24) // Larger size, no frame
            } else if ratio == .original || ratio == .free || ratio == .custom {
                Image(systemName: ratio.iconName)
                    .font(.system(size: 20)) // Consistent with other buttons
            } else {
                // Proportional rectangle for generic ratios
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isSelected ? Color.black : Color.primary.opacity(0.8), lineWidth: 1.2)
                    .frame(width: iconWidth, height: iconHeight)
            }
        }
        .frame(width: 28, height: 28)
    }
}
