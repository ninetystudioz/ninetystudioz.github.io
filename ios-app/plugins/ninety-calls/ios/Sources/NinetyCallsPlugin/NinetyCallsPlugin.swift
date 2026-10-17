// Ninety — the iPhone call screen (v7.11). A call from the system arrives as a PushKit (VoIP) push and is shown with
// CallKit — the real iPhone incoming-call screen, also on the lock screen and with the app closed.
// · Answer → the app opens straight on the call (pending «answer» + «callAction» event for the page).
// · Decline → the server is told with the per-call token that came with the ring (works with the app closed).
// · «end» pushes (cancelled / answered on another device / missed) close the call screen.
// JS: Capacitor.Plugins.NinetyCalls — voipToken(), pending(), endCall({ callId }), events «voipToken», «callAction».
import Foundation
import UIKit
import PushKit
import CallKit
import AVFoundation
import Capacitor

/// started from the AppDelegate by name («NinetyCallsPlugin.NinetyCallBoot», no import needed) so a VoIP push that wakes
/// the closed app is handled at once. (No custom ObjC name here: Capacitor takes the first one in this file as the plugin.)
public class NinetyCallBoot: NSObject {
    @objc public static func boot() {
        NinetyCallManager.shared.start()
    }
}

final class BgTask {
    var id: UIBackgroundTaskIdentifier = .invalid
    func finish() {
        if id != .invalid { UIApplication.shared.endBackgroundTask(id); id = .invalid }
    }
}

public final class NinetyCallManager: NSObject, PKPushRegistryDelegate, CXProviderDelegate {
    public static let shared = NinetyCallManager()
    static let api = URL(string: "https://erhcnkjyaumdoixkksbz.supabase.co/functions/v1/push")!
    static let ringSeconds: TimeInterval = 46

    private var registry: PKPushRegistry?
    private let provider: CXProvider
    private var calls: [String: UUID] = [:]
    private var ids: [UUID: String] = [:]
    private var tokens: [UUID: String] = [:]
    private var answered = Set<UUID>()
    private var timers: [UUID: DispatchWorkItem] = [:]
    private var ended: [String: Date] = [:]
    public private(set) var token: String = ""
    weak var plugin: NinetyCallsPlugin?

