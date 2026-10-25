// Ninety — call media through our own LiveKit server (v8.69, Mahmoud 25 Oct «الحل الجذري للمكالمات», brief claude/calls-root-fix-brief.md).
//
// What: when both sides of a call can use LiveKit, the page (a902-lk-engine.js) does not open a direct WebRTC connection — each
// side joins the same LiveKit room on our server (wss://lk.2-31-99-134.sslip.io, the design-ws Hetzner host) and the server
// forwards the audio. On the iPhone app the room lives here, in the app (LiveKit Swift SDK, its own LK-prefixed WebRTC), so the
// microphone and the speaker belong to the app under CallKit — lock screen, background, Bluetooth / CarPlay — like a phone call.
// Video calls on the iPhone stay on the old path for now (the page decides).
//
// The page drives it: lkJoin({ pcId, url, token, iceServers, muted }) / lkLeave({ pcId }) / lkMute({ muted }) / lkState({ pcId }),
// events «lkEvent» { pcId, kind: state | peer | peer-left | track | mic | audio | joined | error, … }. rtcMute / rtcSpeaker /
// rtcCloseAll (the call screen's mute, speaker and hang-up, a873) reach LiveKit too.
//
// Audio session (LiveKit's own guide for CallKit): the SDK does not touch AVAudioSession (isAutomaticConfigurationEnabled = false)
// and its audio engine may run only while the call's session is ours — CallKit's didActivate, or the voice-chat session the app
// holds itself when there is no CallKit call (NinetyRTC owns that logic; it calls sync() here on every change).
import Foundation
import AVFoundation
import LiveKit

final class NinetyLKRoom: NSObject, RoomDelegate, @unchecked Sendable {
    let id: String
    let room: Room
    weak var owner: NinetyLK?
    var mic: LocalAudioTrack?          // our own microphone track (with statistics → bytes sent for the call log)

    init(_ id: String, _ owner: NinetyLK) {
        self.id = id
        self.owner = owner
        self.room = Room(delegate: nil,
                         connectOptions: nil,
                         roomOptions: RoomOptions(adaptiveStream: false, dynacast: false, reportRemoteTrackStatistics: true))
        super.init()
        room.add(delegate: self)
    }

    func room(_ room: Room, didUpdateConnectionState connectionState: ConnectionState, from oldConnectionState: ConnectionState) {
        owner?.emit(id, ["kind": "state", "state": NinetyLK.name(connectionState), "peers": room.remoteParticipants.count])
    }

    func roomIsReconnecting(_ room: Room) {
        owner?.emit(id, ["kind": "state", "state": "reconnecting"])
    }

    func roomDidReconnect(_ room: Room) {
        owner?.emit(id, ["kind": "state", "state": "connected", "re": true, "peers": room.remoteParticipants.count])
    }

    func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        owner?.emit(id, ["kind": "peer", "peers": room.remoteParticipants.count])
    }

    func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        owner?.emit(id, ["kind": "peer-left", "peers": room.remoteParticipants.count])
    }

    func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        owner?.emit(id, ["kind": "track", "media": publication.kind == .audio ? "audio" : "video", "peers": room.remoteParticipants.count])
    }

    func room(_ room: Room, didDisconnectWithError error: LiveKitError?) {
        var d: [String: Any] = ["kind": "state", "state": "disconnected"]
        if let error = error { d["error"] = "\(error)" }
        owner?.emit(id, d)
    }
}

final class NinetyLK: NSObject {
    static let shared = NinetyLK()
    weak var plugin: NinetyCallsPlugin?

    private var rooms: [String: NinetyLKRoom] = [:]
    private var prepared = false
    private var muted = false
    private var engineOn = false

    var count: Int { return rooms.count }

    // MARK: setup (main thread)
    private func prepare() {
        if prepared { return }
        prepared = true
        AudioManager.shared.audioSession.isAutomaticConfigurationEnabled = false   // NinetyRTC / CallKit own AVAudioSession
        AudioManager.shared.audioSession.isAutomaticDeactivationEnabled = false
        do { try AudioManager.shared.setEngineAvailability(AudioEngineAvailability.none) } catch { NSLog("[NinetyLK] engine off: \(error)") }
        engineOn = false
    }

    /// the engine runs only while there is a room and the call's audio session is ours (CallKit or held by the app)
    func sync() {
        guard prepared else { return }
        let want = !rooms.isEmpty && NinetyRTC.shared.sessionOurs
        if want == engineOn { return }
        do {
            try AudioManager.shared.setEngineAvailability(want ? AudioEngineAvailability.default : AudioEngineAvailability.none)
            engineOn = want
            emitAll(["kind": "audio", "state": want ? "on" : "off"])
        } catch {
            NSLog("[NinetyLK] engine \(want): \(error)")
            emitAll(["kind": "audio", "state": "error", "error": "\(error)"])
        }
    }

