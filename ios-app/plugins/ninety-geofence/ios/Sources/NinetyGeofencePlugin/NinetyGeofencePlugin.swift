// Ninety — native geofence (v8.14, brief claude/geofence-brief.md). iPhone: region monitoring (CLCircularRegion) — iOS relaunches the
// app in the background on enter / exit even when it was closed; the event goes to the factory server (Edge geo-ping) with a device token.
// JS: Capacitor.Plugins.NinetyGeofence.status() · .request() · .setup({ url, token, regions: [{ id, lat, lng, radius }] }) · .clear()
import Foundation
import CoreLocation
import UIKit
import Capacitor

final class NinetyGeoCore: NSObject, CLLocationManagerDelegate {
    static let shared = NinetyGeoCore()
    let manager = CLLocationManager()
    var pendingAuth: ((CLAuthorizationStatus) -> Void)?
    private let ud = UserDefaults.standard

    override init() {
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = false
    }

    var url: String? { ud.string(forKey: "nf.geo.url") }
    var token: String? { ud.string(forKey: "nf.geo.token") }
    var regionsJSON: String { ud.string(forKey: "nf.geo.regions") ?? "[]" }

    func status() -> CLAuthorizationStatus { manager.authorizationStatus }

    func save(url: String, token: String, regions: [[String: Any]]) {
        ud.set(url, forKey: "nf.geo.url"); ud.set(token, forKey: "nf.geo.token")
        if let d = try? JSONSerialization.data(withJSONObject: regions), let s = String(data: d, encoding: .utf8) { ud.set(s, forKey: "nf.geo.regions") }
    }

    @discardableResult
    func register() -> Int {
        for r in manager.monitoredRegions where r.identifier.hasPrefix("nf.") { manager.stopMonitoring(for: r) }
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self),
              let d = regionsJSON.data(using: .utf8),
              let arr = (try? JSONSerialization.jsonObject(with: d)) as? [[String: Any]] else { return 0 }
        var n = 0
        for r in arr.prefix(18) {
            guard let lat = r["lat"] as? Double, let lng = r["lng"] as? Double else { continue }
            let rad = max(100.0, min((r["radius"] as? Double) ?? 200.0, manager.maximumRegionMonitoringDistance))
            let id = "nf." + ((r["id"] as? String) ?? "factory")
            let reg = CLCircularRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lng), radius: rad, identifier: id)
            reg.notifyOnEntry = true; reg.notifyOnExit = true
            manager.startMonitoring(for: reg)
            n += 1
        }
        return n
    }

    func clear() {
        for r in manager.monitoredRegions where r.identifier.hasPrefix("nf.") { manager.stopMonitoring(for: r) }
        ["nf.geo.url", "nf.geo.token", "nf.geo.regions"].forEach { ud.removeObject(forKey: $0) }
    }

    func send(_ ev: String, _ region: String) {
        guard let u = url, let t = token, let target = URL(string: u) else { return }
        var bg: UIBackgroundTaskIdentifier = .invalid
        bg = UIApplication.shared.beginBackgroundTask { UIApplication.shared.endBackgroundTask(bg); bg = .invalid }
        var req = URLRequest(url: target, timeoutInterval: 20)
        req.httpMethod = "POST"; req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["action": "event", "token": t, "ev": ev, "region": region, "at": Date().timeIntervalSince1970 * 1000])
        URLSession.shared.dataTask(with: req) { _, _, _ in
            if bg != .invalid { UIApplication.shared.endBackgroundTask(bg); bg = .invalid }
        }.resume()
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier.hasPrefix("nf.") else { return }
        send("enter", String(region.identifier.dropFirst(3)))
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier.hasPrefix("nf.") else { return }
        send("exit", String(region.identifier.dropFirst(3)))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if let cb = pendingAuth, manager.authorizationStatus != .notDetermined { pendingAuth = nil; cb(manager.authorizationStatus) }
    }
}


