//
//  PhotoDetailView.swift
//  SnapShort
//

import SwiftUI
import Photos

struct PhotoDetailView: View {
    let asset: PHAsset
    @Environment(\.dismiss) private var dismiss
    
    @State private var fullImage: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showInfo: Bool = false
    @State private var shareImage: UIImage?
    @State private var showShareSheet: Bool = false
    
    private var dateText: String {
        guard let date = asset.creationDate else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var sizeText: String {
        "\(asset.pixelWidth) × \(asset.pixelHeight)"
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // MARK: - Main Image
            Group {
                if let fullImage {
                    Image(uiImage: fullImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1 {
                                        withAnimation(.spring()) {
                                            scale = 1
                                            offset = .zero
                                        }
                                        lastScale = 1
                                        lastOffset = .zero
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    guard scale > 1 else { return }
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1 {
                                    scale = 1
                                    offset = .zero
                                    lastScale = 1
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                } else {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
            
            // MARK: - Top Toolbar
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button {
                            showInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        
                        if let fullImage {
                            Button {
                                shareImage = fullImage
                                showShareSheet = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // MARK: - Info Panel
                if showInfo {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(icon: "calendar", label: "Date", value: dateText)
                        InfoRow(icon: "photo", label: "Resolution", value: sizeText)
                        if asset.mediaSubtypes.contains(.photoScreenshot) {
                            InfoRow(icon: "iphone", label: "Type", value: "Screenshot")
                        }
                        if let location = asset.location {
                            InfoRow(
                                icon: "location",
                                label: "Location",
                                value: String(format: "%.4f, %.4f",
                                              location.coordinate.latitude,
                                              location.coordinate.longitude)
                            )
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: showInfo)
        }
        .task {
            loadFullImage()
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareImage {
                ShareSheet(items: [shareImage])
                    .ignoresSafeArea()
            }
        }
    }
    
    private func loadFullImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            if let image {
                DispatchQueue.main.async {
                    self.fullImage = image
                }
            }
        }
    }
}

// MARK: - InfoRow

private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
