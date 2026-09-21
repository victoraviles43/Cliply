import AppKit
import Carbon
import CryptoKit
import SwiftUI

@main
struct ClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            ClipboardMenu(controller: appDelegate.controller)
        } label: {
            Image(systemName: "clipboard")
                .accessibilityLabel("Historial del portapapeles")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = ClipboardController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.start()
        if ProcessInfo.processInfo.arguments.contains("--show") {
            controller.showPanel()
        }
    }
}

@MainActor
final class ClipboardController: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var hotKeyError: String?

    private let pasteboard = NSPasteboard.general
    private var previousChangeCount = 0
    private var timer: Timer?
    private var hotKey: GlobalHotKey?
    private var panel: ClipboardPanel?
    private weak var previousApp: NSRunningApplication?

    func start() {
        previousChangeCount = pasteboard.changeCount
        captureCurrentPasteboard()
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPasteboard() }
        }
        hotKey = GlobalHotKey { [weak self] in self?.togglePanel() }
        if hotKey == nil {
            hotKeyError = "Control + Espacio está ocupado. Cámbialo en Ajustes del Sistema > Teclado > Atajos de teclado."
        }
    }

    private func checkPasteboard() {
        guard pasteboard.changeCount != previousChangeCount else { return }
        previousChangeCount = pasteboard.changeCount
        captureCurrentPasteboard()
    }

    private func captureCurrentPasteboard() {
        guard let item = ClipboardItem.read(from: pasteboard) else { return }
        let existing = items.first { $0.fingerprint == item.fingerprint }
        items.removeAll { $0.fingerprint == item.fingerprint }
        if let existing, existing.isPinned {
            let pinnedIndex = min(items.filter(\.isPinned).count, existing.pinPosition ?? 0)
            items.insert(existing, at: pinnedIndex)
        } else {
            items.insert(item, at: items.filter(\.isPinned).count)
        }
        trimRecentItems()
    }

    private func trimRecentItems() {
        let pinned = items.filter(\.isPinned)
        items = pinned + Array(items.filter { !$0.isPinned }.prefix(10))
        for index in items.indices where items[index].isPinned {
            items[index].pinPosition = index
        }
    }

    func clearHistory() { items.removeAll { !$0.isPinned } }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        trimRecentItems()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = items.remove(at: index)
        updated.isPinned.toggle()
        updated.pinPosition = nil
        items.insert(updated, at: updated.isPinned ? 0 : items.filter(\.isPinned).count)
        trimRecentItems()
    }

    func select(_ item: ClipboardItem) {
        item.write(to: pasteboard)
        previousChangeCount = pasteboard.changeCount
        if !item.isPinned {
            items.removeAll { $0.fingerprint == item.fingerprint }
            items.insert(item, at: items.filter(\.isPinned).count)
            trimRecentItems()
        }
        hidePanel()
    }

    func selectEmoji(_ emoji: String) {
        pasteboard.clearContents()
        pasteboard.setString(emoji, forType: .string)
        previousChangeCount = pasteboard.changeCount
        captureCurrentPasteboard()
        hidePanel()
    }

    func togglePanel() {
        if panel?.isVisible == true { hidePanel() } else { showPanel() }
    }

    func showPanel() {
        checkPasteboard()
        previousApp = NSWorkspace.shared.frontmostApplication
        if panel == nil {
            let panel = ClipboardPanel(
                contentRect: NSRect(x: 0, y: 0, width: 430, height: 560),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = "Portapapeles"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.standardWindowButton(.closeButton)?.isHidden = true
            panel.isMovableByWindowBackground = true
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.onDismiss = { [weak self] in self?.hidePanel() }
            self.panel = panel
        }
        panel?.contentView = NSHostingView(rootView: ClipboardPanelView(controller: self))
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            let frame = screen.visibleFrame
            panel?.setFrameOrigin(NSPoint(x: frame.midX - 215, y: frame.midY - 280))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func hidePanel() {
        panel?.orderOut(nil)
        if let previousApp, previousApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp.activate()
        }
        previousApp = nil
    }
}

final class ClipboardPanel: NSPanel {
    var onDismiss: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onDismiss?() }
    override func close() { onDismiss?() }
}

struct ClipboardItem: Identifiable {
    enum Content {
        case text(String)
        case image(Data)
        case files([URL])
    }

