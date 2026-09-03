//
//  SmartCategorizationService.swift
//  SnapShort
//

import Foundation
import Photos
import os.log

// MARK: - Protocol

protocol SmartCategorizationServicing {
    func categorizeLibrary() async -> [String: [String]]
    func getCategoryCounts() async -> [String: Int]
    func fetchAssets(for category: SmartCategory) async -> [String]
    func getAllCategories() async -> [SmartCategory]
    func addUserCategory(name: String, icon: String, colorHex: String, keywords: [String]) async throws
    func deleteUserCategory(id: String) async throws
    func invalidateCache() async
}

// MARK: - Service

actor SmartCategorizationService: SmartCategorizationServicing {
    private let visionStore: VisionCacheStore
    private let logger = Logger(subsystem: "com.snapsort.vision", category: "categories")
    
    // Cache: built at runtime, re-computed when library changes
    private var categoryAssetMap: [String: Set<String>] = [:]
    private var lastBuiltAt: Date?
    
    init(visionStore: VisionCacheStore) {
        self.visionStore = visionStore
    }
    
    // MARK: - Build Category Index
    
    /// Scans all cached OCR + Vision tags and assigns each asset to matching categories.
    func categorizeLibrary() async -> [String: [String]] {
        logger.info("Starting smart categorization…")
        
        // 1. Fetch all cached OCR records
        let ocrRecords = await visionStore.fetchAllOCRRecords()
        // 2. Fetch all cached content tag records
        let tagRecords = await visionStore.fetchAllContentTagRecords()
        // 3. Fetch screenshot metadata from Photos
        let screenshotIds = fetchScreenshotIdentifiers()
        // 4. Fetch all custom category keywords
        let customCategories = await buildCustomCategories()
        
        var result: [String: Set<String>] = [:]
        
        // Build lookup: assetId → ocrText
        var ocrByAsset: [String: String] = [:]
        for r in ocrRecords { ocrByAsset[r.identifier] = r.text.lowercased() }
        
        // Build lookup: assetId → tags
        var tagsByAsset: [String: String] = [:]
        for r in tagRecords { tagsByAsset[r.identifier] = r.tags.lowercased() }
        
        let allAssets = Set(ocrByAsset.keys).union(Set(tagsByAsset.keys)).union(screenshotIds)
        let allCategories = SmartCategory.presets + customCategories
        
        for assetId in allAssets {
            let ocrText = ocrByAsset[assetId] ?? ""
            let tags = tagsByAsset[assetId] ?? ""
            let isScreenshot = screenshotIds.contains(assetId)
            
            for category in allCategories {
                if matches(assetId: assetId, ocrText: ocrText, tags: tags,
                           isScreenshot: isScreenshot, category: category) {
                    result[category.id, default: []].insert(assetId)
                }
            }
        }
        
        self.categoryAssetMap = result
        self.lastBuiltAt = Date()
        
        var output: [String: [String]] = [:]
        for (key, set) in result { output[key] = Array(set) }
        logger.info("Categorization complete: \(result.count) categories matched")
        return output
    }
    
    func getCategoryCounts() async -> [String: Int] {
        if categoryAssetMap.isEmpty { _ = await categorizeLibrary() }
        return categoryAssetMap.mapValues { $0.count }
    }
    
    func fetchAssets(for category: SmartCategory) async -> [String] {
        if categoryAssetMap.isEmpty { _ = await categorizeLibrary() }
        return Array(categoryAssetMap[category.id] ?? [])
    }
    
    func getAllCategories() async -> [SmartCategory] {
        let counts = await getCategoryCounts()
        let customCategories = await buildCustomCategories()
        
        var all = SmartCategory.presets.map { cat in
            var updated = cat
            updated = SmartCategory(
                id: cat.id, name: cat.name, emoji: cat.emoji, icon: cat.icon,
                colorHex: cat.colorHex, group: cat.group,
                visionTags: cat.visionTags, ocrKeywords: cat.ocrKeywords,
                isCustom: false, photoCount: counts[cat.id] ?? 0
            )
            return updated
        }
        let custom = customCategories.map { cat in
            SmartCategory(
                id: cat.id, name: cat.name, emoji: cat.emoji, icon: cat.icon,
                colorHex: cat.colorHex, group: cat.group,
                visionTags: cat.visionTags, ocrKeywords: cat.ocrKeywords,
                isCustom: true, photoCount: counts[cat.id] ?? 0
            )
        }
        all.append(contentsOf: custom)
        return all
    }
    
    func addUserCategory(name: String, icon: String, colorHex: String, keywords: [String]) async throws {
        let id = "custom_\(UUID().uuidString)"
        let keywordsString = keywords.joined(separator: ",")
        try await visionStore.saveUserCategory(id: id, name: name, iconName: icon, colorHex: colorHex, keywords: keywordsString)
        // Invalidate cache so next call to getCategoryCounts re-builds
        categoryAssetMap = [:]
        lastBuiltAt = nil
        logger.info("Added custom category: \(name)")
    }
    
    func deleteUserCategory(id: String) async throws {
        try await visionStore.deleteUserCategory(id: id)
        categoryAssetMap[id] = nil
        logger.info("Deleted custom category: \(id)")
    }
    
    func invalidateCache() async {
        categoryAssetMap = [:]
        lastBuiltAt = nil
    }
    
    // MARK: - Private Helpers
    
    private func matches(assetId: String, ocrText: String, tags: String,
                         isScreenshot: Bool, category: SmartCategory) -> Bool {
        // Special: screenshot metadata flag
        if category.id == "app_screenshots" && isScreenshot { return true }
        
        // Vision tag matching (OR logic)
        let tagMatched = category.visionTags.contains { tag in
            tags.contains(tag)
        }
        if tagMatched { return true }
        
        // OCR keyword matching (OR logic, case-insensitive)
        guard !ocrText.isEmpty else { return false }
        let ocrMatched = category.ocrKeywords.contains { keyword in
            ocrText.contains(keyword.lowercased())
        }
        return ocrMatched
    }
    
    private func fetchScreenshotIdentifiers() -> Set<String> {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var ids = Set<String>()
        result.enumerateObjects { asset, _, _ in ids.insert(asset.localIdentifier) }
        return ids
    }
    
    private func buildCustomCategories() async -> [SmartCategory] {
        let rawCategories = await visionStore.fetchAllUserCategories()
        return rawCategories.map { raw in
            let keywords = raw.keywords.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return SmartCategory.custom(
                id: raw.id, name: raw.name,
                icon: raw.iconName, colorHex: raw.colorHex,
                keywords: keywords
            )
        }
    }
}
