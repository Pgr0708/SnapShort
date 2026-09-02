//
//  HelperFunctions.swift
//  SnapShort
//
//  Created by Minaxi on 01/09/26.
//

import Foundation
import Photos
import SwiftUI

struct HelperFunctions {
    
    static func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        completion: @escaping (UIImage?) -> Void
    ) {

        let options = PHImageRequestOptions()

        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in

            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    static func saveToDocuments(image: UIImage, name: String) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalFileName = cleanedName.isEmpty ? "image" : cleanedName
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent("\(finalFileName).jpg")
        
        do {
            try data.write(to: fileURL)
            print("Saved successfully to: \(fileURL.path)")
        } catch {
            print("Error saving image to documents: \(error.localizedDescription)")
        }
    }

    // Option B: Save to User's Photos Library (Camera Roll)
    static func saveToPhotoLibrary(image: UIImage) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            if success {
                DispatchQueue.main.async {
                    print("Image saved to Photo Library")
                }
            } else if let error {
                print("Error saving to photo library: \(error.localizedDescription)")
            }
        }
    }
}
