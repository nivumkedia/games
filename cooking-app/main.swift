import Cocoa

let games: [(name: String, url: String)] = [
    ("Fortress Fury",            "tower-defense.html"),
    ("Bullet Storm",             "strategy/other/top-shooter.html"),
    ("Cosmic Blitz",             "strategy/other/asteroids.html"),
    ("Gravity Rush",             "strategy/other/platform-hop.html"),
    ("Sky Vaulter",              "jump_game.html"),
    ("Platformer Adventure",     "platformer.html"),
    ("Shadow Dash",              "strategy/other/platformer.html"),
    ("Language Creator",         "strategy/other/language-creator.html"),
    ("Hackers",                  "strategy/other/hackers.html"),
    ("Mystic Forge",             "strategy/other/alchemy-lab.html"),
    ("Chef Rampage",             "strategy/other/kitchen-chaos.html"),
    ("Lemon Tycoon",             "strategy/other/lemonade-stand.html"),
    ("Sushi Surge",              "sushi-game.html"),
    ("Nitro Blaze",              "strategy/other/racing-game.html"),
    ("Auxotopia",                "strategy/other/auxotopia.html"),
    ("Slice Storm",              "strategy/other/fruit-ninja.html"),
    ("Number Showdown",          "math-jeopardy.html"),
    ("Sushi Sensei",             "sushi-math.html"),
    ("Brain Breaker",            "daily-puzzle.html"),
    ("Tag Frenzy",               "strategy/other/tag-game.html"),
    ("Puck Frenzy",              "strategy/other/air-hockey.html"),
    ("Net Smash",                "strategy/other/net-smash.html"),
    ("Turbo Clash",              "car_battle_game.html"),
    ("Sky Dash",                 "strategy/other/sky-dash.html"),
    ("Monster Escape",           "strategy/other/monster-escape.html"),
    ("Angry Pigs",               "angry-pigs.html"),
    ("Pulse Runner",             "strategy/other/pulse-runner.html"),
    ("Mongolia",                 "strategy/other/mongolia.html"),
    ("Grove Guard",              "strategy/other/tower-defense.html"),
    ("CodeLab",                  "strategy/other/codelab.html"),
]

let lastGameFile = NSHomeDirectory() + "/.cooking_app_last_game"

func loadLastGame() -> String {
    return (try? String(contentsOfFile: lastGameFile, encoding: .utf8)) ?? ""
}

func saveLastGame(_ name: String) {
    try? name.write(toFile: lastGameFile, atomically: true, encoding: .utf8)
}

func findGame(_ input: String) -> (name: String, url: String)? {
    let q = input.lowercased().trimmingCharacters(in: .whitespaces)
    guard !q.isEmpty else { return nil }
    if let m = games.first(where: { $0.name.lowercased() == q }) { return m }
    if let m = games.first(where: { $0.name.lowercased().contains(q) }) { return m }
    let words = q.split(separator: " ").map(String.init)
    return games.first(where: { g in words.allSatisfy { g.name.lowercased().contains($0) } })
}

@discardableResult
func shell(_ path: String, _ args: String...) -> Process {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    try? p.run()
    return p
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var testBtn: NSButton!
    var codexClaudeBtn: NSButton!
    var inCodexMode = false
    var serverProcess: Process?

    func applicationDidFinishLaunching(_ notification: Notification) {
        startServer()
        buildPanel()
        launchClaude()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        serverProcess?.terminate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let target = inCodexMode ? "Codex" : "iTerm2"
        let script = "tell application \"\(target)\" to activate"
        shell("/usr/bin/osascript", "-e", script)
        return false
    }

    func startServer() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        p.arguments = ["-m", "http.server", "3000"]
        p.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/git/nivsgames")
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        serverProcess = p
    }

    func launchClaude() {
        let script = """
        tell application "iTerm2"
            activate
            set newWindow to (create window with default profile)
            tell current session of newWindow
                write text "cd ~/git/nivsgames && claude --dangerously-skip-permissions"
            end tell
        end tell
        """
        shell("/usr/bin/osascript", "-e", script)
    }

    func buildPanel() {
        let w: CGFloat = 200, h: CGFloat = 60
        let screen = NSScreen.main!
        let x = screen.visibleFrame.maxX - w - 16
        let y = screen.visibleFrame.maxY - h - 16

        panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: w, height: h),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        codexClaudeBtn = NSButton(title: "Codex", target: self, action: #selector(codexClaudeTapped))
        codexClaudeBtn.bezelStyle = .rounded

        let lastName = loadLastGame()
        testBtn = NSButton(
            title: lastName.isEmpty ? "Test…" : "▶ \(lastName)",
            target: self,
            action: #selector(testTapped)
        )
        testBtn.bezelStyle = .rounded

        let sv = NSStackView(views: [codexClaudeBtn, testBtn])
        sv.orientation = .horizontal
        sv.spacing = 8
        sv.distribution = .fillEqually
        sv.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        sv.frame = NSRect(x: 0, y: 0, width: w, height: h)
        sv.autoresizingMask = [.width, .height]

        panel.contentView = sv
        panel.makeKeyAndOrderFront(nil)
    }

    @objc func appActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app != NSRunningApplication.current else { return }
        let name = app.localizedName ?? ""
        let isWorkApp = name == "iTerm2" || name == "Codex"
        if isWorkApp {
            panel.orderFront(nil)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
                if front != "iTerm2" && front != "Codex" {
                    self.panel.orderOut(nil)
                }
            }
        }
    }

    @objc func appTerminated(_ notification: Notification) {
        guard let terminated = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let name = terminated.localizedName,
              name == "iTerm2" || name == "Codex" else { return }
        let running = NSWorkspace.shared.runningApplications
        let iTermRunning = running.contains { $0.localizedName == "iTerm2" }
        let codexRunning = running.contains { $0.localizedName == "Codex" }
        if !iTermRunning && !codexRunning {
            NSApp.terminate(nil)
        }
    }

    @objc func codexClaudeTapped() {
        if !inCodexMode {
            shell("/usr/bin/open", "-a", "Codex")
            codexClaudeBtn.title = "Claude"
            inCodexMode = true
        } else {
            let iTermRunning = NSWorkspace.shared.runningApplications
                .contains(where: { $0.localizedName == "iTerm2" })
            if iTermRunning {
                shell("/usr/bin/osascript", "-e", "tell application \"iTerm2\" to activate")
            } else {
                launchClaude()
            }
            codexClaudeBtn.title = "Codex"
            inCodexMode = false
        }
    }

    @objc func testTapped() {
        let lastName = loadLastGame()

        let alert = NSAlert()
        alert.messageText = "Open Game"
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = lastName
        field.placeholderString = "e.g. Fortress Fury"
        alert.accessoryView = field
        field.selectText(nil)

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let typed = field.stringValue.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return }

        if let game = findGame(typed) {
            saveLastGame(typed)
            testBtn.title = "▶ \(typed)"
            shell("/usr/bin/open", "-a", "Google Chrome", "http://localhost:3000/\(game.url)")
        } else {
            let err = NSAlert()
            err.messageText = "Game not found: \"\(typed)\""
            err.informativeText = "Try: \(games.prefix(6).map { $0.name }.joined(separator: ", "))…"
            err.runModal()
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
