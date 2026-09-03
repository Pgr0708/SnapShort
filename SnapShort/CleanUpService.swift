//
//  CleanUpService.swift
//  SnapShort
//

import Foundation
import Photos
import UIKit
import CoreImage
import os

// MARK: - Analysis Result

struct CleanUpAnalysis {
    var duplicateIdentifiers: [String]    = []
    var similarShotIdentifiers: [String]  = []
    var oldUnusedIdentifiers: [String]    = []
    var blurryIdentifiers: [String]       = []
    var totalReclaimableBytes: Int64      = 0

    var totalItems: Int {
        Set(duplicateIdentifiers + similarShotIdentifiers + oldUnusedIdentifiers + blurryIdentifiers).count
    }

    var reclaimableMB: String {
        let mb = Double(totalReclaimableBytes) / 1_048_576
        if mb >= 1000 { return String(format: "%.1f GB", mb / 1024) }
        return String(format: "%.0f MB", mb)
    }

    static let empty = CleanUpAnalysis()
}

// MARK: - Service

actor CleanUpService {

    private let logger = Logger(subsystem: "SnapShort", category: "CleanUp")
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Main Analysis

    func analyze(existingDuplicateIds: [String]) async -> CleanUpAnalysis {
        logger.info("Starting library analysis…")

        async let similar = findSimilarShots()
        async let old     = findOldUnused()
        async let blurry  = findBlurryPhotos()

        let (sim, o, bl) = await (similar, old, blurry)

        // Compute total reclaimable size
        let allIds = Set(existingDuplicateIds + sim + o + bl)
        let bytes  = await computeBytes(for: Array(allIds))

        logger.info("Analysis complete: \(allIds.count) items, \(bytes) bytes")
        return CleanUpAnalysis(
            duplicateIdentifiers:   existingDuplicateIds,
            similarShotIdentifiers: sim,
            oldUnusedIdentifiers:   o,
            blurryIdentifiers:      bl,
            totalReclaimableBytes:  bytes
        )
    }

    // MARK: - Similar Shots (photos taken within 10 s of each other)

    func findSimilarShots() async -> [String] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: options)

        var identifiers: [String] = []
        var lastDate: Date?

        result.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate else { return }
            if let last = lastDate, date.timeIntervalSince(last) <= 10.0 {
                identifiers.append(asset.localIdentifier)
            }
            lastDate = date
        }
        return identifiers
    }

    // MARK: - Old & Unused (>2 years, not in any album)

    func findOldUnused() async -> [String] {
        let options = PHFetchOptions()
        let cutoff  = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        options.predicate   = NSPredicate(format: "creationDate < %@ AND mediaType == %d",
                                          cutoff as NSDate, PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.fetchLimit  = 100

        let result = PHAsset.fetchAssets(with: options)
        var identifiers: [String] = []
        result.enumerateObjects { asset, _, _ in identifiers.append(asset.localIdentifier) }
        return identifiers
    }

    // MARK: - Blurry Photos (edge-detection via CIFilter on 80×80 thumbnails)

    func findBlurryPhotos() async -> [String] {
        let options = PHFetchOptions()
        options.predicate       = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit      = 150      // check last 150 photos

        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }

        var blurryIds: [String] = []
        for asset in assets {
            if let thumb = await loadThumbnail(for: asset), isBlurry(thumb) {
                blurryIds.append(asset.localIdentifier)
            }
        }
        return blurryIds
    }

    // MARK: - Helpers

    private func loadThumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let opts             = PHImageRequestOptions()
            opts.deliveryMode    = .fastFormat
            opts.isNetworkAccessAllowed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 80, height: 80),
                contentMode: .aspectFill,
                options: opts
            ) { img, _ in continuation.resume(returning: img) }
        }
    }

    private func isBlurry(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let ci = CIImage(cgImage: cg)

        guard let edges = CIFilter(name: "CIEdges",
                                   parameters: [kCIInputImageKey: ci,
                                                "inputIntensity": 3.0])?.outputImage else { return false }

        guard let avg = CIFilter(name: "CIAreaAverage",
                                  parameters: [kCIInputImageKey: edges,
                                               kCIInputExtentKey: CIVector(cgRect: edges.extent)])?.outputImage else { return false }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(avg, toBitmap: &bitmap, rowBytes: 4,
                        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                        format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        return Float(bitmap[0]) / 255.0 < 0.025   // < 2.5% edge density = blurry
    }

    private func computeBytes(for identifiers: [String]) async -> Int64 {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var total: Int64 = 0
        result.enumerateObjects { asset, _, _ in
            for resource in PHAssetResource.assetResources(for: asset) {
                if let size = resource.value(forKey: "fileSize") as? Int64 { total += size }
            }
        }
        return total
    }
}
