import AppKit
import RecallCore
import SwiftUI

struct PanelView: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: ClipStore
    @ObservedObject var settings: RecallCore.Settings
    @FocusState private var searchFocused: Bool
    @State private var loginOn = LoginItem.isEnabled

    var body: some View {
        let clips = model.visible
        VStack(spacing: 0) {
            header
            tabs
            if model.needsAccessibility { accessibilityHint }
            if let notice = model.notice {
                Text(notice).font(.system(size: 11)).foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.bottom, 4)
            }
            Divider()
            if clips.isEmpty { empty } else { list(clips) }
            Divider()
            Text("\(clips.count) item\(clips.count == 1 ? "" : "s")")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .frame(height: 32)
        }
        .frame(width: 380).frame(maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button { model.detached.toggle(); model.onDetachChanged() } label: {
                Image(systemName: model.detached ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .help(model.detached ? "Back to floating panel" : "Keep open as a window")
            .accessibilityLabel("Detach panel")

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search  ⌘F", text: $model.query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onChange(of: model.searchRequests) { searchFocused = true }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.25)))

            gearMenu
        }
        .padding(.horizontal, 12).padding(.top, model.detached ? 30 : 10).padding(.bottom, 6)
    }

    private var gearMenu: some View {
        Menu {
            Button(settings.monitoring ? "Stop Monitoring Clipboard" : "Start Monitoring Clipboard") {
                model.toggleMonitoring()
            }
            Picker("Clipboard Monitoring Interval", selection: Binding(
                get: { settings.interval },
                set: { settings.interval = $0; model.onMonitoringChanged() })) {
                ForEach(RecallCore.Settings.intervals, id: \.self) { v in
                    Text(v == 0.5 ? "0.5 s (default)" : "\(v.formatted()) s").tag(v)
                }
            }
            Divider()
            Button("Settings…") { model.onSettings() }.keyboardShortcut(",")
            Toggle("Start at Login", isOn: Binding(
                get: { loginOn },
                set: { LoginItem.set($0); loginOn = LoginItem.isEnabled }))
            Divider()
            Button("About Recall") {
                NSApp.activate()
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            Button("Quit Recall") { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Image(systemName: "gearshape")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onTapGesture { loginOn = LoginItem.isEnabled }
        .accessibilityLabel("Menu")
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            tabButton("History", .history)
            tabButton("Pinned", .pinned)
            Spacer()
            Picker("View", selection: Binding(get: { settings.viewMode }, set: { settings.viewMode = $0 })) {
                Image(systemName: "rectangle.grid.1x2").help("Expanded").tag(ViewMode.expanded)
                Image(systemName: "list.bullet").help("List").tag(ViewMode.list)
                Image(systemName: "square.grid.2x2").help("Grid").tag(ViewMode.grid)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel("View")
        }
        .padding(.horizontal, 12).padding(.bottom, 8)
    }

    private func tabButton(_ title: String, _ tab: RecallCore.Tab) -> some View {
        Button(title) { model.tab = tab }
            .buttonStyle(.plain)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(model.tab == tab ? Color.white.opacity(0.12) : .clear))
            .foregroundStyle(model.tab == tab ? .primary : .secondary)
    }

    private var accessibilityHint: some View {
        HStack(spacing: 4) {
            Text("Recall can't paste for you yet — clips are copied, press ⌘V.")
            Button("Allow") { model.paster.requestAccessibility() }.buttonStyle(.link)
        }
        .font(.system(size: 11)).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.bottom, 4)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard").font(.system(size: 36)).foregroundStyle(.tertiary)
            if !model.query.isEmpty {
                Text("No clips match “\(model.query)”")
            } else if model.tab == .pinned {
                Text("No pinned clips yet")
                Text("Right-click a clip → Pin").font(.system(size: 11))
            } else {
                Text("No clips yet")
                Text("Copy something and it shows up here").font(.system(size: 11))
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func list(_ clips: [Clip]) -> some View {
        let selectedID = model.selected?.id
        return ScrollViewReader { proxy in
            ScrollView {
                switch settings.viewMode {
                case .list:
                    LazyVStack(spacing: 2) {
                        ForEach(clips) { clip in
                            interactive(clip, ClipRow(clip: clip, selected: clip.id == selectedID,
                                                      showPin: model.tab == .history, model: model))
                        }
                    }
                    .padding(6)
                case .grid:
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(clips) { clip in
                            interactive(clip, ClipCard(clip: clip, selected: clip.id == selectedID, expanded: false, model: model))
                        }
                    }
                    .padding(10)
                case .expanded:
                    LazyVStack(spacing: 8) {
                        ForEach(clips) { clip in
                            interactive(clip, ClipCard(clip: clip, selected: clip.id == selectedID, expanded: true, model: model))
                        }
                    }
                    .padding(10)
                }
            }
            .onChange(of: model.selection) { _, id in
                if let id { proxy.scrollTo(id) }
            }
            .onChange(of: model.openCount) {
                if let id = model.selection { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func interactive(_ clip: Clip, _ view: some View) -> some View {
        view
            .id(clip.id)
            .onTapGesture(count: 2) { model.paste(clip) }
            .onTapGesture { model.selection = clip.id }
            .contextMenu { contextMenu(clip) }
    }

    @ViewBuilder private func contextMenu(_ clip: Clip) -> some View {
        Button("Paste") { model.paste(clip) }.keyboardShortcut(.return, modifiers: [])
        if clip.kind == .rich {
            Button("Paste as Plain Text") { model.paste(clip, plain: true) }.keyboardShortcut(.return, modifiers: .shift)
        }
        Button("Copy") { model.copyOnly(clip) }.keyboardShortcut("c")
        Divider()
        Button("Edit…") { model.edit(clip) }.keyboardShortcut("e").disabled(!clip.kind.isEditable)
        Button(clip.pinned ? "Unpin" : "Pin") { model.togglePin(clip) }.keyboardShortcut("p")
        Divider()
        Button("Delete") { model.delete(clip) }.keyboardShortcut(.delete, modifiers: [])
    }
}