    static func iceServers(_ arr: [Any]) -> [IceServer] {
        var out: [IceServer] = []
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
            out.append(IceServer(urls: urls, username: o["username"] as? String, credential: o["credential"] as? String))
        }
        return out
    }

    // MARK: rooms (main thread)
    func join(_ id: String, url: String, token: String, servers: [IceServer], muted m: Bool, _ done: @escaping (String?) -> Void) {
        guard !id.isEmpty, !url.isEmpty, !token.isEmpty else { done("missing pcId / url / token"); return }
        if rooms[id] != nil { done(nil); return }
        prepare()
        let r = NinetyLKRoom(id, self)
        rooms[id] = r
        muted = m
        NinetyRTC.shared.lkChanged()            // keeps / takes the call's audio session
        sync()
        let opts = ConnectOptions(autoSubscribe: true, iceServers: servers)
        let t0 = Date()
        Task {
            do {
                try await r.room.connect(url: url, token: token, connectOptions: opts)
                let ms = Int(Date().timeIntervalSince(t0) * 1000)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if self.rooms[id] !== r { Task { await r.room.disconnect() }; done("left"); return }
                    done(nil)
                    self.emit(id, ["kind": "joined", "ms": ms, "peers": r.room.remoteParticipants.count])
                    self.publishMic(r)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if self.rooms[id] === r { self.rooms[id] = nil; self.afterLeave() }
                    done("\(error)")
                }
            }
        }
    }

    /// the microphone is published after the room is up (it starts recording once the engine is allowed — CallKit / held session)
    private func publishMic(_ r: NinetyLKRoom) {
        let m = muted
        let id = r.id
        Task {
            do {
                let track = await LocalAudioTrack.createTrack(reportStatistics: true)
                r.mic = track
                _ = try await r.room.localParticipant.publish(audioTrack: track)
                if m { try await track.mute() }
                DispatchQueue.main.async { [weak self] in self?.emit(id, ["kind": "mic", "on": !m]) }
            } catch {
                DispatchQueue.main.async { [weak self] in self?.emit(id, ["kind": "mic", "on": false, "error": "\(error)"]) }
            }
        }
    }

    func leave(_ id: String) {
        guard let r = rooms.removeValue(forKey: id) else { return }
        Task { await r.room.disconnect() }
        afterLeave()
    }

    func leaveAll() {
        let all = Array(rooms.values)
        rooms = [:]
        for r in all { Task { await r.room.disconnect() } }
        afterLeave()
    }

    private func afterLeave() {
        guard rooms.isEmpty else { return }
        muted = false
        sync()
        NinetyRTC.shared.lkChanged()
    }

    func setMuted(_ on: Bool) {
        muted = on
        for (_, r) in rooms {
            let id = r.id
            guard let t = r.mic else { continue }        // not published yet — publishMic reads `muted`
            Task {
                do {
                    if on { try await t.mute() } else { try await t.unmute() }
                } catch {
                    DispatchQueue.main.async { [weak self] in self?.emit(id, ["kind": "mic", "on": !on, "error": "\(error)"]) }
                }
            }
        }
    }

    func state(_ id: String?) -> [String: Any] {
        var out: [String: Any] = ["rooms": rooms.count, "prepared": prepared, "muted": muted, "engineOn": engineOn, "session": NinetyRTC.shared.sessionOurs]
        if prepared {
            out["engine"] = AudioManager.shared.isEngineRunning
            let a = AudioManager.shared.engineAvailability
            out["in"] = a.isInputAvailable
            out["out"] = a.isOutputAvailable
        }
        if let id = id, let r = rooms[id] {
            out["state"] = NinetyLK.name(r.room.connectionState)
            out["peers"] = r.room.remoteParticipants.count
            out["mic"] = r.mic != nil && !(r.mic?.isMuted ?? true)
            var inBytes: UInt64 = 0
            var level: Double = 0
            var remoteAudio = 0
            for (_, p) in r.room.remoteParticipants {
                for pub in p.audioTracks {
                    guard let t = pub.track else { continue }
                    remoteAudio += 1
                    if let s = t.statistics {
                        for x in s.inboundRtpStream {
                            inBytes += x.bytesReceived ?? 0
                            level = max(level, x.audioLevel ?? 0)
                        }
                    }
                }
            }
            var outBytes: UInt64 = 0
            if let s = r.mic?.statistics { for x in s.outboundRtpStream { outBytes += x.bytesSent ?? 0 } }
            out["remoteAudio"] = remoteAudio
            out["inBytes"] = inBytes
            out["outBytes"] = outBytes
            out["level"] = level
        }
        return out
    }

    // MARK: events to the page
    func emit(_ id: String, _ data: [String: Any]) {
        var d = data
        d["pcId"] = id
        DispatchQueue.main.async { [weak self] in
            self?.plugin?.notifyListeners("lkEvent", data: d)
        }
    }

    private func emitAll(_ data: [String: Any]) {
        for id in rooms.keys { emit(id, data) }
    }

    static func name(_ s: ConnectionState) -> String {
        switch s {
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .reconnecting: return "reconnecting"
        case .connected: return "connected"
        case .disconnecting: return "disconnecting"
        @unknown default: return "unknown"
        }
    }
}
