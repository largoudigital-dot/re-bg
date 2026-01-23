import Foundation
import UIKit

class BackgroundRemovalService {
    private let apiKey = "nAty7PoA6NweeeqMZEEvdh4b"
    private let endpoint = "https://api.remove.bg/v1.0/removebg"
    
    func removeBackground(from image: UIImage) async throws -> UIImage? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "BackgroundRemovalService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Bilddaten konnten nicht konvertiert werden"])
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image_file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"size\"\r\n\r\n".data(using: .utf8)!)
        body.append("auto".data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("🚀 BackgroundRemovalService: Sending request to remove.bg")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 BackgroundRemovalService: Status Code \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
                print("❌ BackgroundRemovalService: API Error - \(errorBody)")
                throw NSError(domain: "BackgroundRemovalService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(httpResponse.statusCode)"])
            }
        }
        
        print("✅ BackgroundRemovalService: Background removed successfully")
        return UIImage(data: data)
    }
}
