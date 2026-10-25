// Ninety — the call audio inside the iPhone app itself (v8.32, Mahmoud 23 Oct: «صوت المكالمة من الأبليكيشن نفسه»).
//
// Why: an audio call answered on the iPhone call screen (CallKit) — or made while CallKit owns the audio — had the microphone
// muted in the web view: iOS gives the call's audio session to CallKit, and the web view (WebKit) cannot record under it, nor in
// the background. Every answered call from 22 Oct sent zero audio (nf_calls.diag_* → micMuted, outAudioBytes 0).
//
// What: the web page keeps doing everything it did (ringing, the call row, the offer / answer, ICE servers, trickle candidates,
// reconnect, the call screen, the diagnostics) — only the RTCPeerConnection of an AUDIO call is this native one (Google WebRTC,
// stasel/WebRTC M150). The page reaches it through the plugin methods rtc* below (a873-native-rtc.js wraps them as a drop-in
// RTCPeerConnection), so the microphone and the speaker belong to the app under CallKit: it talks on the lock screen, in the
// background, with Bluetooth, like a phone call. Video calls stay in the web view as before.
//
// Audio session: WebRTC's RTCAudioSession in manual mode — recording / playout start only when the session is active:
// · CallKit activates it (answered call, or the outgoing call screen) → didActivate → isAudioEnabled = true;
// · no CallKit call (answered with the in-app «رد», which closes the ringing screen first) → the app activates the voice-chat
//   session itself after a short wait, and gives it back (notify others) when the last connection closes;
// · CallKit deactivates while a connection is still open (the in-app answer case) → the app takes it again.
// Ringback while an outgoing native call rings: a soft 425 Hz tone (1 s on, 2 s off) from the app (the web page stays silent).
import Foundation
import AVFoundation
import WebRTC

final class NinetyPCDelegate: NSObject, RTCPeerConnectionDelegate {
    let id: String
    weak var owner: NinetyRTC?

    init(_ id: String, _ owner: NinetyRTC) {
        self.id = id
        self.owner = owner
        super.init()
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        owner?.emit(id, ["kind": "signaling", "state": NinetyRTC.signaling(stateChanged)])
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        owner?.emit(id, ["kind": "ice", "state": NinetyRTC.ice(newState)])
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        var d: [String: Any] = ["kind": "gathering", "state": NinetyRTC.gathering(newState)]
        if newState == .complete, let sdp = peerConnection.localDescription?.sdp { d["sdp"] = sdp }
        owner?.emit(id, d)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        var d: [String: Any] = ["kind": "candidate", "candidate": candidate.sdp, "sdpMLineIndex": Int(candidate.sdpMLineIndex)]
        if let mid = candidate.sdpMid { d["sdpMid"] = mid }
        if let sdp = peerConnection.localDescription?.sdp { d["sdp"] = sdp }   // the SDP so far, with the candidates gathered until now
        owner?.emit(id, d)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        owner?.emit(id, ["kind": "conn", "state": NinetyRTC.connection(newState)])
    }
}

final class NinetyRTC: NSObject {
    static let shared = NinetyRTC()
    weak var plugin: NinetyCallsPlugin?
    /// a CallKit call (ringing, answered or outgoing) exists — set by NinetyCallManager
    var hasCallKitCall: () -> Bool = { false }

    private var factory: RTCPeerConnectionFactory?
    private var source: RTCAudioSource?
    private var pcs: [String: RTCPeerConnection] = [:]
    private var delegates: [String: NinetyPCDelegate] = [:]
    private var tracks: [String: RTCAudioTrack] = [:]
    private var muted = false
    private var speaker = false
    private(set) var callKitAudio = false
    private(set) var heldAudio = false
    private var ensureItem: DispatchWorkItem?
    private var ensureTries = 0
    private var ringPlayer: AVAudioPlayer?

    var count: Int { return pcs.count }
    /// v8.69: the call's audio session is ours (CallKit activated it, or the app holds the voice-chat session)
    var sessionOurs: Bool { return callKitAudio || heldAudio }
    /// v8.69: something talks — a native connection here or a LiveKit room (NinetyLK)
    private var busy: Bool { return !pcs.isEmpty || NinetyLK.shared.count > 0 }
    private var releaseItem: DispatchWorkItem?

