// Ninety — the iPhone call screen (v7.11). A call from the system arrives as a PushKit (VoIP) push and is shown with
// CallKit — the real iPhone incoming-call screen, also on the lock screen and with the app closed.
// · Answer → the app opens straight on the call (pending «answer» + «callAction» event for the page).
// · Decline → the server is told with the per-call token that came with the ring (works with the app closed).
// · «end» pushes (cancelled / answered on another device / missed) close the call screen.
// JS: Capacitor.Plugins.NinetyCalls — voipToken(), pending(), endCall({ callId }), events «voipToken», «callAction».
//
// v8.19 (Mahmoud 21 Oct, «أجي أرد بيعلّق»): the answered call stays on the iPhone call screen until the in-app call really talks.
// · keepAlive({ on }) — the page says it reports the call state (remembered for the next cold start). Then:
//   · after «Answer» the CallKit call stays up (lock screen keeps the call UI, the audio session stays with the call) until
//     reportConnected({ callId }) — or endCall({ callId, force: true }) on hang-up / failure; an endCall without force on an
//     answered call that is not connected yet is ignored (older page code closes the screen right after answering);
//   · safety: no reportConnected within 45 s of the answer (reportConnecting({ callId }) restarts the 45 s) → the call screen
//     ends and «callEnded» { reason: "timeout" } goes to the page;
//   · the red button on the iPhone call screen after answering → «callEnded» { callId, reason: "user" } (the page hangs up);
//     «Mute» there → «callMuted» { callId, muted } (the page mutes its microphone).
//   Without keepAlive in this app run (older page code, or a rolled-back page) everything works as before.
// · The audio session: .playAndRecord / .voiceChat / Bluetooth (HFP + A2DP), no forced speaker; set before CallKit activates it
//   and again in didActivate; never deactivated by us (WebRTC in the web view owns the audio while the call runs).
// · The pending «answer» is cleared as soon as the page has it (delivered to a listener, or ack({ callId })).
// · Decline sends this phone's VoIP token too, so the server can stop the ringing on the other devices but not this one.
// · caps() → { keepAlive: true, v: 3, outgoing: true, audio: true } (feature detection; the page also checks the method list).
//
// v8.29 (Mahmoud 23 Oct, «الميكروفون بتاعك مش شغال (تطبيق تاني ماسكه؟)» → «يبقى ليه أولوية في الاتصال»):
// · startCallUI({ callId, name, video }) — a call this phone makes is shown as an iPhone call too (CallKit outgoing call):
//   iOS then gives it the call's audio priority (other apps' audio and recording stop, the green call pill, lock screen).
//   reportConnected({ callId }) marks it connected; endCall({ callId, force: true }) ends it; the red button there →
//   «callEnded» { reason: "user" }, «Mute» there → «callMuted» — the same events as an answered call.
// · audioPriority({ on }) — for a call that has no iPhone call screen: the voice-chat audio session is activated by the app
//   itself (not mixable, so another app holding the microphone is interrupted); off gives it back (notify others).
//
// v8.32 (Mahmoud 23 Oct, «صوت المكالمة من الأبليكيشن نفسه»): an AUDIO call talks through the app's own WebRTC (NinetyRTC.swift)
// instead of the web view's — the web view could not record under CallKit nor in the background (zero audio sent on every call
// answered on the iPhone call screen since 22 Oct). The page drives it: rtcCaps / rtcCreate / rtcOffer / rtcAnswer / rtcSetLocal /
// rtcSetRemote / rtcAddIce / rtcStats / rtcMute / rtcSpeaker / rtcRingback / rtcClose / rtcCloseAll / rtcState, events «rtcEvent».
// CallKit's audio activation goes to WebRTC's RTCAudioSession (manual audio). caps() → v 4, rtc: true.
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
    static let connectSeconds: TimeInterval = 45      // v8.19: answered → the page must say «connected» within this
    private static let keepAliveKey = "nfcalls.keepAlive"

    private var registry: PKPushRegistry?
    private let provider: CXProvider
    private var calls: [String: UUID] = [:]
    private var ids: [UUID: String] = [:]
    private var tokens: [UUID: String] = [:]
    private var answered = Set<UUID>()
    private var connected = Set<UUID>()                // v8.19
    private var timers: [UUID: DispatchWorkItem] = [:]
    private var connectTimers: [UUID: DispatchWorkItem] = [:]   // v8.19: safety after the answer
    private let controller = CXCallController()        // v8.29: calls this phone makes
    private var outgoing = Set<UUID>()                 // v8.29
    private var heldAudio = false                      // v8.29: audioPriority activated the session itself
    private var ended: [String: Date] = [:]
    public private(set) var token: String = ""
    weak var plugin: NinetyCallsPlugin?

    /// v8.19: the page reports the call state (reportConnected / endCall force) — remembered for the next cold start
    /// v8.32: a CallKit call (ringing / answered / outgoing) is up — NinetyRTC waits for its audio before taking the session
    var hasCalls: Bool { return !calls.isEmpty }

    var keepAlive: Bool {
        get { UserDefaults.standard.bool(forKey: NinetyCallManager.keepAliveKey) }
        set { UserDefaults.standard.set(newValue, forKey: NinetyCallManager.keepAliveKey); keepAliveNow = newValue }
    }
    /// the page running now said so (a rolled-back page that never calls keepAlive gets the old behaviour: endCall closes at once)
    private(set) var keepAliveNow = false

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
            let wasAnswered = answered.contains(uuid)
            provider.reportCall(with: uuid, endedAt: Date(), reason: kind == "ring" ? .remoteEnded : (wasAnswered ? .remoteEnded : .unanswered))
            forget(uuid)
            if wasAnswered { plugin?.emitEnded(callId, "remote") }   // v8.19: the page checks the call row
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

    /// v8.19: answered but the page never said «connected» → end the call screen and tell the page
    private func armConnect(_ uuid: UUID) {
        connectTimers[uuid]?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self = self, let id = self.ids[uuid], self.answered.contains(uuid), !self.connected.contains(uuid) else { return }
            self.ended[id] = Date()
            self.provider.reportCall(with: uuid, endedAt: Date(), reason: .failed)
            self.forget(uuid)
            self.plugin?.emitEnded(id, "timeout")
        }
        connectTimers[uuid] = w
        DispatchQueue.main.asyncAfter(deadline: .now() + NinetyCallManager.connectSeconds, execute: w)
    }

    private func forget(_ uuid: UUID) {
        timers[uuid]?.cancel()
        timers[uuid] = nil
        connectTimers[uuid]?.cancel()
        connectTimers[uuid] = nil
        if let id = ids[uuid] { calls[id] = nil }
        ids[uuid] = nil
        tokens[uuid] = nil
        answered.remove(uuid)
        connected.remove(uuid)
        outgoing.remove(uuid)
    }

    private func pruneEnded() {
        let limit = Date().addingTimeInterval(-120)
        ended = ended.filter { $0.value > limit }
    }

    /// the in-app call took over or finished → close the iPhone call screen.
    /// v8.19: with keepAlive, an answered call that is not connected yet stays unless force (the page hung up / failed).
    /// Returns false when the call was kept.
    @discardableResult
    func end(_ callId: String, force: Bool = false) -> Bool {
        let id = callId.lowercased()
        guard !id.isEmpty else { return true }
        if let uuid = calls[id], !force, keepAliveNow, answered.contains(uuid), !connected.contains(uuid) { return false }
        ended[id] = Date()
        guard let uuid = calls[id] else { return true }
        provider.reportCall(with: uuid, endedAt: Date(), reason: answered.contains(uuid) ? .remoteEnded : .answeredElsewhere)
        forget(uuid)
        return true
    }

    /// v8.19: the in-app call is talking — the call screen stays as the iPhone's own call until endCall
    func connectedNow(_ callId: String) -> Bool {
        guard let uuid = calls[callId.lowercased()] else { return false }
        connected.insert(uuid)
        connectTimers[uuid]?.cancel()
        connectTimers[uuid] = nil
        if outgoing.contains(uuid) { provider.reportOutgoingCall(with: uuid, connectedAt: Date()) }   // v8.29
        return true
    }

    /// v8.29: a call this phone makes → an iPhone (CallKit) outgoing call, so the call owns the audio like a phone call
    func startOutgoing(_ callId: String, _ name: String, _ video: Bool) -> Bool {
        let id = callId.lowercased()
        guard !id.isEmpty else { return false }
        if calls[id] != nil { return true }
        let uuid = UUID()
        calls[id] = uuid
        ids[uuid] = id
        outgoing.insert(uuid)
        answered.insert(uuid)                          // the red button / mute there go to the page like an answered call
        configureAudio(AVAudioSession.sharedInstance())
        let handle = CXHandle(type: .generic, value: name.isEmpty ? "Ninety" : String(name.prefix(70)))
        let action = CXStartCallAction(call: uuid, handle: handle)
        action.isVideo = video
        action.contactIdentifier = name
        controller.request(CXTransaction(action: action)) { [weak self] err in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let err = err {
                    NSLog("[NinetyCalls] outgoing call UI: \(err)")
                    self.forget(uuid)
                    return
                }
                let u = CXCallUpdate()
                u.remoteHandle = handle
                u.localizedCallerName = name
                u.hasVideo = video
                u.supportsHolding = false
                u.supportsGrouping = false
                u.supportsUngrouping = false
                u.supportsDTMF = false
                self.provider.reportCall(with: uuid, updated: u)
            }
        }
        return true
    }

    /// v8.29: the voice-chat audio session for a call without an iPhone call screen (on) / given back (off)
    func audioPriority(_ on: Bool) -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            if on {
                if !calls.isEmpty { return true }             // CallKit owns the session while its call is up
                configureAudio(session)
                try session.setActive(true, options: [])
                heldAudio = true
            } else if heldAudio {
                heldAudio = false
                if calls.isEmpty { try session.setActive(false, options: [.notifyOthersOnDeactivation]) }
            }
            return true
        } catch {
            NSLog("[NinetyCalls] audioPriority \(on): \(error)")
            return false
        }
    }

    /// v8.19: still connecting — the 45 s start again
    func connectingNow(_ callId: String) -> Bool {
        guard let uuid = calls[callId.lowercased()], answered.contains(uuid), !connected.contains(uuid) else { return false }
        armConnect(uuid)
        return true
    }

    func state(_ callId: String) -> [String: Any] {
        guard let uuid = calls[callId.lowercased()] else { return ["exists": false] }
        return ["exists": true, "answered": answered.contains(uuid), "connected": connected.contains(uuid)]
    }

    // MARK: audio (v8.19)
    private func configureAudio(_ session: AVAudioSession) {
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
        } catch {
            NSLog("[NinetyCalls] audio category: \(error)")
        }
    }

    // MARK: CallKit
    public func providerDidReset(_ provider: CXProvider) {
        let gone = answered.compactMap { ids[$0] }
        for (_, w) in timers { w.cancel() }
        for (_, w) in connectTimers { w.cancel() }
        timers = [:]
        connectTimers = [:]
        calls = [:]
        ids = [:]
        tokens = [:]
        answered = []
        connected = []
        for id in gone { plugin?.emitEnded(id, "reset") }
    }

    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let uuid = action.callUUID
        answered.insert(uuid)
        timers[uuid]?.cancel()
        timers[uuid] = nil
        configureAudio(AVAudioSession.sharedInstance())   // before CallKit activates the session
        if let id = ids[uuid] {
            if keepAlive { armConnect(uuid) }
            if let p = plugin { p.emitAction("answer", id) }  // saved as pending only when no page listens yet
            else { savePending("answer", id) }                // the page / plugin is not loaded yet (cold start)
        }
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let uuid = action.callUUID
        if let id = ids[uuid] {
            ended[id] = Date()
            if answered.contains(uuid) {
                plugin?.emitEnded(id, "user")                 // v8.19: red button after answering → the page hangs up
            } else {
                decline(id, tokens[uuid] ?? "")
                plugin?.emitEnded(id, "declined")
            }
        }
        forget(uuid)
        action.fulfill()
    }

    /// v8.29: the outgoing call (startCallUI) — the audio is set before CallKit activates it
    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        configureAudio(AVAudioSession.sharedInstance())
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        action.fulfill()
    }

    /// v8.19: «Mute» on the iPhone call screen (the call now stays there) → the page mutes its microphone
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        if let id = ids[action.callUUID] { plugin?.emitMuted(id, action.isMuted) }
        action.fulfill()
    }

    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        configureAudio(audioSession)                          // CallKit owns activation
        NinetyRTC.shared.callKitActivated(audioSession)       // v8.32: the app's WebRTC records / plays from now on
    }

    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        NinetyRTC.shared.callKitDeactivated(audioSession)     // v8.32: an open native call takes the session itself again
    }

    // MARK: server
    private func decline(_ id: String, _ t: String) {
        guard !t.isEmpty else { return }
        var req = URLRequest(url: NinetyCallManager.api)
        req.httpMethod = "POST"
        req.timeoutInterval = 10
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        var body: [String: Any] = ["action": "call-decline", "id": id, "t": t]
        if !token.isEmpty { body["voip"] = token }            // v8.19 (push v16): skip this phone, stop the others
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let box = BgTask()
        box.id = UIApplication.shared.beginBackgroundTask(withName: "nf-call-decline") { box.finish() }
        URLSession.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async { box.finish() }
        }.resume()
    }

    // MARK: pending action (answer pressed while the page was not loaded)
    private let pendingKey = "nfcalls.pending"

    func savePending(_ action: String, _ id: String) {
        UserDefaults.standard.set(["action": action, "callId": id, "at": Date().timeIntervalSince1970], forKey: pendingKey)
    }

    /// v8.19: the page has it → forget it (only this call's pending; empty id clears any)
    func clearPending(_ id: String) {
        guard let p = UserDefaults.standard.dictionary(forKey: pendingKey) else { return }
        let pid = (p["callId"] as? String ?? "").lowercased()
        if id.isEmpty || pid == id.lowercased() { UserDefaults.standard.removeObject(forKey: pendingKey) }
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
        CAPPluginMethod(name: "keepAlive", returnType: CAPPluginReturnPromise),         // v8.19
        CAPPluginMethod(name: "reportConnecting", returnType: CAPPluginReturnPromise),  // v8.19
        CAPPluginMethod(name: "reportConnected", returnType: CAPPluginReturnPromise),   // v8.19
        CAPPluginMethod(name: "ack", returnType: CAPPluginReturnPromise),               // v8.19
        CAPPluginMethod(name: "callState", returnType: CAPPluginReturnPromise),         // v8.19
        CAPPluginMethod(name: "caps", returnType: CAPPluginReturnPromise),              // v8.19
        CAPPluginMethod(name: "startWork", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopWork", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "permState", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestIgnoreBattery", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "openFullScreenSettings", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startCallUI", returnType: CAPPluginReturnPromise),       // v8.29
        CAPPluginMethod(name: "audioPriority", returnType: CAPPluginReturnPromise),     // v8.29
        CAPPluginMethod(name: "rtcCaps", returnType: CAPPluginReturnPromise),           // v8.32 native call audio
        CAPPluginMethod(name: "rtcCreate", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rtcOffer", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rtcAnswer", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rtcSetLocal", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rtcSetRemote", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rtcAddIce", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rtcStats", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rtcMute", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rtcSpeaker", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rtcRingback", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rtcClose", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rtcCloseAll", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rtcState", returnType: CAPPluginReturnPromise)
    ]

    override public func load() {
        DispatchQueue.main.async {
            NinetyCallManager.shared.start()
            NinetyCallManager.shared.plugin = self
            NinetyRTC.shared.plugin = self                                          // v8.32
            NinetyRTC.shared.hasCallKitCall = { NinetyCallManager.shared.hasCalls }
        }
    }

    func emitToken(_ t: String) {
        notifyListeners("voipToken", data: ["token": t])
    }

    /// the answer reaches the page now (a listener is there) — otherwise it is kept as pending + retained for the first listener
    func emitAction(_ action: String, _ callId: String) {
        if hasListeners("callAction") {
            NinetyCallManager.shared.clearPending(callId)
        } else {
            NinetyCallManager.shared.savePending(action, callId)
        }
        notifyListeners("callAction", data: ["action": action, "callId": callId, "url": ""], retainUntilConsumed: true)
    }

    /// v8.19: the iPhone call screen ended (reason user / declined / timeout / remote / reset)
    func emitEnded(_ callId: String, _ reason: String) {
        notifyListeners("callEnded", data: ["callId": callId, "reason": reason], retainUntilConsumed: reason == "user")
    }

    /// v8.19: «Mute» pressed on the iPhone call screen
    func emitMuted(_ callId: String, _ muted: Bool) {
        notifyListeners("callMuted", data: ["callId": callId, "muted": muted])
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
        let force = call.getBool("force") ?? false
        DispatchQueue.main.async {
            let done = NinetyCallManager.shared.end(id, force: force)
            call.resolve(["ended": done])
        }
    }

    @objc func keepAlive(_ call: CAPPluginCall) {
        let on = call.getBool("on") ?? true
        DispatchQueue.main.async {
            NinetyCallManager.shared.keepAlive = on
            call.resolve(["on": on])
        }
    }

    @objc func reportConnecting(_ call: CAPPluginCall) {
        let id = call.getString("callId") ?? ""
        DispatchQueue.main.async { call.resolve(["ok": NinetyCallManager.shared.connectingNow(id)]) }
    }

    @objc func reportConnected(_ call: CAPPluginCall) {
        let id = call.getString("callId") ?? ""
        DispatchQueue.main.async { call.resolve(["ok": NinetyCallManager.shared.connectedNow(id)]) }
    }

    @objc func ack(_ call: CAPPluginCall) {
        let id = call.getString("callId") ?? ""
        DispatchQueue.main.async {
            NinetyCallManager.shared.clearPending(id)
            call.resolve()
        }
    }

    @objc func callState(_ call: CAPPluginCall) {
        let id = call.getString("callId") ?? ""
        DispatchQueue.main.async { call.resolve(NinetyCallManager.shared.state(id)) }
    }

    @objc func caps(_ call: CAPPluginCall) {
        call.resolve(["keepAlive": true, "v": 4, "outgoing": true, "audio": true, "rtc": true])
    }

    /// v8.29: a call this phone makes shows as an iPhone call (audio priority)
    @objc func startCallUI(_ call: CAPPluginCall) {
        let id = call.getString("callId") ?? ""
        let name = call.getString("name") ?? ""
        let video = call.getBool("video") ?? false
        DispatchQueue.main.async { call.resolve(["ok": NinetyCallManager.shared.startOutgoing(id, name, video)]) }
    }

    /// v8.29: voice-chat audio session on / off for a call without the iPhone call screen
    @objc func audioPriority(_ call: CAPPluginCall) {
        let on = call.getBool("on") ?? true
        DispatchQueue.main.async { call.resolve(["ok": NinetyCallManager.shared.audioPriority(on), "on": on]) }
    }

    // MARK: v8.32 native call audio (NinetyRTC) — all on the main thread
    @objc func rtcCaps(_ call: CAPPluginCall) {
        call.resolve(["v": 1, "audio": true, "video": false])
    }

    @objc func rtcCreate(_ call: CAPPluginCall) {
        let id = call.getString("pcId") ?? ""
        let raw: [Any] = (call.getArray("iceServers") ?? []).map { $0 as Any }
        DispatchQueue.main.async {
            let servers = NinetyRTC.iceServers(raw)
            if NinetyRTC.shared.create(id, servers) { call.resolve(["ok": true, "servers": servers.count]) } else { call.reject("rtc create failed") }
        }
    }

    @objc func rtcOffer(_ call: CAPPluginCall) {
        let id = call.getString("pcId") ?? ""
        let restart = call.getBool("iceRestart") ?? false
        DispatchQueue.main.async {
            NinetyRTC.shared.offer(id, restart: restart) { sdp, err in
                if let sdp = sdp { call.resolve(["type": "offer", "sdp": sdp]) } else { call.reject(err ?? "offer failed") }
            }
        }
    }

    @objc func rtcAnswer(_ call: CAPPluginCall) {
        let id = call.getString("pcId") ?? ""
        DispatchQueue.main.async {
            NinetyRTC.shared.answer(id) { sdp, err in
                if let sdp = sdp { call.resolve(["type": "answer", "sdp": sdp]) } else { call.reject(err ?? "answer failed") }
            }
        }
    }

    @objc func rtcSetLocal(_ call: CAPPluginCall) {
        let id = call.getString("pcId") ?? ""
        let type = call.getString("type") ?? "offer"
        let sdp = call.getString("sdp") ?? ""
        DispatchQueue.main.async {
            NinetyRTC.shared.setLocal(id, type, sdp) { d, err in
                if let d = d { call.resolve(d) } else { call.reject(err ?? "setLocal failed") }
            }
        }
    }

    @objc func rtcSetRemote(_ call: CAPPluginCall) {
        let id = call.getString("pcId") ?? ""
        let type = call.getString("type") ?? "offer"
        let sdp = call.getString("sdp") ?? ""
        DispatchQueue.main.async {
            NinetyRTC.shared.setRemote(id, type, sdp) { d, err in
                if let d = d { call.resolve(d) } else { call.reject(err ?? "setRemote failed") }
            }
        }
    }

    @objc func rtcAddIce(_ call: CAPPluginCall) {
        let id = call.getString("pcId") ?? ""
        let cand = call.getString("candidate") ?? ""
        let mid = call.getString("sdpMid")
        let index = call.getInt("sdpMLineIndex") ?? 0
        if cand.isEmpty { call.resolve(); return }
        DispatchQueue.main.async {
            NinetyRTC.shared.addIce(id, cand, mid, index) { err in
                if let err = err { call.reject(err) } else { call.resolve() }
            }
        }
    }

    @objc func rtcStats(_ call: CAPPluginCall) {
        let id = call.getString("pcId") ?? ""
        DispatchQueue.main.async {
            NinetyRTC.shared.stats(id) { arr in call.resolve(["stats": arr]) }
        }
    }

    @objc func rtcMute(_ call: CAPPluginCall) {
        let on = call.getBool("muted") ?? false
        DispatchQueue.main.async { NinetyRTC.shared.setMuted(on); call.resolve(["muted": on]) }
    }

    @objc func rtcSpeaker(_ call: CAPPluginCall) {
        let on = call.getBool("on") ?? false
        DispatchQueue.main.async { NinetyRTC.shared.setSpeaker(on); call.resolve(["on": on]) }
    }

    @objc func rtcRingback(_ call: CAPPluginCall) {
        let on = call.getBool("on") ?? false
        DispatchQueue.main.async { NinetyRTC.shared.ringback(on); call.resolve(["on": on]) }
    }

    @objc func rtcClose(_ call: CAPPluginCall) {
        let id = call.getString("pcId") ?? ""
        DispatchQueue.main.async { NinetyRTC.shared.close(id); call.resolve() }
    }

    @objc func rtcCloseAll(_ call: CAPPluginCall) {
        DispatchQueue.main.async { NinetyRTC.shared.closeAll(); call.resolve() }
    }

    @objc func rtcState(_ call: CAPPluginCall) {
        DispatchQueue.main.async { call.resolve(NinetyRTC.shared.state()) }
    }

    /* Android only (work mode, battery, full-screen permission) — nothing to do on the iPhone */
    @objc func startWork(_ call: CAPPluginCall) { call.resolve() }
    @objc func stopWork(_ call: CAPPluginCall) { call.resolve() }
    @objc func permState(_ call: CAPPluginCall) { call.resolve(["battery": true, "fullScreen": true]) }
    @objc func requestIgnoreBattery(_ call: CAPPluginCall) { call.resolve() }
    @objc func openFullScreenSettings(_ call: CAPPluginCall) { call.resolve() }
}
