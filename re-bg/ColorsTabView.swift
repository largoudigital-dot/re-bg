import SwiftUI

struct ColorsTabView: View {
    @ObservedObject var viewModel: EditorViewModel
    @Binding var selectedPicker: ColorPickerTab?
    
    // Preset Colors
    let presetColors: [Color] = [
        .white, .black, .gray, .red, .blue, .green, .yellow, .orange, .pink, .purple, .cyan, .mint
    ]
    
    // Gradient Pairs
    let gradients: [[Color]] = [
        [.blue, .purple],
        [.orange, .red],
        [.green, .blue],
        [.pink, .orange],
        [.black, .gray],
        [.blue, .cyan],
        [.purple, .pink],
        [.yellow, .orange]
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            if let picker = selectedPicker {
                // Schritt 2: Picker Content ONLY
                ZStack {
                    switch picker {
                    case .presets:
                        presetsView
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    case .gradients:
                        gradientsView
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                // Schritt 1: 3-Button Navigation
                HStack(spacing: 0) {
                    ForEach(ColorPickerTab.allCases) { tab in
                        Button(action: {
                            hapticFeedback()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedPicker = tab
                            }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 26, weight: .regular))
                                    .frame(width: 28, height: 28)
                                
                                Text(tab.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }
    
    private var presetsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(presetColors, id: \.self) { color in
                    ColorCircle(color: color, isSelected: viewModel.backgroundColor == color && viewModel.gradientColors == nil) {
                        hapticFeedback()
                        viewModel.saveState()
                        viewModel.backgroundColor = color
                        viewModel.gradientColors = nil
                        viewModel.backgroundImage = nil
                        viewModel.updateAdjustment()
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var gradientsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<gradients.count, id: \.self) { index in
                    let colors = gradients[index]
                    GradientCircle(colors: colors, isSelected: viewModel.gradientColors == colors) {
                        hapticFeedback()
                        viewModel.saveState()
                        viewModel.gradientColors = colors
                        viewModel.backgroundColor = nil
                        viewModel.backgroundImage = nil
                        viewModel.updateAdjustment()
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}



struct ColorCircle: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                if isSelected {
                    Circle()
                        .stroke(Color.blue, lineWidth: 3)
                        .frame(width: 52, height: 52)
                }
            }
        }
    }
}

struct GradientCircle: View {
    let colors: [Color]
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                
                if isSelected {
                    Circle()
                        .stroke(Color.blue, lineWidth: 3)
                        .frame(width: 52, height: 52)
                }
            }
        }
    }
}
