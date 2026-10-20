// Ninety — Apple Pencil for the iPad app.
// v7.48 (note 5): double-tap (Pencil 2 / Pro) and squeeze (Pencil Pro) → window event 'nfpencil' { kind, x, y }.
//   The person's own iPad setting is respected: a double-tap set to «Ignore» in Settings → Apple Pencil is not sent.
// v8.08 (brief «كونسبت بقلم أبل المباشر», Mahmoud 20 Oct: «موافق، ابدأ»): Apple's own ink (PencilKit) while drawing in Concept.
//   The page turns it on for the drawing area only (kit({on:true, area, ex, color, alpha, width, ink})). Then:
//   - the line under the pen tip is drawn by PencilKit (Apple's lowest-latency ink, with its pen prediction);
//   - the same touches (every coalesced point: place, pressure, tilt, time) go to the page as they happen
//     (window event 'nfink' { k:'d'|'m'|'u'|'c'|'b', s, p:[[x, y, pressure, altitude, azimuth, ms], …] }),
//     so the page's own engine builds the real line (brushes, layers, saving, undo stay exactly as they are);
//   - when the page has drawn it, it calls kitAck({s}) and the Apple ink of that line is taken away.
//   Fingers are never touched (zoom / move stay the page's). A pencil touch that starts on a button or panel the page lists
//   in `ex` goes to the page as before and draws nothing. Nothing here is on unless the page asks for it.
// JS: Capacitor.Plugins.NinetyPencil.info() → { available, pencilOnly, kit }
import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass
import Capacitor
import PencilKit

/// A pencil touch that starts where the page has a button: recognised at once (so PencilKit, which waits for it to fail,
/// draws nothing) and never stops the page from getting the touch.
final class NFInkGate: UIGestureRecognizer {
    var blocked: ((CGPoint) -> Bool)?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        // fingers (and a resting hand) are not ours: ignored, so a pencil touch that comes while they are down is still checked
        touches.filter { $0.type != .pencil }.forEach { ignore($0, for: event) }
        guard state == .possible, let t = touches.first(where: { $0.type == .pencil }), let v = view else { return }
        state = blocked?(t.location(in: v)) == true ? .began : .failed
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began || state == .changed { state = .changed }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began || state == .changed { state = .ended } else if state == .possible { state = .failed }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began || state == .changed { state = .cancelled } else if state == .possible { state = .failed }
    }
}

/// Follows one pencil touch in the drawing area and hands every point to the plugin. Never cancels or delays anything.
final class NFInkRec: UIGestureRecognizer {
    var blocked: ((CGPoint) -> Bool)?
    var emit: ((String, [[Double]]) -> Void)?
    private weak var touch: UITouch?

