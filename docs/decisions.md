# Decisions

One line per decision: what, who decided, why. Status: **decided** or **proposed** (needs user OK).

| # | Date | Decision | By | Status | Why |
|---|------|----------|----|--------|-----|
| 1 | 2026-11-24 | Build own clipboard manager instead of fixing PasteNow | User | decided | PasteNow 2.39 saved nothing on macOS 27; user removed it |
| 2 | 2026-11-24 | ~~Similar features, own design~~ → **Same panel layout and flow as PasteNow**; own name, icons, artwork and colours | User | decided (revised) | User wants the PasteNow UI they know; layout is a common pattern, but its icons/artwork/brand are not copied. Personal use; revisit before any public release |
| 3 | 2026-11-24 | Name: **Recall** | User | decided | User's pick from 5 options |
| 4 | 2026-11-24 | Location: `~/Desktop/projects/personal/recall` | User | decided | User's personal projects folder |
| 5 | 2026-11-24 | Personal use only — never released; name "Recall" stays | User | decided | Name clash with other "Recall" apps does not matter |
| 6 | 2026-11-24 | Native Swift/SwiftUI menu bar app | Claude (user approved) | decided | Xcode + Swift 6.4 installed; best fit for macOS 27 |
| 7 | 2026-11-24 | Defer iCloud sync / iPhone app | Claude (user approved) | decided | Needs a second app; large extra scope |
| 8 | 2026-11-24 | **Never save password-manager copies** (items marked concealed/transient on the clipboard) | User | decided | Keep secrets out of history |
| 9 | 2026-11-24 | Local storage only, no network | Claude (user approved) | decided | Privacy; no sync in v1 |
| 10 | 2026-11-24 | First-version feature set closed (see design.md) | User | decided | User confirmed after the feature walk-through |
| 12 | 2026-11-24 | Track every copy: plain text, rich text (keep formatting + plain fallback), Markdown/code (plain text with a type label), images | User | decided | User wants all copies tracked, any text format |
| 13 | 2026-11-24 | **Save everything that can be copied**: text, rich text, Markdown, code, links, colour codes, images, Finder files (stored as paths), and any other format (saved as-is, shown with a generic label) | User | decided | User: "whatever I can copy should be there" |
| 30 | 2026-11-24 | Every clip row shows a **type icon** (link, colour swatch, text, Markdown, code, image thumbnail, file, other) | User | decided | User: "they will show icon like link, color code" |
| 14 | 2026-11-24 | Repeat copies move to top (see 19); **skip single clips over 25 MB** | User | decided | Avoid runaway disk use from huge images/data |
| 15 | 2026-11-24 | Keep only the **last 200** clips by default; limit editable in Settings | User | decided | User does not want unlimited history |
| 16 | 2026-11-24 | Pinned clips don't count toward the limit and are never auto-deleted; oldest unpinned clip (and its image file) removed when over limit | Claude (user approved) | decided | Pinning is meant to keep things |
| 17 | 2026-11-24 | Limit range 10–5000; lowering it asks for confirmation before deleting | Claude (user approved) | decided | Lowering the limit deletes clips — avoid accidental data loss |
| 18 | 2026-11-24 | Clips listed **newest first** | User | decided | User's request |
| 19 | 2026-11-24 | Copying (or pasting from Recall) something already in history moves it to the top instead of adding a duplicate (option A) | User | decided | User chose A over keeping duplicates |
| 27 | 2026-11-24 | **Cmd + Shift + V** opens the clip panel, from any app; shortcut **customizable in Settings** | User | decided | User's request, same as PasteNow |
| 28 | 2026-11-24 | Shortcut press again or Esc closes the panel; panel opens in the same spot as a menu bar click | Claude (user approved) | decided | One consistent place to look |
| 29 | 2026-11-24 | Settings has a shortcut recorder (click, press new keys) + "Reset to ⌘⇧V"; warns if the shortcut is already taken or has no modifier key | Claude (user approved) | decided | Avoid silently broken or typing-blocking shortcuts |
| 25 | 2026-11-24 | Recall lives in the **menu bar** (like PasteNow's "P"); clicking the icon opens the clip panel | User | decided | User's request |
| 26 | 2026-11-24 | Icons: **plain clipboard** (white outline + solid clip) on indigo→teal squircle; menu bar icon = same clipboard, black template. No arrows, clocks or extras | User | decided (user: "icon is now fine") | User: history symbol "looking like timer"; wants a simple clipboard |
| 20 | 2026-11-24 | Pinned clips live in their own Pinned tab; History tab is strictly newest first | User | decided | Matches the PasteNow tab layout; avoids pinned items breaking the order |
| 21 | 2026-11-24 | Clips can be **edited** and **deleted**; right-click shows a menu (Paste, Paste as…, Edit, Delete, etc.) | User | decided | User's request |
| 22 | 2026-11-24 | Menu items: Paste · Paste as Plain Text · Copy · Edit… · Pin/Unpin · Delete | Claude (user approved) | decided | Covers the user's list plus the pin and copy actions already planned |
| 23 | 2026-11-24 | Edit opens a small text editor window; only text clips are editable (images, files not); editing rich text saves it as plain text | Claude (user approved) | decided | Keeps editing simple and predictable |
| 24 | 2026-11-24 | Delete is immediate, no confirm; also the Delete key on a selected clip | Claude (user approved) | decided | Single clip, low stakes; confirm only for bulk deletes (decision 17) |
| 11 | 2026-11-24 | Start at Login in v1, **on by default**, with a checkmark toggle in the gear (settings) menu | User | decided | User wants it running after every restart, toggled from a settings menu like PasteNow's |
| 31 | 2026-11-24 | **Search** box filters the list as you type (text, file names, link URLs) | User | decided | User: "search should be there" |
| 32 | 2026-11-24 | **Clear all history** button in Settings, with confirmation | User | decided | User: "clear all also should be there" |
| 33 | 2026-11-24 | Clear all keeps pinned clips | Claude (user approved) | decided | Consistent with "pinned kept forever" (16) |
| 34 | 2026-11-24 | No custom lists (no "+" button); only History and Pinned tabs | User | decided | User: "no need of custom list" |
| 35 | 2026-11-24 | A pinned clip shows in **both** History (with 📌, normal position) and Pinned | User | decided | User chose B: History always shows everything copied |
| 36 | 2026-11-24 | Menu bar icon spins one full turn (0.3 s) each time a copy is saved; skipped when "Reduce motion" is on | User | decided | User asked for a 360° animation on copy |
| 37 | 2026-11-24 | Panel does not focus the search box on open; typing letters still filters (type-to-search) | User | decided | User: focus on open is unwanted |
| 38 | 2026-11-24 | View switcher right of History/Pinned: **List**, **Grid** (2-column cards), **Expanded** (default) (1-column detailed cards: large image, multi-line text, source app icon, time). Choice remembered | User | decided | User request, PasteNow-style multiple layouts |
| 39 | 2026-11-25 | Panel is **760 pt** tall (was 580); on shorter screens it fills the space below the menu bar minus 12 pt. Width stays 380 | User | decided | User: the panel was too short |
| 40 | 2026-11-25 | Re-copying (or pasting from Recall) a clip already in history **keeps its position**; it only becomes the latest copy. List order = when each clip was first saved. Opening the panel selects and scrolls to the latest copy. Replaces the move-to-top part of 14/19 | User | decided | User: the jump to the top was disorienting |
| 41 | 2026-11-25 | ⌘C in the panel no longer shows "Copied — not pasted"; the clip's outline turns solid **green** (no animation) until the selection moves or the panel reopens. VoiceOver announces "Copied" | User | decided | User: the yellow notice was unwanted |
