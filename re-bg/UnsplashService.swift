import Foundation
import UIKit

struct UnsplashPhoto: Identifiable, Codable {
    let id: String
    let urls: PhotoURLs
    let user: UnsplashUser
    
    struct PhotoURLs: Codable {
        let regular: String
        let small: String
        let thumb: String
    }
    
    struct UnsplashUser: Codable {
        let name: String
    }
}

struct UnsplashSearchResponse: Codable {
    let results: [UnsplashPhoto]
}

class UnsplashService {
    private let accessKey = "XZGmbkc5Zhvx29YrD1CJS5g1pFSQ1gWRMwVo2hM7v34"
    private let baseURL = "https://api.unsplash.com"
    
    func searchPhotos(query: String) async throws -> [UnsplashPhoto] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/photos?query=\(encodedQuery)&per_page=30") else {
            print("❌ UnsplashService: Invalid URL")
            return []
        }
        
        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        
        print("🔍 UnsplashService: Searching for '\(query)'")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 UnsplashService: Status Code \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
                print("❌ UnsplashService: API Error - \(errorBody)")
                throw NSError(domain: "UnsplashService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(httpResponse.statusCode)"])
            }
        }
        
        do {
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(UnsplashSearchResponse.self, from: data)
            print("✅ UnsplashService: Found \(searchResponse.results.count) photos")
            return searchResponse.results
        } catch {
            print("❌ UnsplashService: Decoding error - \(error)")
            throw error
        }
    }
    
    func downloadImage(url: String) async throws -> UIImage? {
        guard let imageURL = URL(string: url) else { return nil }
        print("⏳ UnsplashService: Downloading image from \(url)")
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        return UIImage(data: data)
    }
}
