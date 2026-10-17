// Ninety — document scanner (v6.69). Opens Apple's own document camera (the scanner in Notes / Files):
// edge detection, auto-capture, perspective correction, multi-page. Returns each page as base64 JPEG.
// JS: Capacitor.Plugins.NinetyScanner.scan({ quality: 0.75, maxSide: 2200 }) → { status: 'ok' | 'cancel', pages: [base64…] }
import Foundation
import UIKit
import VisionKit
import Capacitor

@objc(NinetyScannerPlugin)
public class NinetyScannerPlugin: CAPPlugin, CAPBridgedPlugin, VNDocumentCameraViewControllerDelegate {
    public let identifier = "NinetyScannerPlugin"
    public let jsName = "NinetyScanner"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "isAvailable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "scan", returnType: CAPPluginReturnPromise)
    ]
    private var pending: CAPPluginCall?
    private var quality: CGFloat = 0.75
    private var maxSide: CGFloat = 2200

    @objc func isAvailable(_ call: CAPPluginCall) {
        call.resolve(["available": VNDocumentCameraViewController.isSupported])
    }

    @objc func scan(_ call: CAPPluginCall) {
        guard VNDocumentCameraViewController.isSupported else { call.reject("unsupported"); return }
        quality = CGFloat(min(max(call.getDouble("quality") ?? 0.75, 0.3), 0.95))
        maxSide = CGFloat(min(max(call.getDouble("maxSide") ?? 2200, 800), 4000))
        DispatchQueue.main.async {
            if let old = self.pending { old.resolve(["status": "cancel", "pages": []]) }
            self.pending = call
            let vc = VNDocumentCameraViewController()
            vc.delegate = self
            vc.modalPresentationStyle = .fullScreen
            self.bridge?.viewController?.present(vc, animated: true)
        }
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        var pages: [String] = []
        for i in 0..<scan.pageCount {
            let img = resized(scan.imageOfPage(at: i))
            if let data = img.jpegData(compressionQuality: quality) { pages.append(data.base64EncodedString()) }
        }
        controller.dismiss(animated: true) {
            self.pending?.resolve(["status": "ok", "pages": pages])
            self.pending = nil
        }
    }

    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true) {
            self.pending?.resolve(["status": "cancel", "pages": []])
            self.pending = nil
        }
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true) {
            self.pending?.reject(error.localizedDescription)
            self.pending = nil
        }
    }

    private func resized(_ img: UIImage) -> UIImage {
        let s = img.size; let m = max(s.width, s.height)
        if m <= maxSide { return img }
        let r = maxSide / m; let ns = CGSize(width: floor(s.width * r), height: floor(s.height * r))
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: ns, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: ns)) }
    }
}
