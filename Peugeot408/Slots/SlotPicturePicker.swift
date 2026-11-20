import CarKit
import ImageIO
import PhotosUI
import SwiftUI
import UIKit

/// Turns a picked picture into a slot picture: at most 800 px, transparency kept, empty
/// transparent margins trimmed (so the subject fills the space), saved in the App Group.
enum SlotPicture {
    static let folder = "slot-images"
    static let maxPixelSize = 800

    /// Saves PNG/JPEG data under `slot-images/` and returns the relative path.
    static func save(_ data: Data, ext: String, name: String = UUID().uuidString) throws -> String {
        let directory = AppGroup.containerURL.appending(path: folder, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let relative = "\(folder)/\(name).\(ext)"
        try data.write(to: AppGroup.containerURL.appending(path: relative, directoryHint: .notDirectory), options: .atomic)
        return relative
    }

    /// Downsamples, trims transparent margins, and returns (data, file extension).
    static func process(_ data: Data) -> (Data, String)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
              ] as CFDictionary) else { return nil }
        let hasAlpha = ![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo)
        if hasAlpha {
            let trimmed = trimTransparent(image) ?? image
            return UIImage(cgImage: trimmed).pngData().map { ($0, "png") }
        }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.85).map { ($0, "jpg") }
    }

    /// Crops to the pixels that aren't (nearly) transparent.
    static func trimTransparent(_ image: CGImage) -> CGImage? {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 12 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        // Memory row 0 is the image's top row (see CarCutout.opaqueBounds).
        return image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
    }
}

/// None · My Car (live) · built-in photos · Upload.
struct SlotPicturePicker: View {
    @Environment(StudioModel.self) private var studio
    @Binding var imageFile: String?
    /// Centre picture: the first option is "None" instead of "Icon".
    var allowsNone = false
    @State private var picked: PhotosPickerItem?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    option(label: allowsNone ? "None" : "Icon", selected: imageFile == nil) {
                        Image(systemName: allowsNone ? "nosign" : "star.square").font(.title2).foregroundStyle(Theme.secondaryText)
                    } action: { imageFile = nil }

                    option(label: "My Car", selected: imageFile == SlotDesign.myCarImageFile) {
                        thumbnail(AppGroup.containerURL.appending(path: SlotDesign.myCarImageFile, directoryHint: .notDirectory))
                    } action: { imageFile = SlotDesign.myCarImageFile }

                    ForEach(BuiltInCarPhoto.all) { photo in
                        option(label: photo.name, selected: imageFile == builtInPath(photo)) {
                            thumbnail(photo.url)
                        } action: { useBuiltIn(photo) }
                    }

                    PhotosPicker(selection: $picked, matching: .images) {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.badge.plus")
                                .font(.title2)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 84, height: 60)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text("Upload").font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            if let message {
                Text(message).font(.footnote).foregroundStyle(Theme.secondaryText)
            }
        }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
    }

    private func option<Thumb: View>(label: String, selected: Bool, @ViewBuilder thumb: () -> Thumb, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                thumb()
                    .frame(width: 84, height: 60)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(selected ? Theme.accent : .clear, lineWidth: 2))
                Text(label).font(.caption).lineLimit(1)
            }
            .frame(width: 88)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Picture: \(label)")
    }

    @ViewBuilder
    private func thumbnail(_ url: URL?) -> some View {
        if let url, let image = UIImage(contentsOfFile: url.path(percentEncoded: false)) {
            Image(uiImage: image).resizable().scaledToFit().padding(4)
        } else {
            Image(systemName: "car.side").foregroundStyle(Theme.secondaryText)
        }
    }

    private func builtInPath(_ photo: BuiltInCarPhoto) -> String {
        "\(SlotPicture.folder)/builtin-\(photo.id).png"
    }

    /// The built-in photo in its original colours (spec: whatever paint is picked), with your plate.
    private func useBuiltIn(_ photo: BuiltInCarPhoto) {
        let state = studio.state
        guard let png = CarPhotoRenderer.render(photo, paintHex: nil, plate: state.plateText, font: state.plateFont ?? .classic),
              let path = try? SlotPicture.save(png, ext: "png", name: "builtin-\(photo.id)") else {
            message = "Couldn't prepare that photo."
            return
        }
        imageFile = path
        message = nil
    }

    private func upload(_ item: PhotosPickerItem) async {
        defer { picked = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let result = SlotPicture.process(data),
              let path = try? SlotPicture.save(result.0, ext: result.1) else {
            message = "Couldn't use that picture."
            return
        }
        imageFile = path
        message = result.1 == "png" ? "Transparent edges trimmed so the picture fills the slot." : nil
    }
}
