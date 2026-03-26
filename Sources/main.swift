import AppKit
import ApplicationServices

/// Převod pozice myši (Cocoa, globální souřadnice, počátek vlevo dole) na souřadnice pro Accessibility API
/// (globální prostor, počátek vlevo nahoře u hlavního displeje).
private func mouseLocationForAccessibility() -> CGPoint {
    let p = NSEvent.mouseLocation
    guard let screen = NSScreen.screens.first(where: { NSMouseInRect(p, $0.frame, false) }) ?? NSScreen.main
    else {
        return CGPoint(x: p.x, y: p.y)
    }
    let yFromTop = screen.frame.maxY - p.y
    return CGPoint(x: p.x, y: yFromTop)
}

private func role(of element: AXUIElement) -> String? {
    var roleRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success else {
        return nil
    }
    return roleRef as? String
}

private func parent(of element: AXUIElement) -> AXUIElement? {
    var parentRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentRef) == .success,
          let p = parentRef
    else { return nil }
    return (p as! AXUIElement)
}

/// Najde nejbližší předka s rolí AXWindow.
private func containingWindow(of element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    if depth > 40 { return nil }
    if role(of: element) == "AXWindow" {
        return element
    }
    guard let p = parent(of: element) else { return nil }
    return containingWindow(of: p, depth: depth + 1)
}

private func pid(of element: AXUIElement) -> pid_t? {
    var p: pid_t = 0
    guard AXUIElementGetPid(element, &p) == .success else { return nil }
    return p
}

/// Přinese okno dopředu; celou aplikaci aktivuje jen když ještě není v popředí (méně konfliktů se systémem).
private func activate(window: AXUIElement, pid: pid_t) {
    _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    guard let app = NSRunningApplication(processIdentifier: pid) else { return }
    if NSWorkspace.shared.frontmostApplication?.processIdentifier != pid {
        app.activate(options: [.activateIgnoringOtherApps])
    }
}

private final class FocusFollowController: NSObject {
    /// Aplikace, u kterých nechceme focus-follow (např. Finder při zavírání oken, systémové UI).
    private let excludedBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.loginwindow",
    ]

    /// Kurzor musí zůstat nad stejným oknem tuto dobu, než přepneme focus (rychlé přejíždění okny nic nedělá).
    private let dwellTime: TimeInterval = 0.28

    /// Drahé AX dotazy jen když se myš opravdu pohnula (jinak klid = žádné volání WindowServeru).
    private let mouseMoveThreshold: CGFloat = 2.5

    private let systemWide = AXUIElementCreateSystemWide()
    private var lastWindow: AXUIElement?
    private var pendingWindow: AXUIElement?
    private var pendingPid: pid_t?
    private var pendingSince: TimeInterval?
    private var lastMouseScreen = CGPoint.zero
    private var hasLastMouse = false
    private let ourPid = ProcessInfo.processInfo.processIdentifier

    /// Okamžité vypnutí bez ukončení aplikace (např. když systém zrovna nestíhá).
    private(set) var isPaused = false

    @objc func togglePause(_ sender: NSMenuItem) {
        isPaused.toggle()
        sender.state = isPaused ? .on : .off
        sender.title = isPaused ? "Zapnout focus follow" : "Pozastavit focus follow"
    }

    private func isExcluded(pid: pid_t) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return false }
        if let bid = app.bundleIdentifier, excludedBundleIDs.contains(bid) {
            return true
        }
        // Finder musí být vždy vynechán — i když bundleIdentifier chybí (výjimečně při přechodu procesu).
        if app.bundleURL?.lastPathComponent == "Finder.app" {
            return true
        }
        if app.localizedName == "Finder" {
            return true
        }
        return false
    }

    private func mouseMovedMeaningfully() -> Bool {
        let p = NSEvent.mouseLocation
        guard hasLastMouse else {
            lastMouseScreen = p
            hasLastMouse = true
            return true
        }
        let dx = p.x - lastMouseScreen.x
        let dy = p.y - lastMouseScreen.y
        let moved = (dx * dx + dy * dy) >= mouseMoveThreshold * mouseMoveThreshold
        lastMouseScreen = p
        return moved
    }

    /// Dokončení dwell bez opakovaného AX — při stojící myši nezatěžujeme systém.
    private func tryCompletePendingDwell(now: TimeInterval) {
        guard let w = pendingWindow,
              let p = pendingPid,
              let since = pendingSince,
              now - since >= dwellTime
        else { return }
        guard p != ourPid, !isExcluded(pid: p) else {
            pendingWindow = nil
            pendingPid = nil
            pendingSince = nil
            return
        }
        lastWindow = w
        pendingWindow = nil
        pendingPid = nil
        pendingSince = nil
        activate(window: w, pid: p)
    }

    func tick() {
        guard !isPaused else { return }
        let now = ProcessInfo.processInfo.systemUptime

        if !mouseMovedMeaningfully() {
            tryCompletePendingDwell(now: now)
            return
        }

        let pt = mouseLocationForAccessibility()
        var el: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(systemWide, Float(pt.x), Float(pt.y), &el)
        guard err == .success, let element = el else { return }

        guard let window = containingWindow(of: element),
              let targetPid = pid(of: window), targetPid != ourPid
        else { return }

        if isExcluded(pid: targetPid) {
            lastWindow = nil
            pendingWindow = nil
            pendingPid = nil
            pendingSince = nil
            return
        }

        if let lw = lastWindow, CFEqual(lw as CFTypeRef, window as CFTypeRef) {
            pendingWindow = nil
            pendingPid = nil
            pendingSince = nil
            return
        }

        if let pw = pendingWindow, CFEqual(pw as CFTypeRef, window as CFTypeRef) {
            guard let since = pendingSince, now - since >= dwellTime else { return }
            lastWindow = window
            pendingWindow = nil
            pendingPid = nil
            pendingSince = nil
            activate(window: window, pid: targetPid)
            return
        }

        pendingWindow = window
        pendingPid = targetPid
        pendingSince = now
    }
}

autoreleasepool {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    let controller = FocusFollowController()

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem.button {
        button.image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "Focus Follow Mouse")
    }

    let menu = NSMenu()
    let pauseItem = NSMenuItem(
        title: "Pozastavit focus follow",
        action: #selector(FocusFollowController.togglePause(_:)),
        keyEquivalent: ""
    )
    pauseItem.target = controller
    menu.addItem(pauseItem)
    menu.addItem(.separator())
    let quitItem = NSMenuItem(
        title: "Ukončit Focus Follow Mouse",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    )
    quitItem.target = NSApplication.shared
    menu.addItem(quitItem)
    statusItem.menu = menu

    // 8× za sekundu stačí pro dwell; 60 Hz + AX by zbytečně dusilo WindowServer.
    Timer.scheduledTimer(withTimeInterval: 0.125, repeats: true) { _ in
        controller.tick()
    }

    app.run()
}