    override init() {
        let cfg = CXProviderConfiguration()
        cfg.supportsVideo = true
        cfg.maximumCallGroups = 1
        cfg.maximumCallsPerCallGroup = 1
        cfg.supportedHandleTypes = [.generic]
        cfg.includesCallsInRecents = false
        provider = CXProvider(configuration: cfg)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    public func start() {
        if registry != nil { return }
        let r = PKPushRegistry(queue: DispatchQueue.main)
        r.delegate = self
        r.desiredPushTypes = [.voIP]
        registry = r
        if let t = r.pushToken(for: .voIP) { token = t.map { String(format: "%02x", $0) }.joined() }
    }

    // MARK: PushKit
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        plugin?.emitToken(token)
    }

    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        token = ""
    }

    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        let d = payload.dictionaryPayload
        func s(_ k: String) -> String {
            if let v = d[k] as? String { return v }
            if let v = d[k] { return "\(v)" }
            return ""
        }
        let kind = s("type")
        let callId = s("callId").lowercased()
        var caller = s("caller")
        if caller.isEmpty { caller = "Ninety" }
        let task = s("task")
        let exp = Double(s("exp")) ?? 0
        let fresh = exp <= 0 || Date().timeIntervalSince1970 * 1000 < exp
        pruneEnded()

        if kind == "ring" && fresh && !callId.isEmpty && ended[callId] == nil {
            if let old = calls[callId] {
                /* the caller rings again every few seconds — same call, nothing new to show */
                provider.reportNewIncomingCall(with: old, update: update(caller, task, s("video") == "1")) { _ in completion() }
                return
            }
            let uuid = UUID()
            calls[callId] = uuid
            ids[uuid] = callId
            tokens[uuid] = s("t")
            provider.reportNewIncomingCall(with: uuid, update: update(caller, task, s("video") == "1")) { [weak self] err in
                if err != nil { self?.forget(uuid) } else { self?.arm(uuid) }
                completion()
            }
            return
        }
        /* cancelled / answered elsewhere / missed */
        if !callId.isEmpty { ended[callId] = Date() }
        if let uuid = calls[callId] {
            provider.reportCall(with: uuid, endedAt: Date(), reason: kind == "ring" ? .remoteEnded : (answered.contains(uuid) ? .remoteEnded : .unanswered))
            forget(uuid)
            completion()
            return
        }
        /* iOS wants a call shown for every VoIP push — show and end it at once */
        let uuid = UUID()
        provider.reportNewIncomingCall(with: uuid, update: update(caller, task, false)) { [weak self] _ in
            self?.provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
            completion()
        }
    }

    private func update(_ caller: String, _ task: String, _ video: Bool) -> CXCallUpdate {
        let u = CXCallUpdate()
        var name = caller
        if !task.isEmpty { name = caller + " — " + task }
        if name.count > 70 { name = String(name.prefix(70)) + "…" }
        u.remoteHandle = CXHandle(type: .generic, value: caller)
        u.localizedCallerName = name
        u.hasVideo = video
        u.supportsHolding = false
        u.supportsGrouping = false
        u.supportsUngrouping = false
        u.supportsDTMF = false
        return u
    }

    private func arm(_ uuid: UUID) {
        timers[uuid]?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self = self, self.ids[uuid] != nil, !self.answered.contains(uuid) else { return }
            if let id = self.ids[uuid] { self.ended[id] = Date() }
            self.provider.reportCall(with: uuid, endedAt: Date(), reason: .unanswered)
            self.forget(uuid)
        }
        timers[uuid] = w
        DispatchQueue.main.asyncAfter(deadline: .now() + NinetyCallManager.ringSeconds, execute: w)
    }

    private func forget(_ uuid: UUID) {
        timers[uuid]?.cancel()
        timers[uuid] = nil
        if let id = ids[uuid] { calls[id] = nil }
        ids[uuid] = nil
        tokens[uuid] = nil
        answered.remove(uuid)
    }

    private func pruneEnded() {
        let limit = Date().addingTimeInterval(-120)
        ended = ended.filter { $0.value > limit }
    }

    /// the in-app call took over or finished → close the iPhone call screen
    func end(_ callId: String) {
        let id = callId.lowercased()
        guard !id.isEmpty else { return }
        ended[id] = Date()
        guard let uuid = calls[id] else { return }
        provider.reportCall(with: uuid, endedAt: Date(), reason: answered.contains(uuid) ? .remoteEnded : .answeredElsewhere)
        forget(uuid)
    }

    // MARK: CallKit
    public func providerDidReset(_ provider: CXProvider) {
        for (_, w) in timers { w.cancel() }
        timers = [:]
        calls = [:]
        ids = [:]
        tokens = [:]
        answered = []
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let uuid = action.callUUID
        answered.insert(uuid)
        timers[uuid]?.cancel()
        timers[uuid] = nil
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
        if let id = ids[uuid] {
            savePending("answer", id)
            plugin?.emitAction("answer", id)
        }
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let uuid = action.callUUID
        if let id = ids[uuid] {
            ended[id] = Date()
            if !answered.contains(uuid) { decline(id, tokens[uuid] ?? "") }
        }
        forget(uuid)
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) { }

    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) { }

    // MARK: server
    private func decline(_ id: String, _ t: String) {
        guard !t.isEmpty else { return }
        var req = URLRequest(url: NinetyCallManager.api)
        req.httpMethod = "POST"
        req.timeoutInterval = 10
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["action": "call-decline", "id": id, "t": t])
        let box = BgTask()
        box.id = UIApplication.shared.beginBackgroundTask(withName: "nf-call-decline") { box.finish() }
        URLSession.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async { box.finish() }
        }.resume()
    }

    // MARK: pending action (answer pressed while the page was not loaded)
    private let pendingKey = "nfcalls.pending"

    private func savePending(_ action: String, _ id: String) {
        UserDefaults.standard.set(["action": action, "callId": id, "at": Date().timeIntervalSince1970], forKey: pendingKey)
    }

    func takePending() -> [String: Any] {
        guard let p = UserDefaults.standard.dictionary(forKey: pendingKey) else { return [:] }
        UserDefaults.standard.removeObject(forKey: pendingKey)
        let at = p["at"] as? Double ?? 0
        if Date().timeIntervalSince1970 - at > 120 { return [:] }
        return ["action": p["action"] as? String ?? "", "callId": p["callId"] as? String ?? "", "url": ""]
    }
}

@objc(NinetyCallsPlugin)
public class NinetyCallsPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NinetyCallsPlugin"
    public let jsName = "NinetyCalls"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "voipToken", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pending", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "endCall", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startWork", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopWork", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "permState", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestIgnoreBattery", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "openFullScreenSettings", returnType: CAPPluginReturnPromise)
    ]

    override public func load() {
        DispatchQueue.main.async {
            NinetyCallManager.shared.start()
            NinetyCallManager.shared.plugin = self
        }
    }

    func emitToken(_ t: String) {
        notifyListeners("voipToken", data: ["token": t])
    }

    func emitAction(_ action: String, _ callId: String) {
        notifyListeners("callAction", data: ["action": action, "callId": callId, "url": ""], retainUntilConsumed: true)
    }

    @objc func voipToken(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            NinetyCallManager.shared.start()
            call.resolve(["token": NinetyCallManager.shared.token])
        }
    }

    @objc func pending(_ call: CAPPluginCall) {
        DispatchQueue.main.async { call.resolve(NinetyCallManager.shared.takePending()) }
    }

    @objc func endCall(_ call: CAPPluginCall) {
        let id = call.getString("callId") ?? ""
        DispatchQueue.main.async {
            NinetyCallManager.shared.end(id)
            call.resolve()
        }
    }

    /* Android only (work mode, battery, full-screen permission) — nothing to do on the iPhone */
    @objc func startWork(_ call: CAPPluginCall) { call.resolve() }
    @objc func stopWork(_ call: CAPPluginCall) { call.resolve() }
    @objc func permState(_ call: CAPPluginCall) { call.resolve(["battery": true, "fullScreen": true]) }
    @objc func requestIgnoreBattery(_ call: CAPPluginCall) { call.resolve() }
    @objc func openFullScreenSettings(_ call: CAPPluginCall) { call.resolve() }
}