// v11.24 — the route of a trip the driver started, recorded by the phone itself while it is locked (blue location indicator).
// A point every ~10 m, sent to the factory server (Edge geo-ping, action «trip») every 30 s. Stops on tripStop, when the
// server answers that the trip is over, or after 14 hours.
final class NinetyTripCore: NSObject, CLLocationManagerDelegate {
    static let shared = NinetyTripCore()
    let manager = CLLocationManager()
    private let ud = UserDefaults.standard
    private var buf: [[String: Any]] = []
    private var timer: Timer?
    private var sending = false
    private let fmt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        if let a = ud.array(forKey: "nf.trip.buf") as? [[String: Any]] { buf = a }
    }

    var tripId: String? { ud.string(forKey: "nf.trip.id") }
    var running: Bool { tripId != nil && timer != nil }

    private func authorized() -> Bool {
        let s = manager.authorizationStatus
        return s == .authorizedAlways || s == .authorizedWhenInUse
    }

    func start(url: String, token: String, tripId: String) -> Bool {
        guard authorized() else { return false }
        let same = self.tripId == tripId
        ud.set(url, forKey: "nf.trip.url"); ud.set(token, forKey: "nf.trip.token"); ud.set(tripId, forKey: "nf.trip.id")
        if !same || ud.object(forKey: "nf.trip.since") == nil { ud.set(Date().timeIntervalSince1970, forKey: "nf.trip.since") }
        begin()
        return true
    }

    /// after the app was relaunched while a trip was running
    func resumeIfNeeded() {
        guard tripId != nil, timer == nil else { return }
        if expired() || !authorized() { stop(sendLast: false); return }
        begin()
    }

    private func expired() -> Bool {
        let since = ud.double(forKey: "nf.trip.since")
        return since > 0 && Date().timeIntervalSince1970 - since > 14 * 3600
    }

    private func begin() {
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.expired() { self.stop(sendLast: true); return }
                self.flush(last: false)
            }
        }
    }

    func stop(sendLast: Bool) {
        timer?.invalidate(); timer = nil
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        if sendLast { flush(last: true) }
        ud.removeObject(forKey: "nf.trip.id"); ud.removeObject(forKey: "nf.trip.since")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for l in locations where l.horizontalAccuracy >= 0 {
            var o: [String: Any] = [
                "lat": (l.coordinate.latitude * 1e6).rounded() / 1e6,
                "lng": (l.coordinate.longitude * 1e6).rounded() / 1e6,
                "at": fmt.string(from: l.timestamp),
                "acc": Int(l.horizontalAccuracy.rounded())
            ]
            if l.speed >= 0 { o["kmh"] = Int((l.speed * 3.6).rounded()) }
            buf.append(o)
        }
        if buf.count > 900 { buf = Array(buf.suffix(900)) }
        ud.set(buf, forKey: "nf.trip.buf")
        if buf.count >= 40 { flush(last: false) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { }

    func flush(last: Bool) {
        guard !sending, !buf.isEmpty,
              let u = ud.string(forKey: "nf.trip.url"), let t = ud.string(forKey: "nf.trip.token"),
              let target = URL(string: u) else { return }
        let id = ud.string(forKey: "nf.trip.id") ?? ud.string(forKey: "nf.trip.last") ?? ""
        if id.isEmpty { return }
        ud.set(id, forKey: "nf.trip.last")
        let batch = buf
        sending = true
        var bg: UIBackgroundTaskIdentifier = .invalid
        bg = UIApplication.shared.beginBackgroundTask { UIApplication.shared.endBackgroundTask(bg); bg = .invalid }
        var req = URLRequest(url: target, timeoutInterval: 20)
        req.httpMethod = "POST"; req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["action": "trip", "token": t, "tripId": id, "pts": batch, "last": last])
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            DispatchQueue.main.async {
                self.sending = false
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                var stop = code == 403
                if code == 200 {
                    self.buf = Array(self.buf.dropFirst(min(batch.count, self.buf.count)))
                    self.ud.set(self.buf, forKey: "nf.trip.buf")
                    if let d = data, let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any], (j["stop"] as? Bool) == true { stop = true }
                }
                if stop && !last && self.tripId != nil { self.stop(sendLast: false) }
                if bg != .invalid { UIApplication.shared.endBackgroundTask(bg); bg = .invalid }
            }
        }.resume()
    }
}

@objc(NinetyGeofencePlugin)
public class NinetyGeofencePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NinetyGeofencePlugin"
    public let jsName = "NinetyGeofence"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "status", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "request", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setup", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "clear", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "tripStart", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "tripStop", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "tripStatus", returnType: CAPPluginReturnPromise)
    ]

    override public func load() {
        // the shared core owns the CLLocationManager delegate from launch, so a background relaunch on a region event is handled
        _ = NinetyGeoCore.shared
        DispatchQueue.main.async { NinetyTripCore.shared.resumeIfNeeded() }
    }

    private func st() -> [String: Any] {
        let s = NinetyGeoCore.shared.status()
        return ["location": s == .authorizedAlways || s == .authorizedWhenInUse, "background": s == .authorizedAlways,
                "regions": NinetyGeoCore.shared.regionsJSON, "platform": "ios"]
    }

    @objc func status(_ call: CAPPluginCall) { call.resolve(st()) }

    @objc func request(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let core = NinetyGeoCore.shared
            let s = core.status()
            if s == .authorizedAlways { core.register(); call.resolve(self.st()); return }
            core.pendingAuth = { _ in
                if core.status() == .authorizedWhenInUse {
                    core.pendingAuth = { _ in core.register(); call.resolve(self.st()) }
                    core.manager.requestAlwaysAuthorization()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8) { if core.pendingAuth != nil { core.pendingAuth = nil; core.register(); call.resolve(self.st()) } }
                    return
                }
                core.register(); call.resolve(self.st())
            }
            if s == .notDetermined { core.manager.requestWhenInUseAuthorization() } else { core.manager.requestAlwaysAuthorization() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { if core.pendingAuth != nil { core.pendingAuth = nil; call.resolve(self.st()) } }
        }
    }

    @objc func setup(_ call: CAPPluginCall) {
        guard let url = call.getString("url"), let token = call.getString("token") else { call.reject("url / token missing"); return }
        let regions: [[String: Any]] = (call.getArray("regions") ?? []).compactMap { $0 as? [String: Any] }
        DispatchQueue.main.async {
            NinetyGeoCore.shared.save(url: url, token: token, regions: regions)
            var o = self.st(); o["registered"] = NinetyGeoCore.shared.register()
            call.resolve(o)
        }
    }

    @objc func tripStart(_ call: CAPPluginCall) {
        guard let url = call.getString("url"), let token = call.getString("token"), let tripId = call.getString("tripId") else { call.reject("url / token / tripId missing"); return }
        DispatchQueue.main.async {
            if NinetyTripCore.shared.start(url: url, token: token, tripId: tripId) { call.resolve(["running": true, "tripId": tripId]) } else { call.reject("no-location") }
        }
    }

    @objc func tripStop(_ call: CAPPluginCall) {
        DispatchQueue.main.async { NinetyTripCore.shared.stop(sendLast: true); call.resolve(["running": false]) }
    }

    @objc func tripStatus(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let c = NinetyTripCore.shared
            var o: [String: Any] = ["running": c.running, "platform": "ios"]
            if let t = c.tripId { o["tripId"] = t }
            call.resolve(o)
        }
    }

    @objc func clear(_ call: CAPPluginCall) {
        DispatchQueue.main.async { NinetyGeoCore.shared.clear(); call.resolve(self.st()) }
    }
}