    private func pts(_ t: UITouch, _ event: UIEvent?, all: Bool) -> [[Double]] {
        guard let v = view else { return [] }
        let list = all ? (event?.coalescedTouches(for: t) ?? [t]) : [t]
        return list.map { c in
            let p = c.preciseLocation(in: v)
            let mx = c.maximumPossibleForce > 0 ? c.maximumPossibleForce : 4.1667
            let f = c.force > 0 ? min(1, Double(c.force / mx)) : 0.5
            return [(Double(p.x) * 100).rounded() / 100, (Double(p.y) * 100).rounded() / 100, (f * 1000).rounded() / 1000,
                    (Double(c.altitudeAngle) * 1000).rounded() / 1000, (Double(c.azimuthAngle(in: v)) * 1000).rounded() / 1000,
                    (c.timestamp * 100000).rounded() / 100]
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        touches.filter { $0.type != .pencil }.forEach { ignore($0, for: event) }
        guard touch == nil, let t = touches.first(where: { $0.type == .pencil }), let v = view else { return }
        if blocked?(t.location(in: v)) == true { ignore(t, for: event); return }
        touch = t
        state = .began
        emit?("d", pts(t, event, all: false))
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let t = touch, touches.contains(t) else { return }
        state = .changed
        emit?("m", pts(t, event, all: true))
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let t = touch, touches.contains(t) else { return }
        emit?("u", pts(t, event, all: true))
        touch = nil
        state = .ended
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let t = touch, touches.contains(t) else { return }
        emit?("c", [])
        touch = nil
        state = .cancelled
    }
    override func reset() { touch = nil; super.reset() }
    var drawing: Bool { touch != nil }
}

@objc(NinetyPencilPlugin)
public class NinetyPencilPlugin: CAPPlugin, CAPBridgedPlugin, UIPencilInteractionDelegate, UIGestureRecognizerDelegate, PKCanvasViewDelegate {
    public let identifier = "NinetyPencilPlugin"
    public let jsName = "NinetyPencil"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "info", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "kit", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "kitAck", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "kitDrop", returnType: CAPPluginReturnPromise)
    ]
    private var interaction: UIPencilInteraction?

    // v8.08 Apple ink
    private var canvas: PKCanvasView?
    private var gate: NFInkGate?
    private var rec: NFInkRec?
    private var area = CGRect.zero
    private var ex: [CGRect] = []
    private var seq = 0              // the pencil line being drawn (or the last one)
    private var owed = 0             // lines the page has drawn whose Apple ink is still to be taken away
    private var dropped = -1         // a line the page turned into something else (a shape, the wheel): its ack is not counted
    private var trimming = false
    private var lastInk = Date()
    private var watchdog: Timer?

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
            only = UIPencilInteraction.prefersPencilOnlyDrawing
            call.resolve(["available": UIDevice.current.userInterfaceIdiom == .pad, "pencilOnly": only, "kit": UIDevice.current.userInterfaceIdiom == .pad])
        }
    }

    // MARK: double-tap / squeeze
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

    // MARK: v8.08 Apple ink
    private func rect(_ v: Any?) -> CGRect? {
        guard let a = v as? [Any], a.count >= 4 else { return nil }
        let n = a.compactMap { ($0 as? NSNumber)?.doubleValue }
        guard n.count >= 4, n.allSatisfy({ $0.isFinite }) else { return nil }
        return CGRect(x: n[0], y: n[1], width: max(0, n[2]), height: max(0, n[3]))
    }

    private func blocked(_ p: CGPoint) -> Bool {
        if !area.contains(p) { return true }
        return ex.contains { $0.contains(p) }
    }

    private func color(_ hex: String?, _ alpha: Double) -> UIColor {
        var s = (hex ?? "#000000").trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: String(s.prefix(6))).scanHexInt64(&v)
        return UIColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255,
                       alpha: CGFloat(max(0.05, min(1, alpha))))
    }

    @objc func kit(_ call: CAPPluginCall) {
        let on = call.getBool("on") ?? false
        let a = rect(call.getArray("area")), e = (call.getArray("ex") ?? []).compactMap { rect($0) }
        let hex = call.getString("color"), alpha = call.getDouble("alpha") ?? 1, width = call.getDouble("width") ?? 3
        let ink = call.getString("ink") ?? "pen"
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard on, UIDevice.current.userInterfaceIdiom == .pad, let wv = self.bridge?.webView else {
                self.kitStop(); call.resolve(["ok": true, "on": false]); return
            }
            if let a = a { self.area = a }
            self.ex = e
            if self.canvas == nil { self.kitStart(wv) }
            guard let cv = self.canvas else { call.resolve(["ok": false, "on": false]); return }
            let type: PKInkingTool.InkType = ink == "pencil" ? .pencil : ink == "marker" ? .marker : .pen
            cv.tool = PKInkingTool(type, color: self.color(hex, alpha), width: CGFloat(max(0.5, min(80, width))))
            call.resolve(["ok": true, "on": true])
        }
    }

    private func kitStart(_ wv: UIView) {
        let cv = PKCanvasView(frame: wv.bounds)
        cv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cv.backgroundColor = .clear
        cv.isOpaque = false
        cv.overrideUserInterfaceStyle = .light          // the colour is drawn as it is (no dark-mode swap)
        cv.drawingPolicy = .pencilOnly
        cv.isScrollEnabled = false
        cv.contentInsetAdjustmentBehavior = .never
        cv.isUserInteractionEnabled = false             // touches still reach the page; the ink follows the pen through
        cv.delegate = self                              // the drawing recogniser, which now sits on the web view itself
        wv.addSubview(cv)
        let dg = cv.drawingGestureRecognizer
        wv.addGestureRecognizer(dg)
        let g = NFInkGate(target: nil, action: nil)
        g.cancelsTouchesInView = false; g.delaysTouchesBegan = false; g.delaysTouchesEnded = false
        g.delegate = self
        g.blocked = { [weak self] p in self?.blocked(p) ?? true }
        wv.addGestureRecognizer(g)
        dg.require(toFail: g)
        let r = NFInkRec(target: nil, action: nil)
        r.cancelsTouchesInView = false; r.delaysTouchesBegan = false; r.delaysTouchesEnded = false
        r.delegate = self
        r.blocked = { [weak self] p in self?.blocked(p) ?? true }
        r.emit = { [weak self] k, p in self?.emit(k, p) }
        wv.addGestureRecognizer(r)
        canvas = cv; gate = g; rec = r; owed = 0; dropped = -1
        watchdog?.invalidate()
        watchdog = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // ink the page never confirmed (it was busy or went away) does not stay on the screen
            guard let self = self, let cv = self.canvas, !(self.rec?.drawing ?? false), !cv.drawing.strokes.isEmpty,
                  Date().timeIntervalSince(self.lastInk) > 2.5 else { return }
            self.clearInk()
        }
    }

    private func kitStop() {
        watchdog?.invalidate(); watchdog = nil
        if let wv = bridge?.webView {
            let gs: [UIGestureRecognizer?] = [gate, rec]
            gs.forEach { if let g = $0 { wv.removeGestureRecognizer(g) } }
            if let cv = canvas { wv.removeGestureRecognizer(cv.drawingGestureRecognizer) }
        }
        canvas?.removeFromSuperview()
        canvas = nil; gate = nil; rec = nil; owed = 0
    }

    private func clearInk() {
        guard let cv = canvas else { return }
        trimming = true
        cv.drawing = PKDrawing()
        trimming = false
        owed = 0
    }

    private func emit(_ k: String, _ p: [[Double]]) {
        if k == "d" { seq += 1 }
        lastInk = Date()
        var js = "{\"k\":\"\(k)\",\"s\":\(seq),\"p\":["
        js += p.map { "[" + $0.map { $0.isFinite ? String($0) : "0" }.joined(separator: ",") + "]" }.joined(separator: ",")
        js += "]}"
        bridge?.triggerWindowJSEvent(eventName: "nfink", data: js)
    }

    /// The page has drawn line `s`: take its Apple ink away (now, or as soon as PencilKit has added it).
    @objc func kitAck(_ call: CAPPluginCall) {
        let s = call.getInt("s") ?? -2
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if s != self.dropped { self.owed += 1; self.trim() }
            call.resolve()
        }
    }

    /// The page made the line something else (a straight line, a shape, the wheel at the pen): no Apple ink for it.
    @objc func kitDrop(_ call: CAPPluginCall) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let cv = self.canvas else { call.resolve(); return }
            self.dropped = self.seq
            let dg = cv.drawingGestureRecognizer
            dg.isEnabled = false; dg.isEnabled = true    // stops the ink of the line in progress
            self.clearInk()
            call.resolve()
        }
    }

    private func trim() {
        guard let cv = canvas, owed > 0 else { return }
        let have = cv.drawing.strokes.count
        let n = min(owed, have)
        guard n > 0 else { return }
        trimming = true
        cv.drawing = PKDrawing(strokes: Array(cv.drawing.strokes.dropFirst(n)))
        trimming = false
        owed -= n
    }

    public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        if trimming { return }
        lastInk = Date()
        trim()
    }

    public func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        lastInk = Date()
        bridge?.triggerWindowJSEvent(eventName: "nfink", data: "{\"k\":\"b\",\"s\":\(seq)}")
    }

    // the gate and the follower never stop the page (or each other) from getting a touch
    public func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return g === gate || g === rec
    }
}
