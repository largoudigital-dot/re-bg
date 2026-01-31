
import SwiftUI

struct TextEditorOverlay: View {
    @Binding var textItem: TextItem
    let onDone: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            // Transparent background to show image below (like Instagram Stories)
            Color.black.opacity(0.01)
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    onDone()
                }
            
            // Subtle bottom gradient for better focus (as requested)
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.black.opacity(0.4), Color.black.opacity(0.3), Color.black.opacity(0)],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: UIScreen.main.bounds.height * 0.5)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            
            VStack(spacing: 20) {
                Spacer()
                
                Spacer()
                
                // Text Input Area
                ZStack {
                    TextField("", text: $textItem.text, axis: .vertical)
                        .focused($isTextFieldFocused)
                        .font(.custom(textItem.fontName, size: 36))
                        .foregroundColor(textItem.color)
                        .multilineTextAlignment(mapAlignment(textItem.alignment))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Group {
                                if textItem.backgroundStyle != .none {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(textItem.backgroundColor.opacity(textItem.backgroundStyle == .solid ? 1.0 : 0.6))
                                }
                            }
                        )
                        .tint(textItem.color)
                }
                .padding(.horizontal, 30) // Horizontal margin from screen edges
                
                Spacer()
                
                // Bottom Controls
                VStack(spacing: 12) {
                    // Navigation Bar (Move to bottom)
                    HStack {
                        Button("Abbrechen") {
                            onCancel()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                toggleAlignment()
                            }) {
                                Image(systemName: textItem.alignment.iconName)
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: {
                                toggleBackground()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(textItem.backgroundStyle != .none ? Color.white : Color.black.opacity(0.6))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: textItem.backgroundStyle.iconName)
                                        .foregroundColor(textItem.backgroundStyle != .none ? .black : .white)
                                        .font(.system(size: 20, weight: .bold))
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button("Fertig") {
                            onDone()
                        }
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    
                    // Font Selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(TextEditorStyles.fonts) { font in
                                Button(action: {
                                    textItem.fontName = font.name
                                }) {
                                    Text(font.displayName)
                                        .font(.custom(font.name, size: 16))
                                        .padding(.horizontal, 15)
                                        .padding(.vertical, 8)
                                        .background(textItem.fontName == font.name ? Color.white : Color.white.opacity(0.15))
                                        .foregroundColor(textItem.fontName == font.name ? .black : .white)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(.horizontal, 16)
                    
                    // Color Selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TextEditorStyles.colors, id: \.self) { color in
                                ZStack {
                                    if textItem.backgroundStyle != .none {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Text("A")
                                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                                    .foregroundColor(shouldShowBlackText(on: color) ? .black : .white)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.white, lineWidth: textItem.backgroundColor == color ? 3 : 0)
                                            )
                                    } else {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: textItem.color == color ? 3 : 0)
                                            )
                                    }
                                }
                                .contentShape(Rectangle()) // Better hit testing
                                .shadow(color: .black.opacity(0.2), radius: 2)
                                .onTapGesture {
                                    if textItem.backgroundStyle != .none {
                                        textItem.backgroundColor = color
                                        textItem.color = shouldShowBlackText(on: color) ? .black : .white
                                    } else {
                                        textItem.color = color
                                    }
                                }
                            }
                            
                            ColorPicker("", selection: Binding(
                                get: { textItem.backgroundStyle != .none ? textItem.backgroundColor : textItem.color },
                                set: { newColor in
                                    if textItem.backgroundStyle != .none {
                                        textItem.backgroundColor = newColor
                                        textItem.color = shouldShowBlackText(on: newColor) ? .black : .white
                                    } else {
                                        textItem.color = newColor
                                    }
                                }
                            ))
                                .labelsHidden()
                                .scaleEffect(1.2)
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private func toggleAlignment() {
        let cases = TextAlignment.allCases
        if let index = cases.firstIndex(of: textItem.alignment) {
            let nextIndex = (index + 1) % cases.count
            textItem.alignment = cases[nextIndex]
        }
    }
    
    private func toggleBackground() {
        let cases = TextBackgroundStyle.allCases
        if let index = cases.firstIndex(of: textItem.backgroundStyle) {
            let nextIndex = (index + 1) % cases.count
            textItem.backgroundStyle = cases[nextIndex]
            
            // Handle color contrast when background becomes active
            if textItem.backgroundStyle != .none {
                // If background is currently black but text is also dark, or background is default
                if textItem.backgroundColor == .black && textItem.color == .black {
                    textItem.backgroundColor = .white
                }
                
                // Adjust text color for contrast against background
                textItem.color = shouldShowBlackText(on: textItem.backgroundColor) ? .black : .white
            }
        }
    }
    
    private func shouldShowBlackText(on color: Color) -> Bool {
        // Robust luminance check
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let uiColor = UIColor(color)
        
        // Handle potential failure of getRed (e.g. for some color spaces)
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            return luminance > 0.6
        } else {
            // Fallback for complex colors: get components via white value
            var white: CGFloat = 0
            if uiColor.getWhite(&white, alpha: &a) {
                return white > 0.6
            }
        }
        return false // Default to white text for safety
    }
    
    private func mapAlignment(_ alignment: TextAlignment) -> SwiftUI.TextAlignment {
        switch alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}
