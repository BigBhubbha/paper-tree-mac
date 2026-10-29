# Paper Tree for Mac (v0.1)

A lab flask that lives in the notch. Double-tap the right Option key and a black island grows out of the notch with Research mode, Settings, and updates. Triple-tap to flip Research mode. With Research mode on, highlight anything you are reading in any app and it explains it on a small taped card, in plain words.

Built to work in Preview, Safari, Chrome, Word, Pages, Notes, and most apps with real text (not yet tested on a real Mac). No AI key lives in the app; it talks to your own small server (see `../backend`).

## Build and run (no Xcode needed)

You need the Command Line Tools once: `xcode-select --install`

```
cd paper-tree-mac/mac-app
./build.sh --run
```

That compiles, assembles `build/Paper Tree.app`, signs it ad hoc, and opens it.

- `./build.sh` only builds.
- `./build.sh --install` builds, copies it to /Applications, and opens it there (needed for "Open at login").

The first time, macOS may say the app is from an unidentified developer. Right-click `Paper Tree.app`, choose Open, then Open again.

## Permissions

1. **Accessibility** (required). System Settings, Privacy & Security, Accessibility, switch on Paper Tree. The welcome window has a button that takes you there. This lets Paper Tree read the text you highlight and press Cmd+C for you in apps that hide their text.
2. **Local rebuilds** are signed ad hoc, so macOS sees a "new" app after each one. Release builds from GitHub Actions are signed with the long-lived "Paper Tree Signing" certificate and a fixed designated requirement, so Accessibility stays on across updates. For a local ad hoc build: If highlights stop working, open that same Accessibility list, select Paper Tree, press the minus button, then add it again (or toggle it off and on). Quit and reopen Paper Tree.
3. No other permissions. Paper Tree never asks for Input Monitoring, Screen Recording, or files. It listens to mouse clicks, and to the right Option key only to count taps; it never records what you type.

## Connect the explainer

Deploy `../backend` to Netlify (its README walks through it), then open Paper Tree's Settings from the menu bar flask and paste `https://YOUR-SITE.netlify.app/api/explain`. Press Test it. Until then the card shows a friendly "No explainer connected yet" note. It never makes up text.

## How it works

- `Island.swift`: the notch island (a non-activating panel above the menu bar that springs open from the notch, or from the top center on Macs without one), its quick "Research mode on/off" flash, and the right Option tap detector (key code 61: double-tap opens, triple-tap toggles).
- `BuddyView.swift`: the flask, drawn in code (mint glass, liquid, rising bubbles, pink-lavender halo, closed "^ ^" eyes, goggles in research mode).
- `SelectionMonitor.swift`: global mouse monitors. About 350 ms after a drag, double-click, triple-click, or shift-click, it reads the highlight and opens the card. Held Cmd, Control, or Option skips it, and the same highlight does not fire twice.
- `Accessibility.swift`: reads `AXSelectedText`, `AXSelectedTextRange`, and `AXBoundsForRange` from the focused element (or the element under the mouse and its parents), plus about 300 characters on each side as context.
- `CopyFallback.swift`: if Accessibility has no text, it saves your clipboard, presses Cmd+C, reads the text, and puts your clipboard back. You can turn this off in Settings.
- `CardController.swift` and `ExplanationCard.swift`: the card. Simpler and More detail re-ask the server. Esc, the close button, or a click anywhere else closes it.
- `ExplainClient.swift`: POSTs `{text, context, mode}` to your endpoint with friendly errors.

## Settings that are saved

Research mode, server address, app token, copy fallback. They live in `~/Library/Preferences/com.papertree.mac.plist`.

## Where it may struggle

- **Chrome and Electron apps**: Chrome often reports no selected text through Accessibility. Paper Tree asks for it (`AXManualAccessibility`) and falls back to Cmd+C, so the text works, but the card is placed from your mouse position instead of the exact highlight.
- **PDFs in Chrome, Acrobat, and some viewers**: same as above, fallback with approximate placement. Preview usually works through Accessibility.
- **Scanned PDFs** (pictures of text) have no text to read. Nothing happens.
- **Apps that change selection on click**: the card opens on its own after you let go, so there is nothing to click.
- **Clipboard managers** may record the brief Cmd+C. Non-QWERTY layouts such as Dvorak may send a different shortcut for the fallback.
- **Terminal and code editors**: work, but these are not what it is tuned for.

## Open in Xcode instead

See `XCODE.md`.
