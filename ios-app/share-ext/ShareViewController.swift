// Ninety — iPhone share extension (v7.57): «Share» → Ninety → pick the task → the photo / PDF lands in the task chat.
// The list of tasks, the server address and a device token come from the Ninety app (shared keychain item written by the
// NinetyShare plugin every time a task is opened and when the app goes to the background). Nothing secret is in this file.
// v9.71 (Mahmoud 3 Nov: bank app → screenshot → Share → Ninety → «فلوس مستنياك» + the order with the same amount): a button
// «افتح في Ninety» on top — the shared files are left in the same shared keychain group (items «inbox» + «inbox.N»), the Ninety
// app is opened (app.ninety.fabrication://share) and its NinetyShare plugin hands them to the web page (#/share, same as Android).
// If iOS does not open the app, the files still wait there: opening Ninety by hand shows them. «ابعت لـ: مهمة» stays as it was.
import UIKit
import Security
import UniformTypeIdentifiers

private struct ShareTask: Decodable { let id: String; let title: String; let sub: String?; let money: Bool?; let at: Double? }
private struct ShareCtx: Decodable { let v: Int?; let endpoint: String; let token: String; let lang: String?; let name: String?; let sys: String?; let tasks: [ShareTask]?; let at: Double? }
private struct Picked { let name: String; let mime: String; let data: Data; let thumb: String?; let preview: UIImage? }
private final class PickBox { var items = [Int: Picked](); let lock = NSLock() }

private let kGroup = "UF4QLJ9AY9.app.ninety.shared"
private let kService = "app.ninety.share"

private func readCtx() -> ShareCtx? {
    let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: kService, kSecAttrAccount as String: "ctx",
                            kSecAttrAccessGroup as String: kGroup, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
    var out: CFTypeRef?
    guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
    return try? JSONDecoder().decode(ShareCtx.self, from: d)
}

// v9.71 «افتح في Ninety»: the files for the app, in the shared keychain group (the app and the extension already share it —
// no App Group needed). The manifest «inbox» is written last, so the app never sees half a set.
private let kAppURL = "app.ninety.fabrication://share"
private let kInboxMaxFile = 8 * 1024 * 1024
private let kInboxMaxTotal = 16 * 1024 * 1024
private func kcQuery(_ account: String) -> [String: Any] {
    return [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: kService, kSecAttrAccount as String: account, kSecAttrAccessGroup as String: kGroup]
}
private func kcPut(_ account: String, _ data: Data) -> Bool {
    let q = kcQuery(account)
    SecItemDelete(q as CFDictionary)
    var add = q
    add[kSecValueData as String] = data
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
}
private func clearInbox() {
    SecItemDelete(kcQuery("inbox") as CFDictionary)
    for i in 0..<10 { SecItemDelete(kcQuery("inbox.\(i)") as CFDictionary) }
}

class ShareViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private var ctx: ShareCtx?
    private var tasks: [ShareTask] = []
    private var selected: String?
    private var picked: [Picked] = []
    private var loading = true
    private var sending = false
    private var ar: Bool { (ctx?.lang ?? "ar") != "en" }
    private func t(_ a: String, _ e: String) -> String { ar ? a : e }

    private let bar = UINavigationBar()
    private let navItem = UINavigationItem()
    private let openBtn = UIButton(type: .system)
    private let thumbs = UIStackView()
    private let thumbsScroll = UIScrollView()
    private let caption = UITextField()
    private let toLabel = UILabel()
    private let table = UITableView(frame: .zero, style: .plain)
    private let proofRow = UIStackView()
    private let proofLabel = UILabel()
    private let proofSwitch = UISwitch()
    private let note = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        ctx = readCtx()
        tasks = ctx?.tasks ?? []
        let now = Date().timeIntervalSince1970 * 1000
        if let first = tasks.first, let at = first.at, at > 0, now - at < 3600 * 1000 { selected = first.id }
        view.backgroundColor = .systemBackground
        view.semanticContentAttribute = ar ? .forceRightToLeft : .forceLeftToRight
        buildUI()
        if ctx == nil {
            // v9.71: not signed in here yet — «افتح في Ninety» still works (the app shows the files after the sign-in)
            note.text = t("افتح أبلكيشن Ninety وسجّل دخولك مرة، وبعدين جرّب المشاركة تاني.", "Open the Ninety app and sign in once, then share again.")
            note.isHidden = false; table.isHidden = true; caption.isHidden = true; toLabel.isHidden = true
        }
        loadAttachments()
    }

    private func buildUI() {
        bar.translatesAutoresizingMaskIntoConstraints = false
        navItem.title = ctx?.sys ?? "Ninety"
        navItem.leftBarButtonItem = UIBarButtonItem(title: t("إلغاء", "Cancel"), style: .plain, target: self, action: #selector(cancel))
        navItem.rightBarButtonItem = UIBarButtonItem(title: t("ابعت", "Send"), style: .done, target: self, action: #selector(send))
        bar.setItems([navItem], animated: false)
        view.addSubview(bar)

        // v9.71: «افتح في Ninety» — the transfers path (the web page «حوّلت إيه؟» lists the money waiting and the matching order)
        openBtn.translatesAutoresizingMaskIntoConstraints = false
        var oc = UIButton.Configuration.filled()
        oc.title = t("افتح في Ninety", "Open in Ninety")
        oc.subtitle = t("للتحويلات: تشوف «فلوس مستنياك» وتختار الأمر", "For transfers: see the money waiting and pick the order")
        oc.image = UIImage(systemName: "arrow.up.forward.app")
        oc.imagePadding = 8
        oc.titleAlignment = .leading
        oc.cornerStyle = .large
        openBtn.configuration = oc
        openBtn.contentHorizontalAlignment = .leading
        openBtn.semanticContentAttribute = ar ? .forceRightToLeft : .forceLeftToRight
        openBtn.addTarget(self, action: #selector(openInApp), for: .touchUpInside)
        view.addSubview(openBtn)

        thumbsScroll.translatesAutoresizingMaskIntoConstraints = false
        thumbsScroll.showsHorizontalScrollIndicator = false
        thumbs.axis = .horizontal; thumbs.spacing = 8; thumbs.translatesAutoresizingMaskIntoConstraints = false
        thumbsScroll.addSubview(thumbs)
        view.addSubview(thumbsScroll)

        caption.translatesAutoresizingMaskIntoConstraints = false
        caption.placeholder = t("اكتب تعليق (اختياري)", "Add a caption (optional)")
        caption.borderStyle = .roundedRect
        caption.textAlignment = ar ? .right : .left
        caption.returnKeyType = .done
        caption.addTarget(self, action: #selector(endEdit), for: .editingDidEndOnExit)
        view.addSubview(caption)

        toLabel.translatesAutoresizingMaskIntoConstraints = false
        toLabel.text = t("ابعت لـ:", "Send to:")
        toLabel.font = .boldSystemFont(ofSize: 15)
        toLabel.textAlignment = ar ? .right : .left
        view.addSubview(toLabel)

        proofRow.translatesAutoresizingMaskIntoConstraints = false
        proofRow.axis = .horizontal; proofRow.spacing = 8; proofRow.alignment = .center
        proofLabel.text = t("سجّلها إثبات التحويل (هتظهرلك لما تفتح Ninety)", "Record it as the transfer (shown when you open Ninety)")
        proofLabel.font = .systemFont(ofSize: 13); proofLabel.numberOfLines = 2
        proofLabel.textAlignment = ar ? .right : .left
        proofSwitch.isOn = true
        proofRow.addArrangedSubview(proofLabel); proofRow.addArrangedSubview(proofSwitch)
        proofRow.isHidden = true
        view.addSubview(proofRow)

        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self; table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        table.tableFooterView = UIView()
        view.addSubview(table)

        note.translatesAutoresizingMaskIntoConstraints = false
        note.numberOfLines = 0; note.textAlignment = .center; note.textColor = .secondaryLabel; note.isHidden = true
        view.addSubview(note)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        view.addSubview(spinner)

        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: g.topAnchor), bar.leadingAnchor.constraint(equalTo: view.leadingAnchor), bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            thumbsScroll.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 10), thumbsScroll.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 14), thumbsScroll.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -14), thumbsScroll.heightAnchor.constraint(equalToConstant: 76),
            thumbs.topAnchor.constraint(equalTo: thumbsScroll.topAnchor), thumbs.bottomAnchor.constraint(equalTo: thumbsScroll.bottomAnchor), thumbs.leadingAnchor.constraint(equalTo: thumbsScroll.leadingAnchor), thumbs.trailingAnchor.constraint(equalTo: thumbsScroll.trailingAnchor), thumbs.heightAnchor.constraint(equalTo: thumbsScroll.heightAnchor),
            openBtn.topAnchor.constraint(equalTo: thumbsScroll.bottomAnchor, constant: 10), openBtn.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 14), openBtn.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -14), openBtn.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            caption.topAnchor.constraint(equalTo: openBtn.bottomAnchor, constant: 10), caption.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 14), caption.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -14), caption.heightAnchor.constraint(equalToConstant: 40),
            proofRow.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: 8), proofRow.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 14), proofRow.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -14),
            toLabel.topAnchor.constraint(equalTo: proofRow.bottomAnchor, constant: 10), toLabel.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 14), toLabel.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -14),
            table.topAnchor.constraint(equalTo: toLabel.bottomAnchor, constant: 6), table.leadingAnchor.constraint(equalTo: g.leadingAnchor), table.trailingAnchor.constraint(equalTo: g.trailingAnchor), table.bottomAnchor.constraint(equalTo: g.bottomAnchor),
            note.centerYAnchor.constraint(equalTo: g.centerYAnchor), note.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 24), note.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -24),
            spinner.centerXAnchor.constraint(equalTo: g.centerXAnchor), spinner.centerYAnchor.constraint(equalTo: g.centerYAnchor),
        ])
        refreshProof(); refreshSend()
    }

    @objc private func endEdit() { caption.resignFirstResponder() }

    private func refreshProof() {
        let m = tasks.first(where: { $0.id == selected })?.money ?? false
        proofRow.isHidden = !(m && !picked.isEmpty)
    }
    private func refreshSend() {
        navItem.rightBarButtonItem?.isEnabled = ctx != nil && !loading && !sending && selected != nil && (!picked.isEmpty || !(caption.text ?? "").isEmpty)
        openBtn.isEnabled = !loading && !sending && !picked.isEmpty
    }

    // MARK: attachments
    private func loadAttachments() {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        let group = DispatchGroup()
        let box = PickBox()
        spinner.startAnimating()
        for (i, p) in providers.prefix(10).enumerated() {
            if p.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                group.enter()
                p.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, _ in
                    var data: Data? = nil; var name = "file.pdf"
                    if let u = item as? URL { data = try? Data(contentsOf: u); name = u.lastPathComponent }
                    else if let d = item as? Data { data = d }
                    if let d = data, d.count <= 12 * 1024 * 1024 { box.lock.lock(); box.items[i] = Picked(name: name, mime: "application/pdf", data: d, thumb: nil, preview: nil); box.lock.unlock() }
                    group.leave()
                }
            } else if p.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                group.enter()
                p.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                    var img: UIImage? = nil; var name = "photo.jpg"
                    if let u = item as? URL { if let d = try? Data(contentsOf: u) { img = UIImage(data: d) }; name = u.deletingPathExtension().lastPathComponent + ".jpg" }
                    else if let d = item as? Data { img = UIImage(data: d) }
                    else if let im = item as? UIImage { img = im }
                    if let im = img, let full = ShareViewController.jpeg(im, maxSide: 2048, q: 0.8) {
                        let small = ShareViewController.jpeg(im, maxSide: 480, q: 0.6)
                        let thumb = small.map { "data:image/jpeg;base64," + $0.base64EncodedString() }
                        box.lock.lock(); box.items[i] = Picked(name: name, mime: "image/jpeg", data: full, thumb: thumb, preview: small.flatMap { UIImage(data: $0) }); box.lock.unlock()
                    }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.picked = box.items.keys.sorted().compactMap { box.items[$0] }
            self.loading = false
            self.spinner.stopAnimating()
            for p in self.picked { self.thumbs.addArrangedSubview(self.thumbView(p)) }
            if self.picked.isEmpty { self.note.text = self.t("مقدرتش أقرا الملف ده — ابعت صورة أو PDF.", "Could not read this — share a photo or a PDF."); self.note.isHidden = false }
            else if self.ctx == nil { /* keep «sign in once» */ }
            else if self.tasks.isEmpty { self.note.text = self.t("مفيش مهام مفتوحة — افتح المهمة في Ninety الأول.", "No open tasks — open the task in Ninety first."); self.note.isHidden = false }
            self.refreshProof(); self.refreshSend()
        }
    }

    private func thumbView(_ p: Picked) -> UIView {
        let v = UIImageView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.contentMode = .scaleAspectFill; v.clipsToBounds = true; v.layer.cornerRadius = 10
        v.backgroundColor = .secondarySystemBackground
        if let im = p.preview { v.image = im } else { v.image = UIImage(systemName: "doc.richtext"); v.contentMode = .center; v.tintColor = .secondaryLabel }
        NSLayoutConstraint.activate([v.widthAnchor.constraint(equalToConstant: 76), v.heightAnchor.constraint(equalToConstant: 76)])
        return v
    }

    private static func jpeg(_ img: UIImage, maxSide: CGFloat, q: CGFloat) -> Data? {
        let w = img.size.width, h = img.size.height
        guard w > 0, h > 0 else { return nil }
        let s = min(1, maxSide / max(w, h))
        let size = CGSize(width: floor(w * s), height: floor(h * s))
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        let out = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        return out.jpegData(compressionQuality: q)
    }

    // MARK: table
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { tasks.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = UITableViewCell(style: .subtitle, reuseIdentifier: "c")
        let tk = tasks[indexPath.row]
        c.textLabel?.text = tk.title
        c.textLabel?.numberOfLines = 2
        var sub = tk.sub ?? ""
        if tk.money == true { sub = (sub.isEmpty ? "" : sub + " · ") + t("مستنية تحويل", "Waits for a transfer") }
        c.detailTextLabel?.text = sub
        c.detailTextLabel?.textColor = .secondaryLabel
        c.textLabel?.textAlignment = ar ? .right : .left
        c.detailTextLabel?.textAlignment = ar ? .right : .left
        c.accessoryType = tk.id == selected ? .checkmark : .none
        return c
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selected = tasks[indexPath.row].id
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadData(); refreshProof(); refreshSend()
    }

    // MARK: actions
    @objc private func cancel() { extensionContext?.completeRequest(returningItems: nil, completionHandler: nil) }

    // MARK: v9.71 «افتح في Ninety»
    private func stashInbox() -> Int {   // 0 = ok · 1 = too large · 2 = keychain error
        let files = picked
        if files.contains(where: { $0.data.count > kInboxMaxFile }) || files.reduce(0, { $0 + $1.data.count }) > kInboxMaxTotal { return 1 }
        clearInbox()
        var list: [[String: Any]] = []
        for (i, p) in files.prefix(10).enumerated() {
            guard kcPut("inbox.\(i)", p.data) else { clearInbox(); return 2 }
            list.append(["name": p.name, "mime": p.mime, "key": "inbox.\(i)"])
        }
        let man: [String: Any] = ["v": 1, "at": Date().timeIntervalSince1970 * 1000, "text": caption.text ?? "", "files": list]
        guard let d = try? JSONSerialization.data(withJSONObject: man), kcPut("inbox", d) else { clearInbox(); return 2 }
        return 0
    }

    // Opening the containing app from a share extension: UIApplication.open is not available to extension code, so it is
    // looked up at run time on the responder chain (iOS 18 dropped the old one-argument openURL:, the three-argument one
    // still works). NSExtensionContext.open is the fallback (iOS officially honours it for widgets only).
    private func openContainingApp(_ url: URL, done: @escaping (Bool) -> Void) {
        let sel = NSSelectorFromString("openURL:options:completionHandler:")
        var r: UIResponder? = self
        while let cur = r {
            if cur is UIApplication, cur.responds(to: sel), let imp = cur.method(for: sel) {   // not UIWindowScene (same selector, other options type)
                typealias OpenFn = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, (@convention(block) (Bool) -> Void)?) -> Void
                let fn = unsafeBitCast(imp, to: OpenFn.self)
                let cb: @convention(block) (Bool) -> Void = { ok in DispatchQueue.main.async { done(ok) } }
                fn(cur, sel, url as NSURL, NSDictionary(), cb)
                return
            }
            r = cur.next
        }
        if let ec = extensionContext { ec.open(url) { ok in DispatchQueue.main.async { done(ok) } } } else { done(false) }
    }

    @objc private func openInApp() {
        guard !picked.isEmpty, !sending, let url = URL(string: kAppURL) else { return }
        sending = true; refreshSend(); spinner.startAnimating(); caption.resignFirstResponder()
        let res = stashInbox()
        if res != 0 {
            sending = false; spinner.stopAnimating(); refreshSend()
            let msg = res == 1 ? t("الملف كبير أوي يتفتح في Ninety — ابعته لمهمة من تحت.", "The file is too large to open in Ninety — send it to a task below.")
                               : t("مقدرتش أحضّر الصورة — جرّب تاني أو ابعتها لمهمة.", "Could not prepare the picture — try again or send it to a task.")
            let a = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: t("تمام", "OK"), style: .default))
            present(a, animated: true)
            return
        }
        var finished = false
        let finish: (Bool) -> Void = { [weak self] opened in
            guard let self = self, !finished else { return }
            finished = true
            self.spinner.stopAnimating()
            if opened {
                self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                return
            }
            // iOS did not open the app: the files are kept — Ninety shows them the next time it is opened
            self.note.text = self.t("اتحفظت ✓ — افتح أبلكيشن Ninety وهتلاقيها قدامك على طول.", "Saved ✓ — open the Ninety app and it is right there.")
            self.note.isHidden = false; self.table.isHidden = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil) }
        }
        openContainingApp(url, done: finish)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { finish(false) }
    }

    @objc private func send() {
        guard let c = ctx, let taskId = selected, let url = URL(string: c.endpoint), !sending else { return }
        sending = true; refreshSend(); spinner.startAnimating(); caption.resignFirstResponder()
        let files: [[String: Any]] = picked.map { p in
            var o: [String: Any] = ["name": p.name, "mime": p.mime, "data": p.data.base64EncodedString()]
            if let th = p.thumb { o["thumb"] = th }
            return o
        }
        let money = tasks.first(where: { $0.id == taskId })?.money ?? false
        let body: [String: Any] = ["action": "send", "token": c.token, "taskId": taskId, "text": caption.text ?? "", "proof": money && proofSwitch.isOn && !proofRow.isHidden, "files": files]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 90
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { [weak self] _, resp, err in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.sending = false; self.spinner.stopAnimating()
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200 {
                    self.note.text = self.t("اتبعتت ✓", "Sent ✓"); self.note.isHidden = false; self.table.isHidden = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil) }
                    return
                }
                var msg = self.t("مقدرتش أبعتها — جرّب تاني.", "Could not send it — try again.")
                if code == 401 { msg = self.t("افتح Ninety وسجّل دخولك تاني، وبعدين جرّب.", "Open Ninety and sign in again, then try.") }
                else if code == 403 { msg = self.t("مش من أطراف المهمة دي.", "You are not part of this task.") }
                else if code == 413 { msg = self.t("الملف كبير أوي.", "The file is too large.") }
                else if err != nil { msg = self.t("مفيش إنترنت — جرّب تاني.", "No internet — try again.") }
                let a = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
                a.addAction(UIAlertAction(title: self.t("تمام", "OK"), style: .default))
                self.present(a, animated: true)
                self.refreshSend()
            }
        }.resume()
    }
}
