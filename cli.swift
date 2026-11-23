// Command line interface for Grids: query exact guide coordinates headless, or control the running overlay via socket.
// Run as grids-cli (symlink to Grids.app/Contents/MacOS/Grids) or as Grids with subcommands:
//
//   grids-cli lines [WxH] [--mode all|halves|golden|thirds|fine] [--json]
//   grids-cli show [all|halves|golden|thirds|fine]
//   grids-cli hide
//   grids-cli toggle
//   grids-cli status [--json]
//   grids-cli --version | --help

import AppKit
import Security

private let gridsCliName = "grids-cli"

private let gridsAppBundle: Bundle = {
    // executableURL, not argv[0]: run by name from PATH (the Homebrew symlink) argv[0] is the bare name, and the bundle
    // three levels above it is the current folder's, not the app's (measured 2026-11-23: version 0, settings unread).
    let real = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])).resolvingSymlinksInPath()
    let appURL = real.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return Bundle(url: appURL) ?? .main
}()

var gridsSocketPath: String {
    var buf = [CChar](repeating: 0, count: Int(PATH_MAX))
    let dir = confstr(_CS_DARWIN_USER_TEMP_DIR, &buf, buf.count) > 0 ? String(cString: buf) : NSTemporaryDirectory()
    let base = dir.hasSuffix("/") ? dir : dir + "/"
    return base + (gridsAppBundle.bundleIdentifier ?? "com.geragaraza.grids") + ".sock"
}

private func gridsUnixAddress(_ path: String) -> sockaddr_un {
    var a = sockaddr_un()
    a.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8.prefix(MemoryLayout.size(ofValue: a.sun_path) - 1))
    withUnsafeMutableBytes(of: &a.sun_path) { dst in for (i, b) in bytes.enumerated() { dst[i] = b } }
    return a
}

private func gridsAnswersForItself() -> Bool {
    typealias Lookup = @convention(c) (pid_t) -> pid_t
    let me = getpid()
    if let f = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid") {
        let r = unsafeBitCast(f, to: Lookup.self)(me)
        if r > 0 { return r == me }
    }
    return getppid() == 1
}

private func grFail(_ s: String) -> Never {
    FileHandle.standardError.write(Data((s + "\n").utf8))
    exit(1)
}

private func grJSON(_ obj: Any) -> Never {
    guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
          let text = String(data: data, encoding: .utf8) else { grFail("Could not encode JSON.") }
    print(text)
    exit(0)
}

func modeFromSlug(_ s: String) -> Mode? {
    switch s.lowercased() {
    case "all": return .all
    case "halves": return .halves
    case "golden": return .golden
    case "thirds": return .thirds
    case "fine", "8pt", "8-pt": return .fine
    default: return nil
    }
}

func modeSlug(_ m: Mode) -> String {
    switch m { case .all: "all"; case .halves: "halves"; case .golden: "golden"; case .thirds: "thirds"; case .fine: "fine" }
}

private func gridsReadSocket(_ fd: Int32, limit: Int, seconds: Double, toNewline: Bool) -> Data {
    let end = DispatchTime.now().uptimeNanoseconds + UInt64(seconds * 1e9)
    var data = Data(), buf = [UInt8](repeating: 0, count: 1024)
    while data.count < limit, !(toNewline && data.last == 10) {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < end else { break }
        let left = end - now
        var t = timeval(tv_sec: Int(left / 1_000_000_000), tv_usec: Int32(max(1, (left % 1_000_000_000) / 1000)))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &t, socklen_t(MemoryLayout<timeval>.size))
        let n = read(fd, &buf, min(buf.count, limit - data.count))
        if n <= 0 { break }
        data.append(contentsOf: buf[0..<n])
    }
    return data
}

private func gridsSend(_ command: String) -> String? {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return nil }
    defer { close(fd) }
    var a = gridsUnixAddress(gridsSocketPath)
    let ok = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } } == 0
    guard ok else { return nil }
    _ = (command + "\n").withCString { write(fd, $0, strlen($0)) }
    let data = gridsReadSocket(fd, limit: 4096, seconds: 2, toNewline: false)
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}

