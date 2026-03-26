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

private func activate(window: AXUIElement, pid: pid_t) {
    _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    if let app = NSRunningApplication(processIdentifier: pid) {
        app.activate(options: [.activateIgnoringOtherApps])
    }
}

private final class FocusFollowController: NSObject {
    private let systemWide = AXUIElementCreateSystemWide()
    private var lastWindow: AXUIElement?
    private var lastCheck: TimeInterval = 0
    private let minInterval: TimeInterval = 0.08
    private let ourPid = ProcessInfo.processInfo.processIdentifier

    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastCheck >= minInterval else { return }
        lastCheck = now

        let pt = mouseLocationForAccessibility()
        var el: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(systemWide, Float(pt.x), Float(pt.y), &el)
        guard err == .success, let element = el else { return }

        guard let window = containingWindow(of: element),
              let targetPid = pid(of: window), targetPid != ourPid
        else { return }

        if let lw = lastWindow, CFEqual(lw as CFTypeRef, window as CFTypeRef) {
            return
        }

        lastWindow = window
        activate(window: window, pid: targetPid)
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
    let quitItem = NSMenuItem(
        title: "Ukončit Focus Follow Mouse",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    )
    quitItem.target = NSApplication.shared
    menu.addItem(quitItem)
    statusItem.menu = menu

    Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
        controller.tick()
    }

    app.run()
}
