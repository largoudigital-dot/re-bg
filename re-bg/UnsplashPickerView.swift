import SwiftUI

struct UnsplashPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var photos: [UnsplashPhoto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingActionSheet = false
    @State private var showingGallery = false
    @State private var showingCamera = false
    
    let onSelect: (UIImage) -> Void
    private let service = UnsplashService()
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Unsplash durchsuchen...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color(hex: "#374151"))
                .cornerRadius(10)
                .padding()
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    Text(error)
                        .foregroundColor(.red)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            // First Element: Upload Button
                            Button(action: {
                                showingActionSheet = true
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus.viewfinder")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                    Text("Eigenes Foto")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 120)
                                .background(Color.white.opacity(0.1))
                            }
                            
                            ForEach(photos) { photo in
                                Button(action: {
                                    selectPhoto(photo)
                                }) {
                                    AsyncImage(url: URL(string: photo.urls.small)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(minWidth: 0, maxWidth: .infinity)
                                            .frame(height: 120)
                                            .clipped()
                                    } placeholder: {
                                        Color.gray.opacity(0.3)
                                            .frame(height: 120)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .background(Color(hex: "#1F2937").ignoresSafeArea())
            .navigationTitle("Fotos")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Foto hinzufügen", isPresented: $showingActionSheet) {
                Button("Aus Galerie wählen") { showingGallery = true }
                Button("Foto aufnehmen") { showingCamera = true }
                Button("Abbrechen", role: .cancel) { }
            }
            .sheet(isPresented: $showingGallery) {
                ImagePicker(onSelect: { image in
                    onSelect(image)
                    dismiss()
                })
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker(onSelect: { image in
                    onSelect(image)
                    dismiss()
                })
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if photos.isEmpty {
                searchText = "nature"
                performSearch()
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await service.searchPhotos(query: searchText)
                await MainActor.run {
                    self.photos = results
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func selectPhoto(_ photo: UnsplashPhoto) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                if let image = try await service.downloadImage(url: photo.urls.regular) {
                    await MainActor.run {
                        onSelect(image)
                        self.isLoading = false
                        dismiss()
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Bild konnte nicht geladen werden"
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onSelect: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        
        init(_ parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onSelect(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
