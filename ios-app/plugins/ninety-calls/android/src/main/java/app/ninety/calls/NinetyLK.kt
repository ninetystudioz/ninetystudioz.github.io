package app.ninety.calls

import android.content.Context
import com.getcapacitor.JSObject
import com.twilio.audioswitch.AudioDevice
import io.livekit.android.ConnectOptions
import io.livekit.android.LiveKit
import io.livekit.android.RoomOptions
import io.livekit.android.events.RoomEvent
import io.livekit.android.events.collect
import io.livekit.android.room.Room
import io.livekit.android.room.track.Track
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import livekit.org.webrtc.PeerConnection
import org.json.JSONArray

/**
 * v8.69 — call media through our own LiveKit server (Mahmoud 25 Oct «حل جذري للمكالمات», then «ابنيه جوّه الأندرويد أحسن»).
 * When both sides of a call can use LiveKit, the page (a902-lk-engine.js) does not open a direct WebRTC connection: each side joins
 * the same LiveKit room on our server (wss://lk.2-31-99-134.sslip.io) and the server forwards the audio. In the Android app the
 * room lives here, in the app (LiveKit Android SDK): the microphone and the speaker belong to the app (voice-call mode, audio focus,
 * Bluetooth / wired / earpiece / speaker via AudioSwitch), and a «call in progress» foreground service (CallService, microphone)
 * keeps it talking with the screen off or the app in the background. The web page keeps the call screen, the ringing, nf_calls.
 * Video calls stay in the web view (also through LiveKit when both can).
 * Page → plugin: lkJoin / lkLeave / lkMute / lkSpeaker / lkState; events «lkEvent» { pcId, kind, … } (NinetyCallsPlugin).
 */
object NinetyLK {
    fun interface Sink {
        fun lkEvent(o: JSObject)
    }

    fun interface Done {
        fun done(err: String?)
    }

    fun interface StatsDone {
        fun done(o: JSObject)
    }

    @JvmStatic
    var sink: Sink? = null

    private class R(val id: String, val room: Room) {
        var job: Job? = null
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val rooms = HashMap<String, R>()
    private var muted = false
    private var speaker = false

    @JvmStatic
    fun count(): Int = rooms.size

    private fun iceServers(arr: JSONArray?): List<PeerConnection.IceServer> {
        val out = ArrayList<PeerConnection.IceServer>()
        if (arr == null) return out
        for (i in 0 until arr.length()) {
            val o = arr.optJSONObject(i) ?: continue
            val urls = ArrayList<String>()
            val u = o.opt("urls")
            if (u is String) urls.add(u)
            if (u is JSONArray) for (j in 0 until u.length()) u.optString(j).takeIf { it.isNotEmpty() }?.let { urls.add(it) }
            o.optString("url").takeIf { it.isNotEmpty() }?.let { urls.add(it) }
            if (urls.isEmpty()) continue
            val b = PeerConnection.IceServer.builder(urls)
            o.optString("username").takeIf { it.isNotEmpty() }?.let { b.setUsername(it) }
            o.optString("credential").takeIf { it.isNotEmpty() }?.let { b.setPassword(it) }
            out.add(b.createIceServer())
        }
        return out
    }

    private fun emit(id: String, kind: String, fill: (JSObject) -> Unit = {}) {
        val o = JSObject()
        o.put("pcId", id)
        o.put("kind", kind)
        try { fill(o) } catch (_: Exception) { }
        try { sink?.lkEvent(o) } catch (_: Exception) { }
    }

