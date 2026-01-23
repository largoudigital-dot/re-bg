//
//  FilterTabView.swift
//  re-bg
//
//  Created by Photo Editor
//

import SwiftUI

struct FilterTabView: View {
    @ObservedObject var viewModel: EditorViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FilterType.allCases) { filter in
                    FilterThumbnailView(
                        filter: filter,
                        image: viewModel.foregroundImage ?? viewModel.originalImage,
                        backgroundImage: viewModel.backgroundImage,
                        isSelected: viewModel.selectedFilter == filter
                    )
                    .onTapGesture {
                        hapticFeedback()
                        viewModel.applyFilter(filter)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 90)
    }
}

struct FilterThumbnailView: View {
    let filter: FilterType
    let image: UIImage?
    let backgroundImage: UIImage?
    let isSelected: Bool
    
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let thumbnail = thumbnailImage {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 64, height: 64)
                }
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#3B82F6"), lineWidth: 3)
                        .frame(width: 64, height: 64)
                }
            }
            
            Text(filter.displayName)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? Color(hex: "#3B82F6") : Color(hex: "#9CA3AF"))
        }
        .onAppear {
            generateThumbnail()
        }
        .onChange(of: image) { _ in generateThumbnail() }
        .onChange(of: backgroundImage) { _ in generateThumbnail() }
    }
    
    private func generateThumbnail() {
        guard let foreground = image else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let size = CGSize(width: 140, height: 140)
            
            // 1. Process foreground with filter
            let processor = ImageProcessor()
            let filteredForeground = processor.applyFilter(filter, to: foreground) ?? foreground
            
            // 2. Composite with background if exists
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            let rect = CGRect(origin: .zero, size: size)
            
            if let bg = backgroundImage {
                bg.draw(in: rect)
            }
            
            filteredForeground.draw(in: rect)
            
            let result = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            DispatchQueue.main.async {
                self.thumbnailImage = result
            }
        }
    }
}