    let id = UUID()
    let content: Content
    let fingerprint: String
    var isPinned = false
    var pinPosition: Int?

    static func read(from pasteboard: NSPasteboard) -> ClipboardItem? {
        if let files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !files.isEmpty {
            return ClipboardItem(content: .files(files), fingerprint: "files:" + files.map(\.path).joined(separator: "\u{0}"))
        }
        if pasteboard.availableType(from: [.tiff, NSPasteboard.PasteboardType("public.png")]) != nil,
           let image = NSImage(pasteboard: pasteboard), let data = image.tiffRepresentation {
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            return ClipboardItem(content: .image(data), fingerprint: "image:" + digest)
        }
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return ClipboardItem(content: .text(text), fingerprint: "text:" + text)
        }
        return nil
    }

    func write(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        switch content {
        case .text(let text): pasteboard.setString(text, forType: .string)
        case .image(let data):
            if let image = NSImage(data: data) { pasteboard.writeObjects([image]) }
        case .files(let urls): pasteboard.writeObjects(urls as [NSURL])
        }
    }

    var title: String {
        switch content {
        case .text(let text): return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        case .image: return "Imagen"
        case .files(let urls): return urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) archivos"
        }
    }

    var subtitle: String {
        switch content {
        case .text(let text): return "Texto · \(text.count) caracteres"
        case .image: return "Imagen"
        case .files(let urls): return urls.map(\.lastPathComponent).joined(separator: ", ")
        }
    }

    var iconName: String {
        switch content {
        case .text: return "text.alignleft"
        case .image: return "photo"
        case .files: return "doc.on.doc"
        }
    }
}

@MainActor
private final class GlobalHotKey {
    private static var active: GlobalHotKey?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init?(_ action: @escaping () -> Void) {
        self.action = action
        let keyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1)
        let status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey), keyID,
                                            GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else { return nil }
        Self.active = self
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, _ in
            MainActor.assumeIsolated { GlobalHotKey.active?.action() }
            return noErr
        }
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &handlerRef)
        guard handlerStatus == noErr else {
            if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
            Self.active = nil
            return nil
        }
    }

    deinit {
        if let handlerRef { RemoveEventHandler(handlerRef) }
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
    }
}

private struct ClipboardMenu: View {
    @ObservedObject var controller: ClipboardController

    var body: some View {
        Button("Abrir historial  ⌃Espacio") { controller.showPanel() }
        if let error = controller.hotKeyError { Text(error) }
        Divider()
        Text("\(controller.items.filter { !$0.isPinned }.count)/10 recientes · \(controller.items.filter(\.isPinned).count) anclados")
        Button("Borrar recientes") { controller.clearHistory() }
            .disabled(!controller.items.contains { !$0.isPinned })
        Divider()
        Button("Salir") { NSApp.terminate(nil) }
    }
}

private enum PanelTab: String, CaseIterable {
    case clipboard = "Portapapeles"
    case emojis = "Emojis"

    var symbol: String {
        switch self {
        case .clipboard: "list.clipboard"
        case .emojis: "face.smiling"
        }
    }
}

private struct ClipboardPanelView: View {
    @ObservedObject var controller: ClipboardController
    @State private var tab: PanelTab = .clipboard
    @State private var query = ""
    @State private var emojiCategory = "Todos"
    @FocusState private var searchFocused: Bool
    private let accent = Color(red: 0.08, green: 0.43, blue: 0.83)