    /** main thread */
    @JvmStatic
    fun join(ctx: Context, id: String, url: String, token: String, ice: JSONArray?, muted0: Boolean, done: Done) {
        if (id.isEmpty() || url.isEmpty() || token.isEmpty()) { done.done("missing pcId / url / token"); return }
        if (rooms.containsKey(id)) { done.done(null); return }
        val room = LiveKit.create(ctx.applicationContext, RoomOptions(adaptiveStream = false, dynacast = false))
        val r = R(id, room)
        rooms[id] = r
        muted = muted0
        r.job = scope.launch {
            room.events.collect { e ->
                when (e) {
                    is RoomEvent.Connected -> emit(id, "state") { it.put("state", "connected"); it.put("peers", room.remoteParticipants.size) }
                    is RoomEvent.Reconnecting -> emit(id, "state") { it.put("state", "reconnecting") }
                    is RoomEvent.Reconnected -> emit(id, "state") { it.put("state", "connected"); it.put("re", true); it.put("peers", room.remoteParticipants.size) }
                    is RoomEvent.Disconnected -> emit(id, "state") { it.put("state", "disconnected"); it.put("reason", e.reason.toString()); if (e.error != null) it.put("error", e.error.toString()) }
                    is RoomEvent.ParticipantConnected -> emit(id, "peer") { it.put("peers", room.remoteParticipants.size) }
                    is RoomEvent.ParticipantDisconnected -> emit(id, "peer-left") { it.put("peers", room.remoteParticipants.size) }
                    is RoomEvent.TrackSubscribed -> emit(id, "track") { it.put("media", if (e.track.kind == Track.Kind.AUDIO) "audio" else "video"); it.put("peers", room.remoteParticipants.size) }
                    else -> { }
                }
            }
        }
        val t0 = System.currentTimeMillis()
        scope.launch {
            try {
                room.connect(url, token, ConnectOptions(autoSubscribe = true, iceServers = iceServers(ice)))
                if (rooms[id] !== r) { try { room.disconnect(); room.release() } catch (_: Exception) { }; done.done("left"); return@launch }
                done.done(null)
                emit(id, "joined") { it.put("ms", System.currentTimeMillis() - t0); it.put("peers", room.remoteParticipants.size) }
                applySpeaker(r)
                /* v8.71 (calls-lk-fixes #3): a microphone that fails to start is tried again — every 2 s, up to 8 times */
                var tries = 0
                while (rooms[id] === r) {
                    tries += 1
                    try {
                        room.localParticipant.setMicrophoneEnabled(!muted)
                        val n = tries
                        emit(id, "mic") { it.put("on", !muted); it.put("tries", n) }
                        break
                    } catch (ex: Exception) {
                        val n = tries
                        emit(id, "mic") { it.put("on", false); it.put("error", ex.toString()); it.put("tries", n) }
                        if (tries >= 8) break
                        kotlinx.coroutines.delay(2000)
                    }
                }
            } catch (ex: Throwable) {
                if (rooms[id] === r) {
                    rooms.remove(id)
                    r.job?.cancel()
                    try { room.release() } catch (_: Exception) { }
                }
                done.done(ex.toString())
            }
        }
    }

    @JvmStatic
    fun leave(id: String) {
        val r = rooms.remove(id) ?: return
        close(r)
        if (rooms.isEmpty()) { muted = false; speaker = false }
    }

    @JvmStatic
    fun leaveAll() {
        val all = ArrayList(rooms.values)
        rooms.clear()
        for (r in all) close(r)
        muted = false
        speaker = false
    }

    private fun close(r: R) {
        r.job?.cancel()
        try { r.room.disconnect() } catch (_: Exception) { }
        try { r.room.release() } catch (_: Exception) { }
    }

    @JvmStatic
    fun setMuted(on: Boolean) {
        muted = on
        for (r in rooms.values) {
            scope.launch {
                try { r.room.localParticipant.setMicrophoneEnabled(!on) } catch (ex: Exception) { emit(r.id, "mic") { it.put("on", !on); it.put("error", ex.toString()) } }
            }
        }
    }

    @JvmStatic
    fun setSpeaker(on: Boolean) {
        speaker = on
        for (r in rooms.values) applySpeaker(r)
    }

    /** speaker on → the loudspeaker; off → back to the usual order (Bluetooth, wired headset, earpiece) */
    private fun applySpeaker(r: R) {
        try {
            val h = r.room.audioSwitchHandler ?: return
            if (speaker) {
                val dev = h.availableAudioDevices.firstOrNull { it is AudioDevice.Speakerphone }
                if (dev != null) h.selectDevice(dev)
            } else {
                h.selectDevice(null)
            }
        } catch (_: Exception) { }
    }

