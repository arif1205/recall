# Discussion log

Running record of conversations that shaped Recall. Newest at the bottom.

## 2026-11-24 — Why Recall exists

**Background.** The user installed PasteNow 2.39 (build 771) on macOS 27.2.1. It opened and showed
"Stop Monitoring Clipboard" (so monitoring was on), but never saved a single clip ("No Clips Yet",
0 items).

Troubleshooting done:
- No "Pasteboard / Paste from Other Apps" privacy category exists in Privacy & Security on this Mac,
  so macOS was not blocking clipboard reads.
- System log showed no TCC or pasteboard denials for PasteNow.
- App restarted; test text copied with `pbcopy`; still 0 items.
- A newer PasteNow build (901) had been offered and skipped. Likely cause: old build incompatible
  with macOS 27. Not verified.

Outcome: user removed PasteNow completely (app, DMG, login item, `~/Library` data, group container)
and asked to build a similar app of their own.

## 2026-11-24 — PasteNow feature survey

Features found for PasteNow (website, App Store, reviews, and what was seen on the user's Mac):

1. Unlimited clipboard history
2. iCloud sync between Mac, iPhone and iPad
3. Saves text, links, images and code
4. Recognises colour codes (e.g. `#FF5733`) and shows a swatch
5. Three view styles: Simple List, Rich List, Grid
6. Smart Lists that sort clips automatically
7. Custom lists
8. Pinning
9. Search
10. Global shortcut to open (was Cmd + Shift + V)
11. Paste with original formatting or as plain text
12. Drag one or more clips into other apps
13. Clipboard monitoring on/off
14. Clipboard check interval
15. Database View
16. Pasteboard Viewer
17. Start at Login

Sources: https://pastenow.app/, https://apps.apple.com/app/pastenow-instant-clipboard/id1552536109,
https://alternativeto.net/software/pastenow/about

Rule agreed in spirit: build an app with similar *features*, but its own name and design, not a
copy of PasteNow's look.

## 2026-11-24 — Name and location

- Name options offered: ClipNest, Recall, CopyVault, Snipbox, Rewind Clip.
- User chose **Recall**.
- Other Mac apps already use "Recall" (including clipboard managers). Fine for personal use;
  a rename is needed before any App Store release.
- Project folder: `~/Desktop/projects/personal/recall`.

## 2026-11-24 — Feature 1: Start at Login

User: "first of all, it should be start at login, like the pastenow settings ui".

Agreed:
- Recall starts automatically when the user logs in. On by default after first launch.
- A gear icon in the panel opens a settings menu with a **Start at Login** item; a checkmark shows
  when it is on, clicking toggles it. Same idea as PasteNow's gear menu, Recall's own styling.
- macOS also lists it under System Settings → General → Login Items, where it can be turned off.

## 2026-11-24 — Feature 2: Track every copy

User: "it should track all the copy, like image, text (any format, like md, or simple text)".

Agreed (user):
- Plain text, rich text (from Pages, Word, web pages), Markdown and code, images.

Proposed by Claude (waiting for OK):
- Markdown is plain text on the clipboard, so Recall stores it as text and labels it "MD" when it
  looks like Markdown (headings, lists, links); code gets a "Code" label the same way.
- Rich text keeps its formatting, plus a plain copy for "paste as plain text".
- Also track links, colour codes (with swatch) and files copied in Finder (stored as paths).
- Skip an item identical to the previous one; skip images over 25 MB.
- Never save password-manager copies (decision 8).

## 2026-11-24 — UI: same as PasteNow

User: "the ui should be same as paste now". Replaces the earlier "own design" idea (decision 2).

Layout taken from the user's PasteNow screenshots:

```
┌──────────────────────────────────────┐
│ [lists]  [ 🔍 Type to Search...  ] ⚙ │  top bar
│  History  Pinned  …               +  │  list tabs, + adds a list
├──────────────────────────────────────┤
│  clip rows (newest first)            │
│  …                                   │
│  empty state: "No clips yet"         │
├──────────────────────────────────────┤
│ [filter]          N items            │  footer
└──────────────────────────────────────┘
```

- Floating dark panel under the menu bar, opened by Cmd + Shift + V or the menu bar icon.
- Can be pinned/detached into a normal window (seen in PasteNow).
- Gear menu: Stop/Start Monitoring, Monitoring Interval, Settings…, Start at Login (✓), About, Quit.
- Same arrangement and behaviour; Recall uses its own icon, SF Symbols and colours, not PasteNow's
  artwork or branding.

## 2026-11-24 — History limit

User: "it should not keep unlimited, it should only keep the last 200 (configurable in the settings)".
Replaces "unlimited history" (PasteNow feature 1).

Agreed (user): default 200 clips; number editable in Settings.

Proposed by Claude (waiting for OK):
- Pinned clips are kept forever and don't count toward the 200.
- When a new clip pushes history over the limit, the oldest unpinned clip is deleted, including its
  saved image.
- Allowed range 10–5000. Lowering the limit below the current count shows a confirmation
  ("This will delete 150 older clips") before deleting.

## 2026-11-24 — Order

User: "clips should be newest first".

Proposed by Claude (waiting for OK):
- Copying something already in history moves the existing clip to the top (no duplicate).
- Pinned clips show in the Pinned tab; the History tab stays strictly newest first.

## 2026-11-24 — Edit, delete, right-click menu

User: "in the list, it can be edit, or delete, and right click on the item should show a menu as
edit delete paste as etc."

Proposed right-click menu (waiting for OK):

```
 Paste                    ↩
 Paste as Plain Text      ⇧↩
 Copy                     ⌘C
 ─────────────────────────
 Edit…                    ⌘E
 Pin / Unpin              ⌘P
 ─────────────────────────
 Delete                   ⌫
```

- Edit… opens a small editor window with the clip's text, Save / Cancel. Only for text clips;
  greyed out for images and files. Editing rich text saves it as plain text.
- Delete removes the clip at once (no confirmation); Delete key works on the selected clip.
- "Paste as Plain Text" only shown for rich text clips.

## 2026-11-24 — Duplicates

User chose **A**: re-copying something already in history moves the existing clip to the top;
it never appears twice.

## 2026-11-24 — Menu bar icon and app icon

User: "it should be in the accessibility like the paste now, generate a icon for that" and
"clicking on that will show the list as paste now". Read as: a menu bar icon, like PasteNow's "P";
clicking it opens the clip panel.

Generated (in `assets/`):
- `AppIcon.icns` + `AppIcon.iconset/` + `AppIcon-1024.png`: white clipboard with a history
  (counter-clockwise clock) arrow on an indigo→teal rounded square. Also shown in Finder, the Dock
  (when Settings is open) and Privacy & Security → Accessibility.
- `MenuBarIcon.png` (18 px) + `MenuBarIcon@2x.png` (36 px): black template version; macOS tints it
  for light/dark menu bars.

User then: "make the icon simpler, with one icon type thing". Clipboard removed; both icons are now
just the history symbol (clock with a backward arrow). Same files in `assets/`, regenerated.

## 2026-11-24 — Keyboard shortcut

User: "cmd + shift + v should open the list like paste now, it should be customizable".

Agreed (user): Cmd + Shift + V opens the panel from any app; can be changed in Settings.

Proposed by Claude (waiting for OK):
- Pressing the shortcut again, or Esc, closes the panel.
- Panel opens in the same place as clicking the menu bar icon.
- Settings → Shortcut: click the box, press the new keys. "Reset to ⌘⇧V" button.
- Warn if another app already uses that shortcut, or if it has no Cmd/Ctrl/Option key
  (a shortcut like plain "V" would block typing).

User then: "the icon is looking like timer, change it, use clipboard type thing, without any funky
thing, simple clipboard". Both icons are now a plain clipboard: rounded board outline with a solid
clip on top. Regenerated in `assets/`.

User approved the clipboard icon: "the icon is now fine".

## 2026-11-24 — Everything copyable is saved

User: "whatever I can copy should be there". Settles decision 13: all copy types are saved.
Links and colour codes are just text with an extra touch (link label/favicon; colour swatch for
`#FF5733`-style codes). Any format Recall doesn't recognise is saved as-is with a generic label so it
can still be pasted back.

Still proposed: never save password-manager copies (decision 8); skip single clips over 25 MB
(decision 14).

## 2026-11-24 — Type icons on each clip

User: "yes they will show icon like link, color code". Each row gets an icon on the left:

| Clip | Icon (SF Symbol unless noted) |
|------|------|
| Plain text | `text.alignleft` |
| Rich text | `textformat` |
| Markdown | `number` (as in `#` heading) |
| Code | `chevron.left.forwardslash.chevron.right` |
| Link | `link` |
| Colour code | filled circle in that colour (not a symbol) |
| Image | small thumbnail of the image (not a symbol) |
| Finder file | the file's own Finder icon (not a symbol) |
| Other | `doc` |

```
 🔗  https://github.com/…
 🟠  #FF5733
 </>  const x = 1
 🖼  [thumbnail]  Screenshot 1440×900
 📄  report.pdf
```

Icon choices above are Claude's proposal; the "show an icon per type" rule is the user's.

## 2026-11-24 — Password managers

User: "yes password managers should not save". Decision 8 now decided. Works for apps that mark
their copies as concealed (1Password, Bitwarden, Apple Passwords, KeePassXC and most others).
An app that doesn't mark them can't be detected this way; a "never save from these apps" list
could cover that later.

User on the shortcut proposals: "shortcut decision, i am okay with you". Decisions 28–29 approved.

User: "skip items over 25mb". Decision 14 decided.

## 2026-11-24 — Proposals approved

User approved 6 (native Swift), 9 (local only), 7 (no sync for now), 16 (pinned kept forever),
17 (limit 10–5000, confirm on lowering), 22 (right-click menu), 23 (edit text clips only),
24 (instant delete). On 5: "never going to release" — Recall is personal only, name stays.

## 2026-11-24 — Search and Clear all; feature set closed

User: "yes search should be there. clear all also should be there". Search filters as you type;
Settings gets Clear all history with a confirmation. Feature walk-through finished — next step is
the final design (`design.md`) for approval, then a build plan.

## 2026-11-24 — Review of design.md

A reviewer read design.md as a builder. Settled by Claude (recorded in design.md §6): every
clipboard format kept per clip; duplicate check on main content; Recall ignores its own clipboard
writes; paste returns to the app that was in front.

User answers: Clear All keeps pinned clips — "okay" (#33). Custom lists — "no need" (#34).

User chose **B** for pinned clips: they stay in History (marked 📌) and also show in Pinned (#35).

## 2026-11-24 — Clickable mockup

User asked for a local HTML mockup of every screen and action from design.md: `docs/mockup.html`
(open in a browser). Left side lists each screen/action; right side is a fake Mac desktop with the
menu bar icon, panel, menus, Settings and dialogs. Simulated only; it never touches the real clipboard.

## 2026-11-24 — v1 built and installed

Built per plan, installed to `/Applications/Recall.app`, signed with Apple Development. 38 tests pass.
Final code review: 3 important fixes applied (detached-window paste target, ⌫ key-repeat delete, unpin at limit),
plus unreadable index no longer overwritten. Deferred minors: orphan data after index recovery, previous app not
re-activated after Edit → Save, silent hotkey conflict at launch, no notice for missing files, duplicate content
after edit, thumbnails decoded on main thread. User confirmed the menu bar icon is visible.

## 2026-11-25 — Repeat copies keep their position

User: copying a clip that is lower in the list jumped it to the top, which was the original design (#19).
They no longer want that. The clip should stay where it is, be the latest copy, and be selected when
⌘⇧V opens the panel. A copy of something new still goes on top and becomes the selection. Done as #40.

## 2026-11-25 — ⌘C feedback

User did not want the yellow "Copied — not pasted" notice after ⌘C in the panel. They asked for the
card to get a briefly animated green outline instead of the blue accent. Done as #41.