    // MARK: setup
    private func makeFactory() -> RTCPeerConnectionFactory {
        if let f = factory { return f }
        _ = RTCInitializeSSL()
        let s = RTCAudioSession.sharedInstance()
        s.useManualAudio = true                 // the ADM records / plays only while the session is ours (CallKit or held)
        s.isAudioEnabled = callKitAudio || heldAudio
        let f = RTCPeerConnectionFactory()
        factory = f
        return f
    }

    private func audioSource(_ f: RTCPeerConnectionFactory) -> RTCAudioSource {
        if let s = source { return s }
        let s = f.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        source = s
        return s
    }

    static func iceServers(_ arr: [Any]) -> [RTCIceServer] {
        var out: [RTCIceServer] = []
        for item in arr {
            guard let o = item as? [String: Any] else { continue }
            var urls: [String] = []
            if let u = o["urls"] as? String {
                urls = [u]
            } else if let a = o["urls"] as? [Any] {
                urls = a.compactMap { $0 as? String }
            }
            if let u = o["url"] as? String { urls.append(u) }
            if urls.isEmpty { continue }
            out.append(RTCIceServer(urlStrings: urls, username: o["username"] as? String, credential: o["credential"] as? String))
        }
        return out
    }

    // MARK: connections (main thread)
    func create(_ id: String, _ servers: [RTCIceServer]) -> Bool {
        guard !id.isEmpty else { return false }
        if pcs[id] != nil { return true }
        let f = makeFactory()
        releaseItem?.cancel()
        releaseItem = nil
        RTCAudioSession.sharedInstance().isAudioEnabled = callKitAudio || heldAudio   // v8.69: may have been switched off for a LiveKit call
        let cfg = RTCConfiguration()
        cfg.iceServers = servers
        cfg.sdpSemantics = .unifiedPlan
        cfg.bundlePolicy = .maxBundle
        cfg.rtcpMuxPolicy = .require
        cfg.continualGatheringPolicy = .gatherOnce
        let cons = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: ["DtlsSrtpKeyAgreement": "true"])
        let del = NinetyPCDelegate(id, self)
        guard let pc = f.peerConnection(with: cfg, constraints: cons, delegate: del) else { return false }
        let track = f.audioTrack(with: audioSource(f), trackId: "nfa-" + id)
        track.isEnabled = !muted
        _ = pc.add(track, streamIds: ["nfs-" + id])
        pcs[id] = pc
        delegates[id] = del
        tracks[id] = track
        scheduleEnsure(1.5)
        return true
    }

    func pc(_ id: String) -> RTCPeerConnection? { return pcs[id] }

    private func constraints(_ restart: Bool) -> RTCMediaConstraints {
        var m: [String: String] = ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "false"]
        if restart { m["IceRestart"] = "true" }
        return RTCMediaConstraints(mandatoryConstraints: m, optionalConstraints: nil)
    }

    func offer(_ id: String, restart: Bool, _ done: @escaping (String?, String?) -> Void) {
        guard let pc = pcs[id] else { done(nil, "no pc"); return }
        pc.offer(for: constraints(restart)) { sdp, err in
            DispatchQueue.main.async { done(sdp?.sdp, err.map { "\($0)" } ?? (sdp == nil ? "no sdp" : nil)) }
        }
    }

    func answer(_ id: String, _ done: @escaping (String?, String?) -> Void) {
        guard let pc = pcs[id] else { done(nil, "no pc"); return }
        pc.answer(for: constraints(false)) { sdp, err in
            DispatchQueue.main.async { done(sdp?.sdp, err.map { "\($0)" } ?? (sdp == nil ? "no sdp" : nil)) }
        }
    }

    static func sdpName(_ t: RTCSdpType) -> String {
        switch t {
        case .answer: return "answer"
        case .prAnswer: return "pranswer"
        case .rollback: return "rollback"
        default: return "offer"
        }
    }

    static func sdpType(_ s: String) -> RTCSdpType {
        switch s {
        case "answer": return .answer
        case "pranswer": return .prAnswer
        case "rollback": return .rollback
        default: return .offer
        }
    }

    func setLocal(_ id: String, _ type: String, _ sdp: String, _ done: @escaping ([String: Any]?, String?) -> Void) {
        guard let pc = pcs[id] else { done(nil, "no pc"); return }
        pc.setLocalDescription(RTCSessionDescription(type: NinetyRTC.sdpType(type), sdp: sdp)) { err in
            DispatchQueue.main.async {
                if let err = err { done(nil, "\(err)"); return }
                done(self.snapshot(pc), nil)
            }
        }
    }

    func setRemote(_ id: String, _ type: String, _ sdp: String, _ done: @escaping ([String: Any]?, String?) -> Void) {
        guard let pc = pcs[id] else { done(nil, "no pc"); return }
        pc.setRemoteDescription(RTCSessionDescription(type: NinetyRTC.sdpType(type), sdp: sdp)) { err in
            DispatchQueue.main.async {
                if let err = err { done(nil, "\(err)"); return }
                done(self.snapshot(pc), nil)
            }
        }
    }

    private func snapshot(_ pc: RTCPeerConnection) -> [String: Any] {
        var d: [String: Any] = [
            "signaling": NinetyRTC.signaling(pc.signalingState),
            "gathering": NinetyRTC.gathering(pc.iceGatheringState),
            "ice": NinetyRTC.ice(pc.iceConnectionState),
            "conn": NinetyRTC.connection(pc.connectionState),
        ]
        if let l = pc.localDescription { d["localSdp"] = l.sdp; d["localType"] = NinetyRTC.sdpName(l.type) }
        return d
    }

    func addIce(_ id: String, _ cand: String, _ mid: String?, _ index: Int, _ done: @escaping (String?) -> Void) {
        guard let pc = pcs[id] else { done("no pc"); return }
        let c = RTCIceCandidate(sdp: cand, sdpMLineIndex: Int32(index), sdpMid: mid)
        pc.add(c, completionHandler: { err in
            DispatchQueue.main.async { done(err.map { "\($0)" }) }
        })
    }

    func stats(_ id: String, _ done: @escaping ([[String: Any]]) -> Void) {
        guard let pc = pcs[id] else { done([]); return }
        pc.statistics { report in
            var out: [[String: Any]] = []
            for (_, s) in report.statistics {
                var o: [String: Any] = ["id": s.id, "type": s.type, "timestamp": s.timestamp_us / 1000.0]
                for (k, v) in s.values { if let c = NinetyRTC.clean(v) { o[k] = c } }
                out.append(o)
            }
            DispatchQueue.main.async { done(out) }
        }
    }

    /// stats values → JSON-safe (no NaN / infinity)
    static func clean(_ v: Any) -> Any? {
        if let n = v as? NSNumber {
            if CFGetTypeID(n as CFTypeRef) == CFBooleanGetTypeID() { return n.boolValue }
            return n.doubleValue.isFinite ? n : nil
        }
        if let s = v as? String { return s }
        if let a = v as? [Any] { return a.compactMap { clean($0) } }
        if let d = v as? [String: Any] {
            var o: [String: Any] = [:]
            for (k, x) in d { if let c = clean(x) { o[k] = c } }
            return o
        }
        return nil
    }

    func setMuted(_ on: Bool) {
        muted = on
        for (_, t) in tracks { t.isEnabled = !on }
    }

    func setSpeaker(_ on: Bool) {
        speaker = on
        let s = RTCAudioSession.sharedInstance()
        s.lockForConfiguration()
        do {
            try s.overrideOutputAudioPort(on ? AVAudioSession.PortOverride.speaker : AVAudioSession.PortOverride.none)
        } catch {
            NSLog("[NinetyRTC] speaker \(on): \(error)")
        }
        s.unlockForConfiguration()
    }

    func close(_ id: String) {
        if let pc = pcs[id] { pc.close() }
        pcs[id] = nil
        delegates[id] = nil
        tracks[id] = nil
        if pcs.isEmpty { pcsGone() }
    }

    /// v8.69: the last native connection closed. With a LiveKit room up the session stays (only this WebRTC's audio stops);
    /// otherwise it is given back after a short grace — the page closes the native connection right before it joins LiveKit.
    private func pcsGone() {
        if NinetyLK.shared.count > 0 {
            RTCAudioSession.sharedInstance().isAudioEnabled = false
            return
        }
        releaseItem?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.releaseItem = nil
            if self.pcs.isEmpty && NinetyLK.shared.count == 0 { self.allClosed() }
        }
        releaseItem = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: w)
    }

    /// v8.69: a LiveKit room joined / the last one left (NinetyLK)
    func lkChanged() {
        if NinetyLK.shared.count > 0 {
            releaseItem?.cancel()
            releaseItem = nil
            if pcs.isEmpty { RTCAudioSession.sharedInstance().isAudioEnabled = false }
            if !callKitAudio && !heldAudio { ensureTries = 0; scheduleEnsure(0.3) }
        } else if pcs.isEmpty {
            releaseItem?.cancel()
            releaseItem = nil
            allClosed()
        }
    }

    func closeAll() {
        for (_, pc) in pcs { pc.close() }
        pcs = [:]
        delegates = [:]
        tracks = [:]
        allClosed()
    }

    private func allClosed() {
        releaseItem?.cancel()
        releaseItem = nil
        ringback(false)
        ensureItem?.cancel()
        ensureItem = nil
        ensureTries = 0
        muted = false
        if speaker { setSpeaker(false) }
        let s = RTCAudioSession.sharedInstance()
        s.isAudioEnabled = false
        if heldAudio {
            heldAudio = false
            let av = AVAudioSession.sharedInstance()
            s.audioSessionDidDeactivate(av)
            do { try av.setActive(false, options: [.notifyOthersOnDeactivation]) } catch { NSLog("[NinetyRTC] release: \(error)") }
        }
        NinetyLK.shared.sync()
    }

    func state() -> [String: Any] {
        return ["pcs": pcs.count, "audio": RTCAudioSession.sharedInstance().isAudioEnabled, "callkit": callKitAudio, "held": heldAudio, "muted": muted, "speaker": speaker, "lk": NinetyLK.shared.count]
    }

    // MARK: audio session
    func callKitActivated(_ session: AVAudioSession) {
        callKitAudio = true
        ensureItem?.cancel()
        ensureItem = nil
        let s = RTCAudioSession.sharedInstance()
        if heldAudio { heldAudio = false }      // CallKit owns it now
        s.audioSessionDidActivate(session)
        s.isAudioEnabled = !(pcs.isEmpty && NinetyLK.shared.count > 0)   // v8.69: a LiveKit-only call keeps this WebRTC silent
        if speaker { setSpeaker(true) }
        startRing()
        emitAll(["kind": "audio", "state": "callkit"])
        NinetyLK.shared.sync()                  // v8.69: LiveKit's engine may run now
    }

    func callKitDeactivated(_ session: AVAudioSession) {
        callKitAudio = false
        let s = RTCAudioSession.sharedInstance()
        s.audioSessionDidDeactivate(session)
        s.isAudioEnabled = false
        if busy { ensureTries = 0; scheduleEnsure(0.4) }   // still talking (in-app answer closed the ringing screen)
        emitAll(["kind": "audio", "state": "off"])
        NinetyLK.shared.sync()
    }

    private func scheduleEnsure(_ after: TimeInterval) {
        ensureItem?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.ensureAudio() }
        ensureItem = w
        DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: w)
    }

    /// no CallKit session for an open connection → take the voice-chat session (a CallKit call that is about to activate gets ~4 s)
    private func ensureAudio() {
        ensureItem = nil
        guard busy, !callKitAudio else { return }
        if heldAudio {                           // already ours — v8.69: just make sure the right engine plays
            RTCAudioSession.sharedInstance().isAudioEnabled = !(pcs.isEmpty && NinetyLK.shared.count > 0)
            NinetyLK.shared.sync()
            return
        }
        if hasCallKitCall() && ensureTries < 4 {
            ensureTries += 1
            scheduleEnsure(1.0)
            return
        }
        let av = AVAudioSession.sharedInstance()
        do {
            try av.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try av.setActive(true, options: [])
            heldAudio = true
            let s = RTCAudioSession.sharedInstance()
            s.audioSessionDidActivate(av)
            s.isAudioEnabled = !(pcs.isEmpty && NinetyLK.shared.count > 0)
            if speaker { setSpeaker(true) }
            startRing()
            emitAll(["kind": "audio", "state": "held"])
            NinetyLK.shared.sync()
        } catch {
            NSLog("[NinetyRTC] audio session: \(error)")
            emitAll(["kind": "audio", "state": "error", "error": "\(error)"])
            if ensureTries < 8 { ensureTries += 1; scheduleEnsure(1.5) }
        }
    }

    // MARK: ringback (outgoing call ringing)
    private var wantRing = false

    func ringback(_ on: Bool) {
        wantRing = on
        if !on {
            ringPlayer?.stop()
            ringPlayer = nil
            return
        }
        if callKitAudio || heldAudio { startRing() } else if ensureItem == nil { scheduleEnsure(0.1) }   // waits for CallKit first
    }

    private func startRing() {
        guard wantRing, ringPlayer == nil else { return }
        do {
            let p = try AVAudioPlayer(data: NinetyRTC.toneWav())
            p.numberOfLoops = -1
            p.volume = 0.45
            p.prepareToPlay()
            p.play()
            ringPlayer = p
        } catch {
            NSLog("[NinetyRTC] ringback: \(error)")
        }
    }

    /// 425 Hz, 1 s on (soft edges) + 2 s off, 16-bit mono 16 kHz WAV
    static func toneWav() -> Data {
        let rate = 16000
        let total = rate * 3
        let on = rate
        var pcm = Data(capacity: total * 2)
        for i in 0..<total {
            var v: Double = 0
            if i < on {
                let t = Double(i) / Double(rate)
                let edge = min(1.0, min(Double(i), Double(on - i)) / Double(rate / 50))
                v = sin(2.0 * Double.pi * 425.0 * t) * 0.35 * edge
            }
            var s = Int16(max(-1.0, min(1.0, v)) * 32767.0).littleEndian
            withUnsafeBytes(of: &s) { pcm.append(contentsOf: $0) }
        }
        var d = Data()
        func u32(_ x: UInt32) { var y = x.littleEndian; withUnsafeBytes(of: &y) { d.append(contentsOf: $0) } }
        func u16(_ x: UInt16) { var y = x.littleEndian; withUnsafeBytes(of: &y) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + pcm.count)); d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(UInt32(pcm.count))
        d.append(pcm)
        return d
    }

    // MARK: events to the page
    func emit(_ id: String, _ data: [String: Any]) {
        var d = data
        d["pcId"] = id
        DispatchQueue.main.async { [weak self] in
            self?.plugin?.notifyListeners("rtcEvent", data: d)
        }
    }

    private func emitAll(_ data: [String: Any]) {
        for id in pcs.keys { emit(id, data) }
    }

    // MARK: state names (the web's strings)
    static func signaling(_ s: RTCSignalingState) -> String {
        switch s {
        case .stable: return "stable"
        case .haveLocalOffer: return "have-local-offer"
        case .haveLocalPrAnswer: return "have-local-pranswer"
        case .haveRemoteOffer: return "have-remote-offer"
        case .haveRemotePrAnswer: return "have-remote-pranswer"
        case .closed: return "closed"
        @unknown default: return "stable"
        }
    }

    static func ice(_ s: RTCIceConnectionState) -> String {
        switch s {
        case .new: return "new"
        case .checking: return "checking"
        case .connected: return "connected"
        case .completed: return "completed"
        case .failed: return "failed"
        case .disconnected: return "disconnected"
        case .closed: return "closed"
        default: return "new"
        }
    }

    static func gathering(_ s: RTCIceGatheringState) -> String {
        switch s {
        case .new: return "new"
        case .gathering: return "gathering"
        case .complete: return "complete"
        @unknown default: return "new"
        }
    }

    static func connection(_ s: RTCPeerConnectionState) -> String {
        switch s {
        case .new: return "new"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .disconnected: return "disconnected"
        case .failed: return "failed"
        case .closed: return "closed"
        @unknown default: return "new"
        }
    }
}
