
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
                    if textItem.backgroundStyle != .none {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(textItem.backgroundColor.opacity(textItem.backgroundStyle == .solid ? 1.0 : 0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    TextField("", text: $textItem.text, axis: .vertical)
                        .focused($isTextFieldFocused)
                        .font(.custom(textItem.fontName, size: 36))
                        .foregroundColor(textItem.color)
                        .multilineTextAlignment(mapAlignment(textItem.alignment))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .tint(textItem.color)
                }
                .padding(.horizontal, 20)
                
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
                                    .frame(width: 40, height: 40)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: {
                                toggleBackground()
                            }) {
                                Image(systemName: textItem.backgroundStyle.iconName)
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                                    .frame(width: 40, height: 40)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
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
                                Circle()
                                    .fill(color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: textItem.color == color ? 4 : 0)
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 2)
                                    .onTapGesture {
                                        textItem.color = color
                                    }
                            }
                            
                            if textItem.backgroundStyle != .none {
                                ColorPicker("", selection: $textItem.backgroundColor)
                                    .labelsHidden()
                                    .scaleEffect(1.2)
                            }
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
            
            // Default background color if none set
            if textItem.backgroundStyle != .none && textItem.backgroundColor == .black && textItem.color == .black {
                 textItem.backgroundColor = .white
            }
        }
    }
    
    private func mapAlignment(_ alignment: TextAlignment) -> SwiftUI.TextAlignment {
        switch alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}
