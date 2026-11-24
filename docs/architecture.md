# Architecture (proposed)

Status: **draft**. Nothing here is built yet. Feature set still open — see `discussion.md`.

## Platform

- Native macOS menu bar app, Swift 6 + SwiftUI, AppKit where SwiftUI falls short.
- Target: macOS 27 (the user's machine). Toolchain on hand: Xcode, Swift 6.4.2, arm64.
- No Dock icon (`LSUIElement = YES`).

## Components

```
 ┌──────────────┐  new clip   ┌──────────────┐  read/write  ┌─────────────┐
 │ ClipboardWatcher ├────────▶│  ClipStore   │◀────────────▶│ SQLite file │
 └──────────────┘             └──────┬───────┘              └─────────────┘
                                     │ clips
 ┌──────────────┐  open panel ┌──────▼───────┐  chosen clip ┌─────────────┐
 │ HotkeyManager ├───────────▶│  PanelView   ├─────────────▶│   Paster    │
 └──────────────┘             └──────────────┘              └─────────────┘
```

| Part | Job | How |
|------|-----|-----|
| MenuBarItem | Icon in the menu bar; click opens the panel | `NSStatusItem` with `assets/MenuBarIcon.png` set as a template image (`isTemplate = true`). Left-click toggles the panel; panel anchors under the icon. |
| ClipboardWatcher | Detect new copies | Poll `NSPasteboard.general.changeCount` on a timer (macOS has no clipboard-change notification). Skip items marked `org.nspasteboard.ConcealedType` / `TransientType` (password managers). |
| Clip types | What one clip holds | Read pasteboard types in priority order: file URLs (`public.file-url`), image (`public.png` / `public.tiff`), rich text (`public.rtf`, `public.html`) + its plain string, plain text (`public.utf8-plain-text`). Plain text then classified: URL, colour code, Markdown, code, or text — a label only, content stored unchanged. Anything else: store every pasteboard type's raw data so it pastes back exactly; label "Other". Each type maps to a row icon (table in `discussion.md` → "Type icons"): SF Symbol, colour swatch, image thumbnail (generated once at save, stored beside the image) or `NSWorkspace.shared.icon(forFile:)` for files. |
| ClipStore | Save, search, pin, cap history | SwiftData (or SQLite) in `~/Library/Application Support/Recall`. Images stored as files, path in DB. Each clip has a content hash and `lastCopiedAt`; a repeat copy updates `lastCopiedAt` instead of inserting. Lists sort by `lastCopiedAt` descending (newest first). After each insert, trim unpinned clips beyond `historyLimit` (default 200, stored in `UserDefaults`), oldest first, deleting their image files too. |
| Clip actions | Right-click menu + shortcuts on a clip row | SwiftUI `.contextMenu` on each row: Paste, Paste as Plain Text (rich text only), Copy, Edit…, Pin/Unpin, Delete. Edit… opens an `EditClipView` window (text clips only); save updates content, hash and keeps position. Delete removes the row and its image file. |
| SettingsView | Settings window (gear → Settings…) | SwiftUI `Settings` scene. v1 fields: History limit (stepper/field, 10–5000, confirm before a lower value deletes clips), Start at Login, Shortcut (recorder field + "Reset to ⌘⇧V"; needs at least one of ⌘ ⌃ ⌥). |
| HotkeyManager | Global shortcut, default Cmd + Shift + V, user-changeable | Carbon `RegisterEventHotKey` (works without Accessibility permission). Key code + modifiers stored in `UserDefaults`; on change, unregister old and register new. Registration failure (`eventHotKeyExistsErr`) → warning in Settings, keep previous shortcut. Toggles the panel. |
| PanelView | Floating search + list, PasteNow-style layout (see `discussion.md` → "UI") | `NSPanel` (non-activating, dark material) anchored under the menu bar icon, hosting SwiftUI: top bar (lists button, search field, gear menu), list tabs + "+", clip list, footer with item count. Pin button detaches it into a normal window. Arrow keys, Enter, Esc. SF Symbols only, no third-party artwork. |
| Paster | Put clip back and paste | Write clip to pasteboard, then send Cmd + V via `CGEvent`. Needs Accessibility permission. Plain-text variant strips formatting. |
| Login item | Start at login (on by default) | `SMAppService.mainApp.register()` on first launch. Gear menu item shows a checkmark from `SMAppService.mainApp.status` and toggles `register()` / `unregister()`. Read status each time the menu opens, since the user can also change it in System Settings → Login Items. |

## Permissions

- **Accessibility**: only for auto-paste (simulated Cmd + V). Without it, Recall still copies the
  clip back so the user can press Cmd + V themselves.
- No network access. All data stays local.

## Not in this design

- iCloud sync / iPhone app.
- Custom lists, Smart Lists, Grid view, drag-out — candidates for a later version.