@MainActor final class GridsControl {
    private var fd: Int32 = -1
    private var source: DispatchSourceRead?
    private var requirement: SecRequirement?
    private var inode: ino_t = 0
    var handle: (String) -> String = { _ in "Unknown command." }

    func start() {
        var me: SecCode?, staticMe: SecStaticCode?, req: SecRequirement?
        guard SecCodeCopySelf([], &me) == errSecSuccess, let me,
              SecCodeCopyStaticCode(me, [], &staticMe) == errSecSuccess, let staticMe,
              SecCodeCopyDesignatedRequirement(staticMe, [], &req) == errSecSuccess else { return }
        requirement = req
        let path = gridsSocketPath
        unlink(path)
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        var a = gridsUnixAddress(path)
        let bound = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } } == 0
        var st = stat()
        guard bound, chmod(path, 0o600) == 0, listen(fd, 4) == 0, lstat(path, &st) == 0 else {
            close(fd); fd = -1; unlink(path); return
        }
        inode = st.st_ino
        let s = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
        s.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.accept() } }
        s.resume()
        source = s
    }

    func stop() {
        source?.cancel(); source = nil
        var st = stat()
        if fd >= 0 {
            close(fd); fd = -1
            if lstat(gridsSocketPath, &st) == 0, st.st_ino == inode { unlink(gridsSocketPath) }
        }
    }

    private func accept() {
        let c = Darwin.accept(fd, nil, nil)
        guard c >= 0 else { return }
        defer { close(c) }
        var noSigPipe: Int32 = 1
        setsockopt(c, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        guard trusted(c) else { _ = "Refused: not \(gridsCliName).\n".withCString { write(c, $0, strlen($0)) }; return }
        let line = String(decoding: gridsReadSocket(c, limit: 1024, seconds: 1, toNewline: true), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let reply = handle(line)
        _ = (reply + "\n").withCString { write(c, $0, strlen($0)) }
    }

    private func trusted(_ c: Int32) -> Bool {
        var token = audit_token_t(), size = socklen_t(MemoryLayout<audit_token_t>.size)
        guard getsockopt(c, SOL_LOCAL, LOCAL_PEERTOKEN, &token, &size) == 0, let requirement else { return false }
        let data = withUnsafeBytes(of: &token) { Data($0) }
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributeAudit: data] as CFDictionary, [], &code) == errSecSuccess, let code else { return false }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
}

