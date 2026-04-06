//
//  ModelDownloadManager.swift
//  KAI
//
//  Kitchen Assistant - Model Download Manager
//  Downloads Llama 3.2 1B model from HuggingFace
//

import Foundation

/// Model download errors
enum ModelDownloadError: LocalizedError, Equatable {
    case invalidURL
    case downloadFailed(Error)
    case fileSystemError(Error)
    case verificationFailed
    case insufficientStorage
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .verificationFailed:
            return "Model file verification failed"
        case .insufficientStorage:
            return "Not enough storage space. Need at least 2GB free."
        case .networkUnavailable:
            return "No internet connection. Please connect to WiFi."
        }
    }

    static func == (lhs: ModelDownloadError, rhs: ModelDownloadError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.verificationFailed, .verificationFailed),
             (.insufficientStorage, .insufficientStorage),
             (.networkUnavailable, .networkUnavailable):
            return true
        case (.downloadFailed(let lhsError), .downloadFailed(let rhsError)),
             (.fileSystemError(let lhsError), .fileSystemError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Model information
struct ModelInfo {
    let name: String
    let size: Int64 // Size in bytes
    let url: String
    let filename: String
    let description: String
    let requiredStorage: Int64 // Required free space in bytes

    var sizeInGB: Double {
        return Double(size) / 1_073_741_824.0 // Convert bytes to GB
    }

    var requiredStorageInGB: Double {
        return Double(requiredStorage) / 1_073_741_824.0
    }
}

/// Model download state
enum ModelDownloadState {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case error(ModelDownloadError)
}

/// Manager for downloading and managing AI models
@MainActor
class ModelDownloadManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var downloadState: ModelDownloadState = .notDownloaded
    @Published var downloadProgress: Double = 0.0
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0

    // MARK: - Properties

    /// Llama 3.2 1B model information
    static let llama32_1B = ModelInfo(
        name: "Llama 3.2 1B",
        size: 1_500_000_000, // ~1.5GB
        url: "https://huggingface.co/hugging-quants/Llama-3.2-1B-Instruct-Q4_K_M-GGUF/resolve/main/llama-3.2-1b-instruct-q4_k_m.gguf",
        filename: "llama-3.2-1b-instruct-q4_k_m.gguf",
        description: "Lightweight AI model optimized for on-device inference. Perfect for recipe assistance.",
        requiredStorage: 2_000_000_000 // Require 2GB free space
    )

    private var downloadTask: URLSessionDownloadTask?
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes
        config.timeoutIntervalForResource = 3600 // 1 hour
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    // MARK: - File Paths

    /// Get the Documents directory
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Get the models directory (creates if needed)
    private var modelsDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Get path to model file
    func getModelPath(for model: ModelInfo) -> URL {
        return modelsDirectory.appendingPathComponent(model.filename)
    }

    /// Get path string to model file
    func getModelPathString(for model: ModelInfo) -> String {
        return getModelPath(for: model).path
    }

    // MARK: - Model Status

    /// Check if model is downloaded
    func isModelDownloaded(_ model: ModelInfo) -> Bool {
        let path = getModelPath(for: model)
        return FileManager.default.fileExists(atPath: path.path)
    }

    /// Get downloaded model size
    func getDownloadedModelSize(_ model: ModelInfo) -> Int64? {
        let path = getModelPath(for: model)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path.path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }

    /// Update download state based on model status
    func updateState(for model: ModelInfo) {
        if isModelDownloaded(model) {
            downloadState = .downloaded
            downloadProgress = 1.0
        } else {
            downloadState = .notDownloaded
            downloadProgress = 0.0
        }
    }

    // MARK: - Storage Management

    /// Check available storage space
    private func getAvailableStorage() -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentsDirectory.path)
            return attributes[.systemFreeSize] as? Int64
        } catch {
            print("Error checking storage: \(error)")
            return nil
        }
    }

    /// Check if there's enough storage for download
    private func hasEnoughStorage(for model: ModelInfo) -> Bool {
        guard let available = getAvailableStorage() else { return false }
        return available >= model.requiredStorage
    }

    // MARK: - Download Operations

    /// Download model from HuggingFace
    func downloadModel(_ model: ModelInfo) async throws {
        // Check network
        guard isNetworkAvailable() else {
            downloadState = .error(.networkUnavailable)
            throw ModelDownloadError.networkUnavailable
        }

        // Check storage
        guard hasEnoughStorage(for: model) else {
            downloadState = .error(.insufficientStorage)
            throw ModelDownloadError.insufficientStorage
        }

        // Check if already downloaded
        if isModelDownloaded(model) {
            print("ℹ️ Model already downloaded")
            downloadState = .downloaded
            return
        }

        // Validate URL
        guard let url = URL(string: model.url) else {
            downloadState = .error(.invalidURL)
            throw ModelDownloadError.invalidURL
        }

        print("📥 Starting download of \(model.name)...")
        print("📍 URL: \(model.url)")
        print("💾 Size: \(String(format: "%.2f GB", model.sizeInGB))")

        // Start download
        downloadState = .downloading(progress: 0.0)
        downloadProgress = 0.0
        totalBytes = model.size

        return try await withCheckedThrowingContinuation { continuation in
            downloadTask = urlSession.downloadTask(with: url) { [weak self] tempURL, response, error in
                guard let self = self else { return }

                Task { @MainActor in
                    if let error = error {
                        self.downloadState = .error(.downloadFailed(error))
                        continuation.resume(throwing: ModelDownloadError.downloadFailed(error))
                        return
                    }

                    guard let tempURL = tempURL else {
                        let error = ModelDownloadError.downloadFailed(NSError(domain: "ModelDownload", code: -1))
                        self.downloadState = .error(error)
                        continuation.resume(throwing: error)
                        return
                    }

                    do {
                        let destinationURL = self.getModelPath(for: model)

                        // Remove existing file if present
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try FileManager.default.removeItem(at: destinationURL)
                        }

                        // Move downloaded file
                        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                        print("✅ Model downloaded successfully")
                        print("📍 Saved to: \(destinationURL.path)")

                        // Verify file size
                        if let fileSize = self.getDownloadedModelSize(model) {
                            print("📊 File size: \(String(format: "%.2f GB", Double(fileSize) / 1_073_741_824.0))")
                        }

                        self.downloadState = .downloaded
                        self.downloadProgress = 1.0

                        continuation.resume()

                    } catch {
                        print("❌ Failed to save model: \(error)")
                        self.downloadState = .error(.fileSystemError(error))
                        continuation.resume(throwing: ModelDownloadError.fileSystemError(error))
                    }
                }
            }

            downloadTask?.resume()
        }
    }

    /// Cancel ongoing download
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadState = .notDownloaded
        downloadProgress = 0.0
        print("🛑 Download cancelled")
    }

    // MARK: - Model Management

    /// Delete downloaded model
    func deleteModel(_ model: ModelInfo) throws {
        let path = getModelPath(for: model)

        guard FileManager.default.fileExists(atPath: path.path) else {
            print("ℹ️ Model file not found, nothing to delete")
            return
        }

        do {
            try FileManager.default.removeItem(at: path)
            print("🗑️ Model deleted successfully")
            downloadState = .notDownloaded
            downloadProgress = 0.0
        } catch {
            print("❌ Failed to delete model: \(error)")
            throw ModelDownloadError.fileSystemError(error)
        }
    }

    // MARK: - Network Check

    private func isNetworkAvailable() -> Bool {
        // Simple network availability check
        // For production, consider using NWPathMonitor
        return true // Placeholder - assume network is available
    }

    // MARK: - Helper Methods

    /// Get storage usage info
    func getStorageInfo() -> (used: Int64, available: Int64, total: Int64)? {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: documentsDirectory.path) else {
            return nil
        }

        let available = attributes[.systemFreeSize] as? Int64 ?? 0
        let total = attributes[.systemSize] as? Int64 ?? 0
        let used = total - available

        return (used: used, available: available, total: total)
    }

    /// Format bytes to readable string
    static func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        let mb = Double(bytes) / 1_048_576.0

        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Handled in completion handler
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            self.downloadedBytes = totalBytesWritten
            self.totalBytes = totalBytesExpectedToWrite

            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            self.downloadProgress = progress
            self.downloadState = .downloading(progress: progress)

            // Log progress at 25% intervals
            let percentage = Int(progress * 100)
            if percentage % 25 == 0 {
                print("📊 Download progress: \(percentage)% (\(ModelDownloadManager.formatBytes(totalBytesWritten)) / \(ModelDownloadManager.formatBytes(totalBytesExpectedToWrite)))")
            }
        }
    }
}