    @JvmStatic
    fun state(id: String?): JSObject {
        val o = JSObject()
        o.put("rooms", rooms.size)
        o.put("muted", muted)
        o.put("speaker", speaker)
        val r = if (id != null) rooms[id] else null
        if (r != null) {
            o.put("state", r.room.state.name.lowercase())
            o.put("peers", r.room.remoteParticipants.size)
            o.put("mic", r.room.localParticipant.isMicrophoneEnabled)
            var remoteAudio = 0
            for (p in r.room.remoteParticipants.values) remoteAudio += p.audioTrackPublications.count { it.first.subscribed }
            o.put("remoteAudio", remoteAudio)
            try { o.put("device", r.room.audioSwitchHandler?.selectedAudioDevice?.name ?: "") } catch (_: Exception) { }
        }
        return o
    }

    /** audio bytes in / out + packets / loss / jitter / round trip + the incoming level — both connections of the room, every
     *  stats type read from both reports (v8.71, calls-lk-fixes #4/#5: the subscriber report alone gave inBytes 0 on 25 Oct) */
    @JvmStatic
    fun stats(id: String?, done: StatsDone) {
        val o = state(id)
        val r = if (id != null) rooms[id] else null
        if (r == null) { done.done(o); return }
        var inBytes = 0L
        var outBytes = 0L
        var pRecv = 0L
        var pLost = 0L
        var jitter = 0.0
        var level = 0.0
        var fLost = -1.0
        var rtt = -1.0
        var left = 2
        var sent = false
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        fun num(v: Any?): Double = (v as? Number)?.toDouble() ?: 0.0
        fun finish() {
            left -= 1
            if (left > 0 || sent) return
            sent = true
            o.put("inBytes", inBytes)
            o.put("outBytes", outBytes)
            o.put("level", level)
            o.put("packetsReceived", pRecv)
            o.put("packetsLost", pLost)
            o.put("jitter", jitter)
            if (fLost >= 0) o.put("fractionLost", fLost)
            if (rtt >= 0) o.put("rtt", rtt)
            done.done(o)
        }
        val read = livekit.org.webrtc.RTCStatsCollectorCallback { rep ->
            main.post {
                try {
                    for (st in rep.statsMap.values) {
                        val m = st.members
                        val audio = (m["kind"] ?: m["mediaType"]) == "audio"
                        when (st.type) {
                            "inbound-rtp" -> if (audio) {
                                inBytes += num(m["bytesReceived"]).toLong()
                                pRecv += num(m["packetsReceived"]).toLong()
                                pLost += maxOf(0L, num(m["packetsLost"]).toLong())
                                jitter = maxOf(jitter, num(m["jitter"]))
                                level = maxOf(level, num(m["audioLevel"]))
                            }
                            "outbound-rtp" -> if (audio) outBytes += num(m["bytesSent"]).toLong()
                            "remote-inbound-rtp" -> if (audio) {
                                if (m["fractionLost"] != null) fLost = maxOf(fLost, num(m["fractionLost"]))
                                if (m["roundTripTime"] != null) rtt = maxOf(rtt, num(m["roundTripTime"]))
                            }
                            "candidate-pair" -> if (m["state"] == "succeeded" && m["nominated"] == true && m["currentRoundTripTime"] != null) rtt = maxOf(rtt, num(m["currentRoundTripTime"]))
                        }
                    }
                } catch (_: Exception) { }
                finish()
            }
        }
        try { r.room.getSubscriberRTCStats(read) } catch (_: Exception) { main.post { finish() } }
        try { r.room.getPublisherRTCStats(read) } catch (_: Exception) { main.post { finish() } }
        main.postDelayed({ left = 0; if (!sent) { left = 1; finish() } }, 3000)   // a report that never comes back does not hold the page
    }
}