@MainActor func runGridsCLI(_ rawArgs: [String]) -> Bool {
    let exe = gridsAppBundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String ?? "Grids"
    let named = URL(fileURLWithPath: rawArgs[0]).lastPathComponent != exe
    let rest = Array(rawArgs.dropFirst())
    let usage = """
    Usage: \(gridsCliName) lines [WxH] [--mode all|halves|golden|thirds|fine] [--json]
           \(gridsCliName) show [all|halves|golden|thirds|fine]
           \(gridsCliName) hide
           \(gridsCliName) toggle
           \(gridsCliName) status [--json]
           \(gridsCliName) --version | --help
    """
    guard let cmd = rest.first else {
        if named { print(usage); exit(0) }
        return false
    }
    switch cmd {
    case "--help", "-h":
        print(usage); exit(0)
    case "--version", "-V":
        let v = gridsAppBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        print("Grids \(v)"); exit(0)
    case "lines", "show", "hide", "toggle", "status":
        break
    default:
        if named || cmd.hasPrefix("--") { grFail(usage) }
        return false
    }
    if gridsAnswersForItself() {
        grFail("\(gridsCliName) runs from a terminal or script, not launched as an app or launchd job.")
    }

    let tail = Array(rest.dropFirst())
    switch cmd {
    case "lines":
        var mode = Mode.all, json = false
        var sizeStr: String? = nil
        var i = 0
        while i < tail.count {
            switch tail[i] {
            case "--json": json = true; i += 1
            case "--mode":
                guard i + 1 < tail.count, let m = modeFromSlug(tail[i + 1]) else { grFail(usage) }
                mode = m; i += 2
            default:
                guard sizeStr == nil else { grFail(usage) }
                sizeStr = tail[i]; i += 1
            }
        }
        let scr = NSScreen.main ?? NSScreen.screens.first
        let scale = scr?.backingScaleFactor ?? 2.0
        var W = scr?.frame.width ?? 1728, H = scr?.frame.height ?? 1117
        if let s = sizeStr {
            let parts = s.lowercased().split(separator: "x")
            guard parts.count == 2, let w = Double(parts[0]), let h = Double(parts[1]), w > 0, h > 0 else { grFail(usage) }
            W = CGFloat(w); H = CGFloat(h)
        }
        func snap(_ v: CGFloat) -> Double { Double((v * scale).rounded() / scale) }
        let labels: [(String, [CGFloat])] = {
            var out: [(String, [CGFloat])] = [("halves", [0.5])]
            if mode == .all || mode == .halves { out.append(("quarters", [0.25, 0.75])) }
            if mode == .all || mode == .golden { out.append(("golden", [1 - phi, phi])) }
            if mode == .all || mode == .thirds { out.append(("thirds", [1.0 / 3, 2.0 / 3])) }
            return out
        }()
        if json {
            var gDict: [String: Any] = [:]
            for (name, fs) in labels {
                gDict[name] = ["x": fs.map { snap(W * $0) }, "y": fs.map { snap(H * $0) }]
            }
            grJSON([
                "width": Double(W), "height": Double(H), "scale": Double(scale),
                "mode": modeSlug(mode), "gridStep": (mode == .all || mode == .fine) ? 8 : 0,
                "guides": gDict,
            ])
        }
        print("canvas: \(Int(W))x\(Int(H)) pt (scale \(Int(scale))x) mode=\(modeSlug(mode))")
        for (name, fs) in labels {
            let xs = fs.map { String(format: "%g", snap(W * $0)) }.joined(separator: ", ")
            let ys = fs.map { String(format: "%g", snap(H * $0)) }.joined(separator: ", ")
            print("\(name)\tx=[\(xs)]\ty=[\(ys)]")
        }
        if mode == .all || mode == .fine { print("fine\tstep=8 pt (major=32 pt)") }
        exit(0)

    case "status":
        let json = tail == ["--json"]
        guard tail.isEmpty || json else { grFail(usage) }
        let version = gridsAppBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let reply = gridsSend("status")
        let running = reply != nil
        var visible = false, mode = "all"
        if let r = reply, r.hasPrefix("ok ") {
            let parts = r.dropFirst(3).split(separator: " ")
            if parts.count >= 2 { visible = parts[0] == "on"; mode = String(parts[1]) }
        }
        if json {
            grJSON(["version": version, "running": running, "visible": visible, "mode": mode])
        }
        print("version: \(version)")
        print("running: \(running ? "yes" : "no")")
        if running { print("visible: \(visible ? "yes" : "no")\nmode: \(mode)") }
        exit(0)

    case "show":
        guard tail.count <= 1 else { grFail(usage) }
        let m = tail.first ?? "all"
        guard modeFromSlug(m) != nil else { grFail(usage) }
        guard let r = gridsSend("show \(m)") else { grFail("Grids is not running.") }
        if r.hasPrefix("ok") { print(r == "ok" ? "Shown: \(m)" : String(r.dropFirst(3))); exit(0) }
        grFail(r)

    case "hide":
        guard tail.isEmpty else { grFail(usage) }
        guard let r = gridsSend("hide") else { grFail("Grids is not running.") }
        if r.hasPrefix("ok") { print("Hidden."); exit(0) }
        grFail(r)

    case "toggle":
        guard tail.isEmpty else { grFail(usage) }
        guard let r = gridsSend("toggle") else { grFail("Grids is not running.") }
        if r.hasPrefix("ok") { print(r.count > 3 ? String(r.dropFirst(3)) : "Toggled."); exit(0) }
        grFail(r)

    default:
        grFail(usage)
    }
}
