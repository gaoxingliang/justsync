import Foundation
import Photos
import UIKit
import CoreLocation
import AVFoundation
import UniformTypeIdentifiers

class PhotoLibraryManager: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published var photoCount = 0
    @Published var videoCount = 0
    @Published var totalCount = 0
    @Published var hasPermission = false
    
    private var allAssets: [PHAsset] = []
    
    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task {
            await loadPhotos()
        }
    }
    
    func requestPermission() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.hasPermission = status == .authorized || status == .limited
        }
    }
    
    func loadPhotos() async {
        let photoOptions = PHFetchOptions()
        photoOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let imgCount = PHAsset.fetchAssets(with: photoOptions).count
        
        let videoOptions = PHFetchOptions()
        videoOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.video.rawValue)
        let vidCount = PHAsset.fetchAssets(with: videoOptions).count
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let allPhotosResult = PHAsset.fetchAssets(with: fetchOptions)
        
        // Enumerate assets in a background task to prevent blocking the main thread / cooperative pool
        let assets = await Task.detached(priority: .userInitiated) { () -> [PHAsset] in
            var tempAssets: [PHAsset] = []
            tempAssets.reserveCapacity(allPhotosResult.count)
            allPhotosResult.enumerateObjects { asset, _, _ in
                tempAssets.append(asset)
            }
            return tempAssets
        }.value
        
        await MainActor.run {
            self.allAssets = assets
            self.photoCount = imgCount
            self.videoCount = vidCount
            self.totalCount = assets.count
        }
    }
    
    func getAllAssets() -> [PHAsset] {
        return allAssets
    }
    
    func getAsset(by identifier: String) -> PHAsset? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return fetchResult.firstObject
    }
    
    func getAssetMetadata(asset: PHAsset) -> [String: Any] {
        var metadata: [String: Any] = [
            "identifier": asset.localIdentifier,
            "mediaType": asset.mediaType == .image ? "image" : "video",
            "creationDate": asset.creationDate?.timeIntervalSince1970 ?? 0,
            "modificationDate": asset.modificationDate?.timeIntervalSince1970 ?? 0,
            "pixelWidth": asset.pixelWidth,
            "pixelHeight": asset.pixelHeight,
            "duration": asset.duration,
            "isFavorite": asset.isFavorite,
            "isHidden": asset.isHidden
        ]
        
        if let location = asset.location {
            metadata["location"] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "altitude": location.altitude
            ]
        }
        
        var subtypes: [String] = []
        if asset.mediaSubtypes.contains(.photoLive) {
            subtypes.append("live")
        }
        if asset.mediaSubtypes.contains(.photoScreenshot) {
            subtypes.append("screenshot")
        }
        if asset.mediaSubtypes.contains(.photoDepthEffect) {
            subtypes.append("portrait")
        }
        if asset.mediaSubtypes.contains(.photoPanorama) {
            subtypes.append("panorama")
        }
        if asset.mediaSubtypes.contains(.photoHDR) {
            subtypes.append("hdr")
        }
        if !subtypes.isEmpty {
            metadata["subtypes"] = subtypes
        }
        
        return metadata
    }
    
    func getImageData(asset: PHAsset, completion: @escaping (Data?, String, [String: Any]?) -> Void) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current
        
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, orientation, info in
            var mimeType = "image/jpeg"
            if let uti = dataUTI, let utType = UTType(uti) {
                mimeType = utType.preferredMIMEType ?? "image/jpeg"
            }
            
            var finalData = data
            var finalMimeType = mimeType
            
            // If the image is HEIC/HEIF, convert it to JPEG since browsers do not support HEIC/HEIF
            if let data = data, (mimeType.contains("heic") || mimeType.contains("heif")) {
                if let image = UIImage(data: data) {
                    if let jpegData = image.jpegData(compressionQuality: 0.9) {
                        finalData = jpegData
                        finalMimeType = "image/jpeg"
                    }
                }
            }
            
            var exifMetadata: [String: Any]?
            if let data = data,
               let source = CGImageSourceCreateWithData(data as CFData, nil),
               let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                exifMetadata = imageProperties
            }
            
            completion(finalData, finalMimeType, exifMetadata)
        }
    }
    
    func getVideoData(asset: PHAsset, completion: @escaping (URL?) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            if let urlAsset = avAsset as? AVURLAsset {
                completion(urlAsset.url)
            } else {
                completion(nil)
            }
        }
    }
    
    func getThumbnail(asset: PHAsset, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        options.version = .current

        let maxPixelSize = max(size.width, size.height)
        let targetSize = CGSize(
            width: min(CGFloat(asset.pixelWidth), maxPixelSize),
            height: min(CGFloat(asset.pixelHeight), maxPixelSize)
        )
        
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
            completion(image)
        }
    }
    
    func deleteAssets(identifiers: [String], completion: @escaping (Bool, Error?) -> Void) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(fetchResult)
        }) { success, error in
            if success {
                Task {
                    await self.loadPhotos()
                }
            }
            completion(success, error)
        }
    }
}
