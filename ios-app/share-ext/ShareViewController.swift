// Ninety — iPhone share extension (v7.57): «Share» → Ninety → pick the task → the photo / PDF lands in the task chat.
// The list of tasks, the server address and a device token come from the Ninety app (shared keychain item written by the
// NinetyShare plugin every time a task is opened and when the app goes to the background). Nothing secret is in this file.
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
            note.text = t("افتح أبلكيشن Ninety وسجّل دخولك مرة، وبعدين جرّب المشاركة تاني.", "Open the Ninety app and sign in once, then share again.")
            note.isHidden = false; table.isHidden = true; caption.isHidden = true; toLabel.isHidden = true
            loading = false; refreshSend(); return
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
            caption.topAnchor.constraint(equalTo: thumbsScroll.bottomAnchor, constant: 10), caption.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 14), caption.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -14), caption.heightAnchor.constraint(equalToConstant: 40),
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
            if self.tasks.isEmpty { self.note.text = self.t("مفيش مهام مفتوحة — افتح المهمة في Ninety الأول.", "No open tasks — open the task in Ninety first."); self.note.isHidden = false }
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
