import UIKit

final class ImageLoadingService {
    static let shared = ImageLoadingService()
    
    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    
    private init() {
        self.session = URLSession.shared
        
        // Configure cache
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func loadImage(from urlString: String) async throws -> UIImage? {
        // Check cache first
        if let cachedImage = cache.object(forKey: urlString as NSString) {
            return cachedImage
        }
        
        // Fix URL if missing protocol
        let fixedUrlString = urlString.hasPrefix("http") ? urlString : "https://\(urlString)"
        
        // Validate URL
        guard let url = URL(string: fixedUrlString) else {
            return nil
        }
        
        // Download image
        let (data, _) = try await session.data(from: url)
        
        guard let image = UIImage(data: data) else {
            return nil
        }
        
        // Cache the image
        cache.setObject(image, forKey: urlString as NSString, cost: data.count)
        
        return image
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}