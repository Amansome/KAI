//
//  RecipeImageManager.swift
//  KAI
//
//  Kitchen Assistant - Recipe Image Manager
//

import Foundation
import SwiftUI
import UIKit

class RecipeImageManager: ObservableObject {
    @Published var imageCache: [String: UIImage] = [:]
    @Published var isLoadingImages: [String: Bool] = [:]
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        // Create cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("RecipeImages")
        
        createCacheDirectoryIfNeeded()
        loadCachedImages()
    }
    
    // MARK: - Image Loading
    
    func getImage(for recipe: Recipe) -> UIImage? {
        // Check memory cache first
        if let cachedImage = imageCache[recipe.id] {
            return cachedImage
        }
        
        // Check disk cache
        if let diskImage = loadImageFromDisk(recipeId: recipe.id) {
            imageCache[recipe.id] = diskImage
            return diskImage
        }
        
        // Generate placeholder image if no image exists
        return generatePlaceholderImage(for: recipe)
    }
    
    func loadImageAsync(for recipe: Recipe) {
        guard imageCache[recipe.id] == nil else { return }
        guard isLoadingImages[recipe.id] != true else { return }
        
        isLoadingImages[recipe.id] = true
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            // Try to load from disk first
            if let diskImage = self?.loadImageFromDisk(recipeId: recipe.id) {
                DispatchQueue.main.async {
                    self?.imageCache[recipe.id] = diskImage
                    self?.isLoadingImages[recipe.id] = false
                }
                return
            }
            
            // Generate and cache placeholder
            let placeholder = self?.generatePlaceholderImage(for: recipe)
            
            DispatchQueue.main.async {
                if let placeholder = placeholder {
                    self?.imageCache[recipe.id] = placeholder
                    self?.saveImageToDisk(image: placeholder, recipeId: recipe.id)
                }
                self?.isLoadingImages[recipe.id] = false
            }
        }
    }
    
    // MARK: - Placeholder Generation
    
    private func generatePlaceholderImage(for recipe: Recipe) -> UIImage {
        let size = CGSize(width: 200, height: 150)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background gradient
            let colors = getColorsForCategory(recipe.category)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [colors.0.cgColor, colors.1.cgColor] as CFArray,
                                    locations: [0.0, 1.0])
            
            context.cgContext.drawLinearGradient(gradient!,
                                               start: CGPoint(x: 0, y: 0),
                                               end: CGPoint(x: size.width, y: size.height),
                                               options: [])
            
            // Recipe emoji
            let emoji = recipe.categoryEmoji
            let font = UIFont.systemFont(ofSize: 60)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            
            let emojiSize = emoji.size(withAttributes: attributes)
            let emojiRect = CGRect(
                x: (size.width - emojiSize.width) / 2,
                y: (size.height - emojiSize.height) / 2 - 10,
                width: emojiSize.width,
                height: emojiSize.height
            )
            
            emoji.draw(in: emojiRect, withAttributes: attributes)
            
            // Recipe name
            let nameFont = UIFont.boldSystemFont(ofSize: 14)
            let nameAttributes: [NSAttributedString.Key: Any] = [
                .font: nameFont,
                .foregroundColor: UIColor.white,
                .backgroundColor: UIColor.black.withAlphaComponent(0.5)
            ]
            
            let nameRect = CGRect(x: 10, y: size.height - 30, width: size.width - 20, height: 20)
            recipe.name.draw(in: nameRect, withAttributes: nameAttributes)
        }
    }
    
    private func getColorsForCategory(_ category: String) -> (UIColor, UIColor) {
        switch category.lowercased() {
        case "sandwich":
            return (UIColor.systemOrange, UIColor.systemRed)
        case "salad":
            return (UIColor.systemGreen, UIColor.systemTeal)
        case "kids":
            return (UIColor.systemPurple, UIColor.systemPink)
        case "prep":
            return (UIColor.systemBlue, UIColor.systemIndigo)
        default:
            return (UIColor.systemGray, UIColor.systemGray2)
        }
    }
    
    // MARK: - Disk Cache Management
    
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func loadCachedImages() {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files {
            if file.pathExtension == "png",
               let image = UIImage(contentsOfFile: file.path) {
                let recipeId = file.deletingPathExtension().lastPathComponent
                imageCache[recipeId] = image
            }
        }
    }
    
    private func loadImageFromDisk(recipeId: String) -> UIImage? {
        let imageURL = cacheDirectory.appendingPathComponent("\(recipeId).png")
        return UIImage(contentsOfFile: imageURL.path)
    }
    
    private func saveImageToDisk(image: UIImage, recipeId: String) {
        guard let data = image.pngData() else { return }
        
        let imageURL = cacheDirectory.appendingPathComponent("\(recipeId).png")
        try? data.write(to: imageURL)
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        imageCache.removeAll()
        
        // Clear disk cache
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }
    
    func getCacheSize() -> String {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 MB"
        }
        
        let totalSize = files.compactMap { url -> Int64? in
            let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues?.fileSize ?? 0)
        }.reduce(0, +)
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

