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
final class PhotoLibraryManager: ObservableObject {

    @Published private(set) var assets: PHFetchResult<PHAsset>?

    func fetchPhotos() {

    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    guard status == .authorized || status == .limited else {
        assets = nil
        return
    }

    let options = PHFetchOptions()

    options.sortDescriptors = [
        NSSortDescriptor(
            key: "modificationDate",
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
