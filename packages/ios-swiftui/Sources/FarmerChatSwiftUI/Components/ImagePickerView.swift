import SwiftUI
import PhotosUI
import UIKit

// MARK: - PHPicker wrapper (gallery)

struct PHImagePicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImagePicked: onImagePicked) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagePicked: (UIImage?) -> Void
        init(onImagePicked: @escaping (UIImage?) -> Void) { self.onImagePicked = onImagePicked }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                onImagePicked(nil); return
            }
            provider.loadObject(ofClass: UIImage.self) { obj, _ in
                DispatchQueue.main.async { self.onImagePicked(obj as? UIImage) }
            }
        }
    }
}

// MARK: - UIImagePicker wrapper (camera)

struct CameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImagePicked: onImagePicked) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage?) -> Void
        init(onImagePicked: @escaping (UIImage?) -> Void) { self.onImagePicked = onImagePicked }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            onImagePicked(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onImagePicked(nil)
        }
    }
}

// MARK: - Image source bottom sheet

struct ImageSourceSheet: View {
    var onCamera: () -> Void
    var onGallery: () -> Void
    var onCancel: () -> Void

    private let darkCard = Color(red: 0.09, green: 0.18, blue: 0.08)
    private let green = Color(red: 0.18, green: 0.49, blue: 0.20)
    private let textPrimary = Color(red: 0.9, green: 0.97, blue: 0.9)
    private let textSecondary = Color(red: 0.67, green: 0.78, blue: 0.68)

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("Add Image")
                .font(.headline)
                .foregroundColor(textPrimary)
            Text("Photograph your crop for analysis")
                .font(.caption)
                .foregroundColor(textSecondary)
                .padding(.bottom, 20)

            VStack(spacing: 0) {
                ImageSourceRow(icon: "camera.fill", title: "Take Photo",
                               subtitle: "Use your camera to capture the crop",
                               green: green, textPrimary: textPrimary, textSecondary: textSecondary,
                               action: onCamera)
                Divider().background(Color.white.opacity(0.1))
                ImageSourceRow(icon: "photo.on.rectangle", title: "Choose from Gallery",
                               subtitle: "Select an existing photo",
                               green: green, textPrimary: textPrimary, textSecondary: textSecondary,
                               action: onGallery)
            }
            .background(darkCard)
            .cornerRadius(16)
            .padding(.bottom, 12)

            Button("Cancel") { onCancel() }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(textSecondary)
        }
        .padding(.horizontal, 20)
        .background(Color(red: 0.08, green: 0.14, blue: 0.09))
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}

private struct ImageSourceRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let green: Color
    let textPrimary: Color
    let textSecondary: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(green)
                    .frame(width: 48, height: 48)
                    .background(green.opacity(0.15))
                    .cornerRadius(12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold()).foregroundColor(textPrimary)
                    Text(subtitle).font(.caption).foregroundColor(textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - UIImage → base64 JPEG helper

extension UIImage {
    func toBase64Jpeg(quality: CGFloat = 0.8) -> String? {
        jpegData(compressionQuality: quality).map { $0.base64EncodedString() }
    }
}
