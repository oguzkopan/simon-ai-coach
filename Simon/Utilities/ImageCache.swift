//
//  ImageCache.swift
//  Simon
//
//  Created on Day 19-21: Polish + Edge Cases
//

import UIKit
import SwiftUI

actor ImageCache {
    static let shared = ImageCache()
    
    private var cache: [URL: UIImage] = [:]
    private let maxCacheSize = 100 // Maximum number of images to cache
    
    private init() {}
    
    func image(for url: URL) -> UIImage? {
        return cache[url]
    }
    
    func store(_ image: UIImage, for url: URL) {
        // Simple LRU: remove oldest if cache is full
        if cache.count >= maxCacheSize {
            cache.removeValue(forKey: cache.keys.first!)
        }
        cache[url] = image
    }
    
    func clear() {
        cache.removeAll()
    }
}

// MARK: - Cached Async Image

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
    }
    
    private func loadImage() async {
        guard let url = url, !isLoading else { return }
        
        isLoading = true
        
        // Check cache first
        if let cachedImage = await ImageCache.shared.image(for: url) {
            self.image = cachedImage
            isLoading = false
            return
        }
        
        // Download image
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                await ImageCache.shared.store(downloadedImage, for: url)
                self.image = downloadedImage
            }
        } catch {
            print("Failed to load image: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Convenience Initializer

extension CachedAsyncImage where Content == Image, Placeholder == Color {
    init(url: URL?) {
        self.init(
            url: url,
            content: { $0.resizable() },
            placeholder: { Color.gray.opacity(0.2) }
        )
    }
}
