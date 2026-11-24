# Recall — Design (v1)

Status: **approved by user 2026-11-24** ("yes fine almost. please start building this").
Detail and history: `discussion.md` (why), `decisions.md` (numbered decisions, cited as #n),
`architecture.md` (components).

## 1. Intent

Recall is a personal macOS clipboard manager for one user on one Mac (macOS 27.2, Apple Silicon).
It replaces PasteNow 2.39, which ran but never saved a clip on macOS 27. The user wants the PasteNow
experience they know — menu bar icon, Cmd + Shift + V panel, search, pinning — in an app they own.

Success: every copy (except passwords) shows up in the panel at once, and getting it back is one
shortcut + one click or Enter.

## 2. Goals, non-goals, anti-goals

**Goals (v1)**
1. Save everything copied, newest first (#12, #13, #18).
2. Open the panel from the menu bar icon or Cmd + Shift + V; shortcut changeable (#25, #27).
3. Paste a clip straight into the app the user was in.
4. Search as you type (#31). Pin, edit, delete clips (#20–#24).
5. Start at Login, on by default (#11).

**Non-goals (v1)**
- iCloud sync, iPhone/iPad app, multiple Macs (#7).
- Custom lists, Smart Lists, Grid/Rich view styles, drag-out, Database View, Pasteboard Viewer.
- App Store or any public release — personal use only (#5).

**Anti-goals (would be a failure even if it "works")**
- Saving passwords from password managers (#8).
- Any network access; data leaving the Mac (#9).
- Silently losing pinned clips (#16).
- A shortcut that swallows normal typing (#29).

## 3. Constraints

- macOS 27.2, arm64. Toolchain: Xcode, Swift 6.4.2.
- No Apple Developer Program account assumed. App is built locally and signed with a **stable local
  signing identity** (a self-signed code-signing certificate, or the user's free Apple Development
  certificate if Xcode has one). Reason: macOS ties the Accessibility permission to the signature —
  ad-hoc signing changes every build and would make the user re-grant permission after each rebuild.
- Accessibility permission is needed only for auto-paste (simulated Cmd + V). Without it, Recall
  still puts the clip on the clipboard and shows a one-line hint to press Cmd + V.

## 4. Approaches considered

| Approach | Trade-off | Verdict |
|----------|-----------|---------|
| **Native Swift + SwiftUI/AppKit menu bar app** | Best fit for macOS 27: real `NSPanel`, global hotkey, `SMAppService` login item, small and fast. Swift only. | **Chosen** (#6, user approved) |
| Electron / Tauri (web UI) | Familiar web stack, but heavy memory for an always-on app; clipboard types, hotkeys and auto-paste still need native code. | Rejected |
| Fix or update PasteNow | No control; the failure was in PasteNow itself. User removed it. | Rejected (#1) |

## 5. What the user sees

### 5.1 Menu bar icon
Plain clipboard, black template image (macOS tints it) — `assets/MenuBarIcon.png` / `@2x` (#26).
Click → panel opens under the icon; click again → closes. No Dock icon.

### 5.2 Panel (same layout and flow as PasteNow, Recall's own icons and colours — #2)

```
┌──────────────────────────────────────┐
│ [📌]  [ 🔍 Type to Search...     ] ⚙ │
│  History   Pinned                    │
├──────────────────────────────────────┤
│ 🔗   https://github.com/…            │  ← newest
│ 🟠   #FF5733                          │
│ </>  const x = 1                      │
│ [🖼]  Screenshot 1440×900             │
│ 📄   report.pdf                       │
├──────────────────────────────────────┤
│                 37 items             │
└──────────────────────────────────────┘
```

- Dark floating panel, opens under the menu bar icon, also via the shortcut (#28).
- 📌 button detaches the panel into a normal window that stays open (#2).
- Tabs: **History** (every clip, strictly newest first) and **Pinned** (#20). A pinned clip shows in
  both: at its normal place in History with a small 📌, and in Pinned (#35). No custom lists (#34).
- Each row: type icon + one-line preview (#30). Icons:
  text `text.alignleft` · rich text `textformat` · Markdown `number` · code
  `chevron.left.forwardslash.chevron.right` · link `link` · colour = filled circle in that colour ·
  image = thumbnail · file = Finder icon · other `doc`.
- Empty state: "No clips yet — copy something".
- Footer: item count of the current tab.

### 5.3 Keyboard in the panel
- Typing goes to search; list filters as you type (#31) — matches clip text, file names and URLs,
  case-insensitive.
- ↑ ↓ move selection; **Enter** pastes; **Shift + Enter** pastes as plain text;
  **⌘C** copies without pasting; **⌘E** edit; **⌘P** pin/unpin; **Delete** deletes;
  **Esc** or the shortcut again closes (#22, #24, #28).

### 5.4 Right-click menu on a clip (#22)
```
 Paste                    ↩
 Paste as Plain Text      ⇧↩    (only for rich text)
 Copy                     ⌘C
 ─────────────────────────
 Edit…                    ⌘E    (text clips only, else greyed)
 Pin / Unpin              ⌘P
 ─────────────────────────
 Delete                   ⌫
```
- **Edit…** opens a small window with the text, Save / Cancel. Rich text becomes plain on save (#23).
- **Delete** is immediate, no confirmation (#24).

### 5.5 Gear menu
```
 Stop Monitoring Clipboard        (toggles to "Start Monitoring Clipboard")
 Clipboard Monitoring Interval  ▸ 0.25 s · 0.5 s (default) · 1 s · 2 s
 ─────────────────────────
 Settings…
 ✓ Start at Login
 ─────────────────────────
 About Recall
 Quit Recall
```
When monitoring is stopped, the menu bar icon is drawn at half opacity.

### 5.6 Settings window
```
 Shortcut:   [ ⌘⇧V ]  Reset to ⌘⇧V
 History:    [ 200 ] clips   (10–5000)
 ☑ Start at Login
 [ Clear All History… ]
```
- Shortcut recorder: click, press keys. Must include ⌘, ⌃ or ⌥; warns if another app holds it
  and keeps the previous one (#29).
- Lowering History below the current count asks first: "This will delete N older clips" (#17).
- **Clear All History…** asks first, then deletes every unpinned clip (#32). Pinned clips are kept
  and stay visible in both tabs (#33).

## 6. Behaviour rules

| Rule | Detail | Ref |
|------|--------|-----|
| What is saved | Every clipboard change: plain text, rich text (formatting + plain fallback), Markdown, code, links, colour codes, images, Finder files (paths), any other type saved raw so it pastes back exactly | #12, #13 |
| Never saved | Items marked concealed or transient (`org.nspasteboard.ConcealedType`, `TransientType`, `AutoGeneratedType`) — password managers | #8 |
| Size limit | Skip any single clip over 25 MB | #14 |
| Duplicates | Same content copied again → existing clip moves to top, no duplicate | #19 |
| Order | History sorted by last copied time, newest first | #18 |
| Pasting from Recall | Also moves that clip to top | #19 |
| Limit | Default 200 History clips; when over, delete oldest unpinned (and its image file) | #15, #16 |
| Pinned | A flag on the clip; shown in History (with 📌) and Pinned. Kept forever, not counted in the limit, not removed by Clear All. Re-copying it moves it to the top of History like any clip | #16, #33, #35 |
| Editing | Changes content in place; keeps position | #23 |
| Storage | Local only: `~/Library/Application Support/Recall` | #9 |
| Start at Login | Registered on first launch; user can turn off in gear menu or System Settings | #11 |
| All formats kept | A clip stores every format on the clipboard (e.g. plain + rich + app-specific), so it pastes back exactly. 25 MB limit = all formats together. Several files/items copied at once = one clip | Claude's call |
| Duplicate check | Based on the clip's main content (text, image bytes or file paths); same text with and without formatting counts as one clip, the newer formats replace the old | Claude's call |
| Recall's own writes | When Recall puts a clip on the clipboard (paste, paste as plain, copy), the watcher ignores that change; only the original clip moves to top | Claude's call |
| Paste target | Recall remembers the app that was in front when the panel opened. Paste = put clip on clipboard → close floating panel → bring that app back → Cmd + V. In the detached window, Enter does the same but the window stays open | Claude's call |

## 7. How it is built (decided parts)

Native Swift 6 + SwiftUI hosted in AppKit, `LSUIElement` menu bar app. Components and the API for
each are in `architecture.md`: MenuBarItem (`NSStatusItem`), ClipboardWatcher (polls
`NSPasteboard.changeCount`), ClipStore (local database + image files), HotkeyManager (Carbon
`RegisterEventHotKey`), PanelView (`NSPanel` + SwiftUI), Paster (pasteboard write + `CGEvent` Cmd + V),
SettingsView, login item (`SMAppService`). App icon `assets/AppIcon.icns`.

## 8. Left to the builder

- Project layout (Xcode project vs Swift Package + bundling script) and the signing setup, within
  the constraint in §3.
- Database choice (SwiftData or SQLite) and schema.
- How Markdown / code / colour codes are detected (simple heuristics are fine; a wrong label is
  harmless, content is never changed).
- Exact panel size, colours and fonts, within "dark floating panel like PasteNow".
- First-run flow for asking Accessibility permission.
- Tests: small tests for the logic with branches — clip classification, duplicate/move-to-top,
  history trimming with pinned clips, size limit, concealed-type skipping.
