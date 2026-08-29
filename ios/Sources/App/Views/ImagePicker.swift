import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let pc = UIImagePickerController()
        pc.sourceType = .photoLibrary
        pc.delegate = context.coordinator
        return pc
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController,
                                  didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onPick(img)
            }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
