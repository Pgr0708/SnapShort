//
//  VisionCacheStore.swift
//  SnapShort
//

import Foundation
import CoreData
import CoreGraphics
import os.log

enum RecordType: String, CaseIterable {
    case imageHash = "ImageHashRecord"
    case faceEmbedding = "FaceEmbeddingRecord"
    case contentTag = "ContentTagRecord"
    case ocrText = "OCRTextRecord"
}

struct ImageHashData {
    let assetLocalIdentifier: String
    let pHashValue: String
    let dHashValue: String
    let imageWidth: Int32
    let imageHeight: Int32
    let captureDate: Date?
}

struct OCRTextData {
    let assetLocalIdentifier: String
    let extractedText: String
    let textBoundingBoxes: Data
    let ocrConfidence: Float
}

struct ContentTagData {
    let assetLocalIdentifier: String
    let tags: String
    let tagConfidences: Data
}

struct FaceEmbeddingData {
    let assetLocalIdentifier: String
    let faceIndex: Int16
    let boundingBox: CGRect
    let embeddingVector: Data
    let embeddingModelVersion: String
    let faceQualityScore: Float
}

actor VisionCacheStore {
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.snapsort.vision", category: "store")
    
    init(container: NSPersistentContainer? = nil) {
        // CoreDataManager.nsPersistentContainer is an IUO; provide a local fallback
        // in case it hasn't finished loading yet (rare, only on cold launch race).
        let targetContainer: NSPersistentContainer
        if let supplied = container {
            targetContainer = supplied
        } else if let shared = CoreDataManager.shared.nsPersistentContainer {
            targetContainer = shared
        } else {
            // Fallback: create an in-memory store so the actor never crashes.
            let fallback = NSPersistentContainer(name: "GoViral")
            let desc = NSPersistentStoreDescription()
            desc.type = NSInMemoryStoreType
            fallback.persistentStoreDescriptions = [desc]
            fallback.loadPersistentStores { _, _ in }
            targetContainer = fallback
        }
        self.container = targetContainer
        self.context = targetContainer.newBackgroundContext()
        self.context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.context.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Image Hash
    
    func upsertImageHashes(_ records: [ImageHashData]) async throws {
        guard !records.isEmpty else { return }
        try await context.perform { [context] in
            for data in records {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: RecordType.imageHash.rawValue)
                fetchRequest.predicate = NSPredicate(format: "assetLocalIdentifier == %@", data.assetLocalIdentifier)
                fetchRequest.fetchLimit = 1
                
                let entity: NSManagedObject
                if let existing = try context.fetch(fetchRequest).first {
                    entity = existing
                } else {
                    entity = NSEntityDescription.insertNewObject(forEntityName: RecordType.imageHash.rawValue, into: context)
                }
                
                entity.setValue(data.assetLocalIdentifier, forKey: "assetLocalIdentifier")
                entity.setValue(data.pHashValue, forKey: "pHashValue")
                entity.setValue(data.dHashValue, forKey: "dHashValue")
                entity.setValue(data.imageWidth, forKey: "imageWidth")
                entity.setValue(data.imageHeight, forKey: "imageHeight")
                entity.setValue(data.captureDate, forKey: "captureDate")
                entity.setValue(Date(), forKey: "computedAt")
            }
            
            if context.hasChanges {
                try context.save()
            }
        }
        logger.info("Upserted \(records.count) image hash records")
    }
    
    func fetchImageHashes(identifiers: [String]) async -> [String: NSManagedObject] {
        guard !identifiers.isEmpty else { return [:] }
        return await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: RecordType.imageHash.rawValue)
            fetchRequest.predicate = NSPredicate(format: "assetLocalIdentifier IN %@", identifiers)
            
            do {
                let results = try context.fetch(fetchRequest)
                var dict: [String: NSManagedObject] = [:]
                for result in results {
                    if let id = result.value(forKey: "assetLocalIdentifier") as? String {
                        dict[id] = result
                    }
                }
                return dict
            } catch {
                self.logger.error("Failed to fetch image hashes: \(error.localizedDescription)")
                return [:]
            }
        }
    }
    
    // MARK: - OCR Text
    
    func upsertOCRTexts(_ records: [OCRTextData]) async throws {
        guard !records.isEmpty else { return }
        try await context.perform { [context] in
            for data in records {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: RecordType.ocrText.rawValue)
                fetchRequest.predicate = NSPredicate(format: "assetLocalIdentifier == %@", data.assetLocalIdentifier)
                fetchRequest.fetchLimit = 1
                
                let entity: NSManagedObject
                if let existing = try context.fetch(fetchRequest).first {
                    entity = existing
                } else {
                    entity = NSEntityDescription.insertNewObject(forEntityName: RecordType.ocrText.rawValue, into: context)
                }
                
                entity.setValue(data.assetLocalIdentifier, forKey: "assetLocalIdentifier")
                entity.setValue(data.extractedText, forKey: "extractedText")
                entity.setValue(data.textBoundingBoxes, forKey: "textBoundingBoxes")
                entity.setValue(data.ocrConfidence, forKey: "ocrConfidence")
                entity.setValue(Date(), forKey: "computedAt")
            }
            
            if context.hasChanges {
                try context.save()
            }
        }
        logger.info("Upserted \(records.count) OCR text records")
    }
    
    func fetchOCRTexts(identifiers: [String]) async -> [String: NSManagedObject] {
        guard !identifiers.isEmpty else { return [:] }
        return await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: RecordType.ocrText.rawValue)
            fetchRequest.predicate = NSPredicate(format: "assetLocalIdentifier IN %@", identifiers)
            
            do {
                let results = try context.fetch(fetchRequest)
                var dict: [String: NSManagedObject] = [:]
                for result in results {
                    if let id = result.value(forKey: "assetLocalIdentifier") as? String {
                        dict[id] = result
                    }
                }
                return dict
            } catch {
                self.logger.error("Failed to fetch OCR texts: \(error.localizedDescription)")
                return [:]
            }
        }
    }
    
    func searchOCR(query: String) async -> [(identifier: String, text: String, confidence: Float)] {
        let terms = query.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !terms.isEmpty else { return [] }
        
        return await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: RecordType.ocrText.rawValue)
            
            // Build AND predicate: each term must be contained
            let predicates = terms.map { term in
                NSPredicate(format: "extractedText CONTAINS[cd] %@", term)
            }
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            
            do {
                let results = try context.fetch(fetchRequest)
                return results.compactMap { result in
                    guard let id = result.value(forKey: "assetLocalIdentifier") as? String,
                          let text = result.value(forKey: "extractedText") as? String,
                          let confidence = result.value(forKey: "ocrConfidence") as? Float else {
                        return nil
                    }
                    return (identifier: id, text: text, confidence: confidence)
                }
            } catch {
                self.logger.error("Failed to search OCR: \(error.localizedDescription)")
                return []
            }
        }
    }
    
    // MARK: - Content Tags
    
    func upsertContentTags(_ records: [ContentTagData]) async throws {
        guard !records.isEmpty else { return }
        try await context.perform { [context] in
            for data in records {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: RecordType.contentTag.rawValue)
                fetchRequest.predicate = NSPredicate(format: "assetLocalIdentifier == %@", data.assetLocalIdentifier)
                fetchRequest.fetchLimit = 1
                
                let entity: NSManagedObject
                if let existing = try context.fetch(fetchRequest).first {
                    entity = existing
                } else {
                    entity = NSEntityDescription.insertNewObject(forEntityName: RecordType.contentTag.rawValue, into: context)
                }
                
                entity.setValue(data.assetLocalIdentifier, forKey: "assetLocalIdentifier")
                entity.setValue(data.tags, forKey: "tags")
                entity.setValue(data.tagConfidences, forKey: "tagConfidences")
                entity.setValue(Date(), forKey: "computedAt")
            }
            
            if context.hasChanges {
                try context.save()
            }
        }
        logger.info("Upserted \(records.count) content tag records")
    }
    
    func searchContentTags(query: String) async -> [(identifier: String, tags: String, confidence: Float)] {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        
        return await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: RecordType.contentTag.rawValue)
            fetchRequest.predicate = NSPredicate(format: "tags CONTAINS[cd] %@", normalized)
            
            do {
                let results = try context.fetch(fetchRequest)
                return results.compactMap { result in
                    guard let id = result.value(forKey: "assetLocalIdentifier") as? String,
                          let tags = result.value(forKey: "tags") as? String,
                          let confidencesData = result.value(forKey: "tagConfidences") as? Data else {
                        return nil
                    }
                    // Extract confidence for matched tag (simplified - use first confidence)
                    let confidences = confidencesData.withUnsafeBytes { buffer in
                        guard let base = buffer.baseAddress else { return [Float]() }
                        let count = buffer.count / MemoryLayout<Float>.size
                        return (0..<count).map { index in
                            base.load(fromByteOffset: index * MemoryLayout<Float>.size, as: Float.self)
                        }
                    }
                    let confidence = confidences.first ?? 0.0
                    return (identifier: id, tags: tags, confidence: confidence)
                }
            } catch {
                self.logger.error("Failed to search content tags: \(error.localizedDescription)")
                return []
            }
        }
    }
    
    // MARK: - Face Embeddings
    
    func upsertFaceEmbeddings(_ records: [FaceEmbeddingData]) async throws {
        guard !records.isEmpty else { return }
        try await context.perform { [context] in
            for data in records {
                let entity = NSEntityDescription.insertNewObject(forEntityName: RecordType.faceEmbedding.rawValue, into: context)
                
                entity.setValue(data.assetLocalIdentifier, forKey: "assetLocalIdentifier")
                entity.setValue(data.faceIndex, forKey: "faceIndex")
                entity.setValue(data.boundingBox.origin.x, forKey: "boundingBoxX")
                entity.setValue(data.boundingBox.origin.y, forKey: "boundingBoxY")
                entity.setValue(data.boundingBox.width, forKey: "boundingBoxWidth")
                entity.setValue(data.boundingBox.height, forKey: "boundingBoxHeight")
                entity.setValue(data.embeddingVector, forKey: "embeddingVector")
                entity.setValue(data.embeddingModelVersion, forKey: "embeddingModelVersion")
                entity.setValue(data.faceQualityScore, forKey: "faceQualityScore")
                entity.setValue(Date(), forKey: "computedAt")
            }
            
            if context.hasChanges {
                try context.save()
            }
        }
        logger.info("Upserted \(records.count) face embedding records")
    }
    
    // MARK: - Processed Identifiers (Delta Processing)
    
    func processedIdentifiers(for recordType: RecordType) async -> Set<String> {
        return await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: recordType.rawValue)
            fetchRequest.resultType = .dictionaryResultType
            fetchRequest.propertiesToFetch = ["assetLocalIdentifier"]
            fetchRequest.returnsDistinctResults = true
            
            do {
                let results = try context.fetch(fetchRequest) as? [[String: String]] ?? []
                return Set(results.compactMap { $0["assetLocalIdentifier"] })
            } catch {
                self.logger.error("Failed to fetch processed identifiers: \(error.localizedDescription)")
                return Set()
            }
        }
    }
    
    // MARK: - All Records (for duplicate detection)
    
    func fetchAllImageHashes() async -> [(identifier: String, pHash: String, dHash: String, width: Int, height: Int, date: Date?)] {
        return await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: RecordType.imageHash.rawValue)
            
            do {
                let results = try context.fetch(fetchRequest)
                return results.compactMap { result in
                    guard let id = result.value(forKey: "assetLocalIdentifier") as? String,
                          let pHash = result.value(forKey: "pHashValue") as? String,
                          let dHash = result.value(forKey: "dHashValue") as? String else {
                        return nil
                    }
                    let width = (result.value(forKey: "imageWidth") as? Int32).map(Int.init) ?? 0
                    let height = (result.value(forKey: "imageHeight") as? Int32).map(Int.init) ?? 0
                    let date = result.value(forKey: "captureDate") as? Date
                    return (identifier: id, pHash: pHash, dHash: dHash, width: width, height: height, date: date)
                }
            } catch {
                self.logger.error("Failed to fetch all image hashes: \(error.localizedDescription)")
                return []
            }
        }
    }
    
    /// Bulk fetch all OCR text records for SmartCategorizationService
    func fetchAllOCRRecords() async -> [(identifier: String, text: String)] {
        return await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: RecordType.ocrText.rawValue)
            do {
                let results = try context.fetch(fetchRequest)
                return results.compactMap { r in
                    guard let id = r.value(forKey: "assetLocalIdentifier") as? String,
                          let text = r.value(forKey: "extractedText") as? String else { return nil }
                    return (identifier: id, text: text)
                }
            } catch {
                self.logger.error("Failed to fetch all OCR records: \(error.localizedDescription)")
                return []
            }
        }
    }
    
    /// Bulk fetch all content tag records for SmartCategorizationService
    func fetchAllContentTagRecords() async -> [(identifier: String, tags: String)] {
        return await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: RecordType.contentTag.rawValue)
            do {
                let results = try context.fetch(fetchRequest)
                return results.compactMap { r in
                    guard let id = r.value(forKey: "assetLocalIdentifier") as? String,
                          let tags = r.value(forKey: "tags") as? String else { return nil }
                    return (identifier: id, tags: tags)
                }
            } catch {
                self.logger.error("Failed to fetch all content tags: \(error.localizedDescription)")
                return []
            }
        }
    }
    
    func deleteImageHashRecords(identifiers: [String]) async throws {
        guard !identifiers.isEmpty else { return }
        try await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: RecordType.imageHash.rawValue)
            fetchRequest.predicate = NSPredicate(format: "assetLocalIdentifier IN %@", identifiers)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDelete.resultType = .resultTypeStatusOnly
            try context.execute(batchDelete)
        }
    }
    
    func deleteOCRRecords(identifiers: [String]) async throws {
        guard !identifiers.isEmpty else { return }
        try await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: RecordType.ocrText.rawValue)
            fetchRequest.predicate = NSPredicate(format: "assetLocalIdentifier IN %@", identifiers)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDelete.resultType = .resultTypeStatusOnly
            try context.execute(batchDelete)
        }
    }
    
    /// Purges all references to deleted photo IDs across all Core Data entities (hashes, OCR, tags, embeddings, notes)
    func purgeDeletedAssets(identifiers: [String]) async {
        guard !identifiers.isEmpty else { return }
        let entityNames = [
            RecordType.imageHash.rawValue,
            RecordType.ocrText.rawValue,
            RecordType.contentTag.rawValue,
            RecordType.faceEmbedding.rawValue,
            "PhotoNoteRecord"
        ]
        
        await context.perform { [context] in
            for name in entityNames {
                let req = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                req.predicate = NSPredicate(format: "assetLocalIdentifier IN %@", identifiers)
                let batchDel = NSBatchDeleteRequest(fetchRequest: req)
                batchDel.resultType = .resultTypeStatusOnly
                _ = try? context.execute(batchDel)
            }
            if context.hasChanges { try? context.save() }
        }
        logger.info("Purged \(identifiers.count) deleted assets from all Core Data tables")
    }
    
    // MARK: - Photo Notes (User Descriptions + AI Captions)
    
    func savePhotoNote(assetId: String, userNote: String, aiCaption: String = "") async throws {
        try await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PhotoNoteRecord")
            fetchRequest.predicate = NSPredicate(format: "assetLocalIdentifier == %@", assetId)
            fetchRequest.fetchLimit = 1
            
            let entity: NSManagedObject
            if let existing = try context.fetch(fetchRequest).first {
                entity = existing
            } else {
                entity = NSEntityDescription.insertNewObject(forEntityName: "PhotoNoteRecord", into: context)
            }
            
            entity.setValue(assetId, forKey: "assetLocalIdentifier")
            entity.setValue(userNote, forKey: "userNote")
            entity.setValue(aiCaption, forKey: "aiCaption")
            entity.setValue(Date(), forKey: "updatedAt")
            
            if context.hasChanges { try context.save() }
        }
        logger.info("Saved note for asset \(assetId)")
    }
    
    func fetchPhotoNote(for assetId: String) async -> (userNote: String, aiCaption: String) {
        return await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PhotoNoteRecord")
            fetchRequest.predicate = NSPredicate(format: "assetLocalIdentifier == %@", assetId)
            fetchRequest.fetchLimit = 1
            
            guard let record = try? context.fetch(fetchRequest).first else {
                return (userNote: "", aiCaption: "")
            }
            let note = record.value(forKey: "userNote") as? String ?? ""
            let caption = record.value(forKey: "aiCaption") as? String ?? ""
            return (userNote: note, aiCaption: caption)
        }
    }
    
    func searchPhotoNotes(query: String) async -> [(identifier: String, matchedNote: String)] {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        
        return await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "PhotoNoteRecord")
            fetchRequest.predicate = NSPredicate(
                format: "userNote CONTAINS[cd] %@ OR aiCaption CONTAINS[cd] %@",
                normalized, normalized
            )
            do {
                let results = try context.fetch(fetchRequest)
                return results.compactMap { r in
                    guard let id = r.value(forKey: "assetLocalIdentifier") as? String else { return nil }
                    let note = r.value(forKey: "userNote") as? String ?? ""
                    let caption = r.value(forKey: "aiCaption") as? String ?? ""
                    let matched = note.isEmpty ? caption : note
                    return (identifier: id, matchedNote: matched)
                }
            } catch {
                self.logger.error("Failed to search photo notes: \(error.localizedDescription)")
                return []
            }
        }
    }
    
    // MARK: - User Categories (Custom Categories)
    
    func saveUserCategory(
        id: String, name: String, iconName: String,
        colorHex: String, keywords: String
    ) async throws {
        try await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserCategoryRecord")
            fetchRequest.predicate = NSPredicate(format: "categoryId == %@", id)
            fetchRequest.fetchLimit = 1
            
            let entity: NSManagedObject
            if let existing = try context.fetch(fetchRequest).first {
                entity = existing
            } else {
                entity = NSEntityDescription.insertNewObject(forEntityName: "UserCategoryRecord", into: context)
                entity.setValue(Date(), forKey: "createdAt")
            }
            
            entity.setValue(id, forKey: "categoryId")
            entity.setValue(name, forKey: "name")
            entity.setValue(iconName, forKey: "iconName")
            entity.setValue(colorHex, forKey: "colorHex")
            entity.setValue(keywords, forKey: "keywords")
            
            if context.hasChanges { try context.save() }
        }
        logger.info("Saved user category: \(name)")
    }
    
    func fetchAllUserCategories() async -> [(id: String, name: String, iconName: String, colorHex: String, keywords: String)] {
        return await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserCategoryRecord")
            let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: true)
            fetchRequest.sortDescriptors = [sortDescriptor]
            
            do {
                let results = try context.fetch(fetchRequest)
                return results.compactMap { r in
                    guard let id = r.value(forKey: "categoryId") as? String,
                          let name = r.value(forKey: "name") as? String else { return nil }
                    let icon = r.value(forKey: "iconName") as? String ?? "folder.fill"
                    let color = r.value(forKey: "colorHex") as? String ?? "#4A5FE8"
                    let keywords = r.value(forKey: "keywords") as? String ?? ""
                    return (id: id, name: name, iconName: icon, colorHex: color, keywords: keywords)
                }
            } catch {
                self.logger.error("Failed to fetch user categories: \(error.localizedDescription)")
                return []
            }
        }
    }
    
    func deleteUserCategory(id: String) async throws {
        try await context.perform { [context] in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "UserCategoryRecord")
            fetchRequest.predicate = NSPredicate(format: "categoryId == %@", id)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDelete.resultType = .resultTypeStatusOnly
            try context.execute(batchDelete)
        }
        logger.info("Deleted user category: \(id)")
    }
}
