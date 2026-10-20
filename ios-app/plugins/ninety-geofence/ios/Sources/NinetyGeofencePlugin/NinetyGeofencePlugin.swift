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

@objc(NinetyGeofencePlugin)
public class NinetyGeofencePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "NinetyGeofencePlugin"
    public let jsName = "NinetyGeofence"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "status", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "request", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setup", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "clear", returnType: CAPPluginReturnPromise)
    ]

    override public func load() {
        // the shared core owns the CLLocationManager delegate from launch, so a background relaunch on a region event is handled
        _ = NinetyGeoCore.shared
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

    @objc func clear(_ call: CAPPluginCall) {
        DispatchQueue.main.async { NinetyGeoCore.shared.clear(); call.resolve(self.st()) }
    }
}