    private var filteredItems: [ClipboardItem] {
        guard !query.isEmpty else { return controller.items }
        return controller.items.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredEmojis: [EmojiEntry] {
        EmojiCatalog.all.filter {
            (emojiCategory == "Todos" || $0.category == emojiCategory) &&
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.symbol.contains(query))
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.black.opacity(0.25))
                .frame(width: 34, height: 4)
                .padding(.top, 9)

            HStack(alignment: .bottom, spacing: 18) {
                ForEach(PanelTab.allCases, id: \.self) { option in
                    Button {
                        tab = option
                        query = ""
                        searchFocused = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 19, weight: .medium))
                                .frame(width: 34, height: 25)
                            Capsule()
                                .fill(tab == option ? accent : .clear)
                                .frame(width: 25, height: 3)
                        }
                        .foregroundStyle(tab == option ? accent : Color.gray)
                    }
                    .buttonStyle(.plain)
                    .help(option.rawValue)
                    .accessibilityLabel(option.rawValue)
                }
                Spacer()
                Button { controller.hidePanel() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.65))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cerrar")
            }
            .padding(.horizontal, 18)

            HStack {
                Text(tab.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.17, blue: 0.24))
                Spacer()
                if tab == .clipboard {
                    Button { controller.clearHistory() } label: {
                        Text("Borrar recientes")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(red: 0.17, green: 0.23, blue: 0.31))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
                    }
                        .buttonStyle(.plain)
                        .disabled(!controller.items.contains { !$0.isPinned })
                        .help("Los elementos anclados se conservan")
                }
            }
            .padding(.horizontal, 18)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.gray)
                TextField("", text: $query, prompt: Text(tab == .clipboard ? "Buscar en el historial" : "Buscar emojis").foregroundColor(.gray))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.black)
                    .focused($searchFocused)
                    .onSubmit {
                        if tab == .clipboard, let first = filteredItems.first { controller.select(first) }
                        if tab == .emojis, let first = filteredEmojis.first { controller.selectEmoji(first.symbol) }
                    }
            }
            .padding(.horizontal, 11)
            .frame(height: 33)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.black.opacity(0.08)))
            .padding(.horizontal, 18)

            if tab == .clipboard {
                clipboardContent
            } else {
                emojiContent
            }

            HStack {
                Text(tab == .clipboard ? "Selecciona un elemento y pulsa ⌘V para pegarlo" : "Selecciona un emoji y pulsa ⌘V para pegarlo")
                    .font(.caption)
                    .foregroundStyle(Color.black.opacity(0.55))
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
        .frame(width: 430, height: 560)
        .background {
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.985, blue: 1), Color(red: 0.86, green: 0.93, blue: 1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .onAppear { searchFocused = true }
        .onExitCommand { controller.hidePanel() }
    }

    @ViewBuilder
    private var clipboardContent: some View {
        if filteredItems.isEmpty {
            ContentUnavailableView(
                query.isEmpty ? "Historial vacío" : "Sin resultados",
                systemImage: query.isEmpty ? "clipboard" : "magnifyingglass",
                description: Text(query.isEmpty ? "Copia texto, imágenes o archivos para verlos aquí." : "Prueba con otra búsqueda.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 9) {
                    ForEach(filteredItems) { item in
                        ClipboardCard(item: item, controller: controller)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 3)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var emojiContent: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(EmojiCatalog.categories, id: \.self) { category in
                        Button(category) { emojiCategory = category }
                            .buttonStyle(.plain)
                            .font(.caption.weight(emojiCategory == category ? .semibold : .regular))
                            .foregroundStyle(emojiCategory == category ? .white : Color.black.opacity(0.7))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(emojiCategory == category ? accent : .white.opacity(0.7), in: Capsule())
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)

            ScrollView {
                if filteredEmojis.isEmpty {
                    ContentUnavailableView.search
                        .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 7)], spacing: 7) {
                        ForEach(filteredEmojis) { entry in
                            Button { controller.selectEmoji(entry.symbol) } label: {
                                Text(entry.symbol)
                                    .font(.system(size: 27))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                            .help(entry.name)
                            .accessibilityLabel(entry.name)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 3)
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct ClipboardCard: View {
    let item: ClipboardItem
    @ObservedObject var controller: ClipboardController

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button { controller.select(item) } label: {
                Group {
                    switch item.content {
                    case .image(let data):
                        if let image = NSImage(data: data) {
                            HStack {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 130, height: 70)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                Spacer()
                                Text("Imagen").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    case .text, .files:
                        Text(item.title)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.13, green: 0.17, blue: 0.23))
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copiar: \(item.title)")
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 14) {
                Menu {
                    Button(item.isPinned ? "Desanclar" : "Anclar") { controller.togglePin(item) }
                    Button("Eliminar", role: .destructive) { controller.delete(item) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.62))
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24, height: 24)
                .tint(Color.black.opacity(0.62))
                .help("Más opciones")

                Button { controller.togglePin(item) } label: {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(item.isPinned ? Color.blue : Color.gray)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(item.isPinned ? "Desanclar" : "Anclar arriba")
            }
            .foregroundStyle(Color.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(item.isPinned ? Color.blue.opacity(0.7) : Color.black.opacity(0.09), lineWidth: item.isPinned ? 1.5 : 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}
