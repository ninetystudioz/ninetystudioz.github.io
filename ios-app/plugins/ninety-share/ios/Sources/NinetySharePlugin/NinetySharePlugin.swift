// Ninety — share sheet bridge (v7.57). iPhone: the web app hands the share extension what it needs (server address, a device
// token, the person's recent tasks) through a keychain item shared by the app and its extension (same team, access group
// app.ninety.shared). Android: the app receives «Share» intents (images / PDF) and the web page takes the files with take().
// JS: Capacitor.Plugins.NinetyShare.setContext({ ctx: '<json>' }) · .clear()
import Foundation
import Security
import Capacitor

@objc(NinetySharePlugin)
public class NinetySharePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NinetySharePlugin"
    public let jsName = "NinetyShare"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "setContext", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "clear", returnType: CAPPluginReturnPromise)
    ]
    static let group = "UF4QLJ9AY9.app.ninety.shared"
    static let service = "app.ninety.share"
    static func base() -> [String: Any] {
        return [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "ctx", kSecAttrAccessGroup as String: group]
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
        call.resolve(["ok": true])
    }
}
