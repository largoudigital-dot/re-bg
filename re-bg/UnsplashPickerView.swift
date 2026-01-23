import SwiftUI

struct UnsplashPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var photos: [UnsplashPhoto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
            .navigationTitle("Unsplash Fotos")
            .navigationBarTitleDisplayMode(.inline)
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
