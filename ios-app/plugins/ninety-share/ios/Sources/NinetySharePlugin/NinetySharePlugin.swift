// Ninety — share sheet bridge (v7.57). iPhone: the web app hands the share extension what it needs (server address, a device
// token, the person's recent tasks) through a keychain item shared by the app and its extension (same team, access group
// app.ninety.shared). Android: the app receives «Share» intents (images / PDF) and the web page takes the files with take().
// JS: Capacitor.Plugins.NinetyShare.setContext({ ctx: '<json>' }) · .clear()
// v9.71 iPhone «افتح في Ninety»: the extension leaves the shared files in the same keychain group (manifest «inbox» + one item
// «inbox.N» per file) and opens app.ninety.fabrication://share. take() hands them to the page in the Android shape
// { files: [{ name, mime, data (base64) }], text } and forgets them; has() → { n, at } without taking. When the app is opened
// (by that link or by hand) and files are waiting, the window event «nfshare» fires (as on Android).
import Foundation
import UIKit
import Security
import Capacitor

@objc(NinetySharePlugin)
public class NinetySharePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NinetySharePlugin"
    public let jsName = "NinetyShare"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "setContext", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "clear", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "take", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "has", returnType: CAPPluginReturnPromise)
    ]
    static let group = "UF4QLJ9AY9.app.ninety.shared"
    static let service = "app.ninety.share"
    static let scheme = "app.ninety.fabrication"
    static let maxAgeMs: Double = 6 * 3600 * 1000
    static func base(_ account: String = "ctx") -> [String: Any] {
        return [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecAttrAccessGroup as String: group]
    }
    private var lastFire: Date = .distantPast

    override public func load() {
        NotificationCenter.default.addObserver(self, selector: #selector(onOpenURL(_:)), name: .capacitorOpenURL, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc func setContext(_ call: CAPPluginCall) {
        guard let s = call.getString("ctx"), let data = s.data(using: .utf8) else { call.reject("ctx missing"); return }
        let q = NinetySharePlugin.base()
        let attrs: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        var st = SecItemUpdate(q as CFDictionary, attrs as CFDictionary)
        if st == errSecItemNotFound {
            var add = q
            for (k, v) in attrs { add[k] = v }
            st = SecItemAdd(add as CFDictionary, nil)
        }
        if st == errSecSuccess { call.resolve(["ok": true]) } else { call.reject("keychain \(st)") }
    }

    @objc func clear(_ call: CAPPluginCall) {
        SecItemDelete(NinetySharePlugin.base() as CFDictionary)
        NinetySharePlugin.clearInbox()   // v9.71: a signed-out phone keeps no shared picture either
        call.resolve(["ok": true])
    }

    // MARK: v9.71 inbox (files shared with «افتح في Ninety»)
    static func read(_ account: String) -> Data? {
        var q = base(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }
    static func clearInbox() {
        SecItemDelete(base("inbox") as CFDictionary)
        for i in 0..<10 { SecItemDelete(base("inbox.\(i)") as CFDictionary) }
    }
    static func manifest() -> [String: Any]? {
        guard let d = read("inbox"), let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { return nil }
        let at = (o["at"] as? Double) ?? 0
        if Date().timeIntervalSince1970 * 1000 - at > maxAgeMs { clearInbox(); return nil }   // left over from long ago
        return o
    }

    @objc func has(_ call: CAPPluginCall) {
        let m = NinetySharePlugin.manifest()
        let n = (m?["files"] as? [Any])?.count ?? 0
        let text = (m?["text"] as? String) ?? ""
        call.resolve(["n": (n > 0 || !text.isEmpty) ? max(n, 1) : 0, "at": (m?["at"] as? Double) ?? 0])
    }

    @objc func take(_ call: CAPPluginCall) {
        DispatchQueue.global(qos: .userInitiated).async {
            var files: [[String: Any]] = []
            var text = ""
            if let m = NinetySharePlugin.manifest() {
                text = (m["text"] as? String) ?? ""
                for f in (m["files"] as? [[String: Any]]) ?? [] {
                    guard let key = f["key"] as? String, key.hasPrefix("inbox."), let d = NinetySharePlugin.read(key) else { continue }
                    files.append(["name": (f["name"] as? String) ?? "photo.jpg", "mime": (f["mime"] as? String) ?? "image/jpeg", "data": d.base64EncodedString()])
                }
            }
            NinetySharePlugin.clearInbox()
            var r: [String: Any] = ["files": files]
            if !text.isEmpty { r["text"] = text }
            call.resolve(r)
        }
    }

    private func notifyIfWaiting(delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, NinetySharePlugin.read("inbox") != nil, Date().timeIntervalSince(self.lastFire) > 1.5 else { return }
            self.lastFire = Date()
            self.bridge?.triggerWindowJSEvent(eventName: "nfshare")
        }
    }
    @objc func onOpenURL(_ n: Notification) {
        guard let o = n.object as? [String: Any], let url = o["url"] as? URL, url.scheme?.lowercased() == NinetySharePlugin.scheme else { return }
        notifyIfWaiting(delay: 0.4)
    }
    @objc func onActive() { notifyIfWaiting(delay: 0.6) }
}
