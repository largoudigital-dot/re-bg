//
//  ContentView.swift
//  re-bg
//
//  Created by Photo Editor
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isEditorActive = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1F2937")
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // App Title
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(Color(hex: "#3B82F6"))
                        
                        Text("Foto Editor")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Wähle ein Foto zum Bearbeiten")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#9CA3AF"))
                    }
                    
                    // Select Photo Button
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20))
                            
                            Text("Foto auswählen")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: 300)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#3B82F6"))
                        .cornerRadius(12)
                    }
                }
                
                // Navigation to Editor
                if let image = selectedImage {
                    NavigationLink(
                        destination: EditorView(image: image),
                        isActive: $isEditorActive
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker { rawImage in
                    self.selectedImage = rawImage
                    self.isEditorActive = true
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let onSelect: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    if let uiImage = image as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.onSelect(uiImage)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
