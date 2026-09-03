//
//  PhotoLibraryManager.swift
//  SnapShort
//
//  Created by Minaxi on 01/09/26.
//

import Foundation
import Photos
import UIKit
internal import Combine

@MainActor
final class PhotoLibraryManager: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {

    @Published private(set) var assets: PHFetchResult<PHAsset>?
    
    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    // MARK: - PhotoKit Change Observer
    
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard let current = self.assets,
                  let details = changeInstance.changeDetails(for: current) else {
                // If library had empty assets or structure reset, re-fetch
                self.fetchPhotos()
                return
            }
            self.assets = details.fetchResultAfterChanges
            print("PhotoLibraryManager: observed library change, new count: \(self.assets?.count ?? 0)")
        }
    }
    
    /// Override the current fetch result (e.g. to show only screenshots or favorites).
    func setAssets(_ result: PHFetchResult<PHAsset>) {
        assets = result
    }

    func fetchPhotos() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        guard status == .authorized || status == .limited else {
            assets = nil
            return
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(
                key: "creationDate",
                ascending: false
            )
        ]

        assets = PHAsset.fetchAssets(
            with: .image,
            options: options
        )

        print("Photos available:", assets?.count ?? 0)
    }
    
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
}
