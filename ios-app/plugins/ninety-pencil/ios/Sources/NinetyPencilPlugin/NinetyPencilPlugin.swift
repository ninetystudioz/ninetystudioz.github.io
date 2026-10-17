// Ninety — Apple Pencil double-tap (Pencil 2 / Pro) and squeeze (Pencil Pro) for the iPad app (v7.48, note 5).
// The web page decides what they do (Concept: the wheel at the pen tip, eraser, last tool or undo — «Pen settings»).
// Each gesture reaches the page as a window event:  window.addEventListener('nfpencil', e => e.kind / e.x / e.y)
//   kind: 'tap' | 'squeeze';  x / y: where the pen hovers (web view points = CSS pixels) when the iPad knows it (iOS 17.5+).
// The person's own iPad setting is respected: a double-tap set to «Ignore» in Settings → Apple Pencil is not sent.
// JS (optional): Capacitor.Plugins.NinetyPencil.info() → { available, pencilOnly }
import Foundation
import UIKit
import Capacitor

@objc(NinetyPencilPlugin)
public class NinetyPencilPlugin: CAPPlugin, CAPBridgedPlugin, UIPencilInteractionDelegate {
    public let identifier = "NinetyPencilPlugin"
    public let jsName = "NinetyPencil"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "info", returnType: CAPPluginReturnPromise)
    ]
    private var interaction: UIPencilInteraction?

    override public func load() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let view = self.bridge?.webView else { return }
            let i = UIPencilInteraction()
            i.delegate = self
            view.addInteraction(i)
            self.interaction = i
        }
    }

    @objc func info(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            var only = false
            if #available(iOS 14.0, *) { only = UIPencilInteraction.prefersPencilOnlyDrawing }
            call.resolve(["available": UIDevice.current.userInterfaceIdiom == .pad, "pencilOnly": only])
        }
    }

    // iOS 12.1 – 17.4: the double-tap
    public func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        if UIPencilInteraction.preferredTapAction == .ignore { return }
        send("tap", nil)
    }

    // iOS 17.5+: the double-tap with the hover point, and the squeeze (Apple Pencil Pro)
    @available(iOS 17.5, *)
    public func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        if UIPencilInteraction.preferredTapAction == .ignore { return }
        send("tap", tap.hoverPose?.location)
    }

    @available(iOS 17.5, *)
    public func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        guard squeeze.phase == .ended else { return }
        send("squeeze", squeeze.hoverPose?.location)
    }

    private func send(_ kind: String, _ loc: CGPoint?) {
        var data: [String: Any] = ["kind": kind]
        var js = "{\"kind\":\"\(kind)\""
        if let p = loc, p.x.isFinite, p.y.isFinite {
            data["x"] = Double(p.x); data["y"] = Double(p.y)
            js += String(format: ",\"x\":%.1f,\"y\":%.1f", Double(p.x), Double(p.y))
        }
        js += "}"
        notifyListeners("pencil", data: data)
        DispatchQueue.main.async { [weak self] in self?.bridge?.triggerWindowJSEvent(eventName: "nfpencil", data: js) }
    }
}
