import SwiftUI
import AppKit
import HottripUI

/// Рендерит все экраны из SnapshotCatalog в PNG.
/// Использование: HottripSnapshots [outputDir] [--scale N] [--only name-substring] [--no-chrome] [--no-full] [--app-icon path.png]
@main
struct HottripSnapshots {
    @MainActor
    static func main() {
        var args = Array(CommandLine.arguments.dropFirst())
        func flag(_ f: String) -> Bool { if let i = args.firstIndex(of: f) { args.remove(at: i); return true }; return false }
        func option(_ f: String) -> String? {
            guard let i = args.firstIndex(of: f), i + 1 < args.count else { return nil }
            let v = args[i + 1]; args.removeSubrange(i...(i + 1)); return v
        }
        let scale = option("--scale").flatMap(Double.init) ?? 3
        let only = option("--only")
        let noChrome = flag("--no-chrome")
        let noFull = flag("--no-full")
        let appIcon = option("--app-icon")
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        let outDir = URL(fileURLWithPath: args.first ?? FileManager.default.currentDirectoryPath + "/snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        var count = 0
        for entry in SnapshotCatalog.entries where only.map({ entry.name.contains($0) }) ?? true {
            // 1) Экран телефона 393×852 (+ рамка устройства).
            let screen = entry.view
                .frame(width: HTDevice.size.width, height: HTDevice.size.height)
                .clipped()
                .htSnapshotEnvironment()
            let framed: AnyView = noChrome
                ? AnyView(screen)
                : AnyView(HTDeviceChrome(darkStatusBar: entry.darkStatusBar) { screen }
                            .padding(24).background(HTColor.Chrome.backdrop))
            count += write(framed, to: outDir.appendingPathComponent("\(entry.name).png"), scale: scale,
                           proposed: ProposedViewSize(width: nil, height: nil)) ? 1 : 0

            // 2) «Full»: весь контент по высоте (как если бы экран проскроллили целиком).
            if entry.renderFull && !noFull {
                let full = entry.view
                    .frame(width: HTDevice.size.width)
                    .htSnapshotEnvironment(fullHeight: true)
                let url = outDir.appendingPathComponent("\(entry.name)-full.png")
                count += write(full, to: url, scale: min(scale, 2),
                               proposed: ProposedViewSize(width: HTDevice.size.width, height: nil),
                               minHeight: HTDevice.size.height + 1) ? 1 : 0
            }
        }
        if let appIcon {
            let url = URL(fileURLWithPath: appIcon)
            count += write(HTAppIcon().environment(\.colorScheme, .light), to: url, scale: 1,
                           proposed: ProposedViewSize(width: 1024, height: 1024), opaque: true) ? 1 : 0
        }
        print("Готово: \(count) PNG → \(outDir.path)")
    }

    /// Возвращает true, если файл записан.
    @MainActor
    static func write<V: View>(_ view: V, to url: URL, scale: Double, proposed: ProposedViewSize,
                              minHeight: CGFloat = 0, opaque: Bool = false) -> Bool {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = opaque
        renderer.proposedSize = proposed
        guard let cg = renderer.cgImage else {
            FileHandle.standardError.write("Ошибка: не удалось отрендерить \(url.lastPathComponent)\n".data(using: .utf8)!)
            return false
        }
        if CGFloat(cg.height) / scale < minHeight {
            try? FileManager.default.removeItem(at: url) // контент помещается в экран — full не нужен
            return false
        }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: url)
            print("\(url.lastPathComponent)  \(cg.width)×\(cg.height)")
            return true
        } catch {
            FileHandle.standardError.write("Ошибка: \(url.lastPathComponent): \(error)\n".data(using: .utf8)!)
            return false
        }
    }
}
