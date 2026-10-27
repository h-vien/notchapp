---
name: NotchChat
description: A discreet Telegram conversation surface that feels continuous with the MacBook notch.
colors:
  telegram-blue: "#2EA3F0"
  panel-tint: "rgba(9, 12, 17, 0.48)"
  text-primary: "rgba(255, 255, 255, 0.96)"
  text-secondary: "rgba(255, 255, 255, 0.62)"
  surface-raised: "rgba(255, 255, 255, 0.095)"
  separator: "rgba(255, 255, 255, 0.13)"
  glass-edge: "rgba(255, 255, 255, 0.20)"
  glass-highlight: "rgba(255, 255, 255, 0.08)"
typography:
  headline:
    fontFamily: "SF Pro Rounded, SF Pro Display, system-ui, sans-serif"
    fontSize: "19px"
    fontWeight: 700
    lineHeight: 1.15
  title:
    fontFamily: "SF Pro Rounded, SF Pro Text, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 700
    lineHeight: 1.2
  body:
    fontFamily: "SF Pro Text, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: 1.3
  label:
    fontFamily: "SF Pro Text, system-ui, sans-serif"
    fontSize: "10px"
    fontWeight: 600
    lineHeight: 1.2
rounded:
  field: "8px"
  composer: "9px"
  bubble: "10px"
  control: "12px"
  compact-panel: "15px"
  expanded-panel: "24px"
spacing:
  hairline: "0.5px"
  micro: "4px"
  tight: "5px"
  compact: "6px"
  control: "8px"
  panel: "14px"
  auth: "18px"
components:
  panel-expanded:
    backgroundColor: "{colors.panel-tint}"
    rounded: "{rounded.expanded-panel}"
    width: "310px"
    height: "340px"
  panel-compact:
    backgroundColor: "transparent"
    rounded: "0px"
    width: "physical-notch-width"
    height: "physical-notch-height"
  button-primary:
    backgroundColor: "{colors.telegram-blue}"
    textColor: "#000000"
    typography: "{typography.title}"
    rounded: "{rounded.control}"
    height: "36px"
  icon-button:
    textColor: "{colors.text-secondary}"
    rounded: "{rounded.control}"
    size: "24px"
  input-compact:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    typography: "{typography.body}"
    rounded: "{rounded.field}"
    height: "28px"
  message-outgoing:
    backgroundColor: "{colors.telegram-blue}"
    textColor: "#000000"
    typography: "{typography.body}"
    rounded: "{rounded.bubble}"
    padding: "5px 7px"
  message-incoming:
    textColor: "{colors.text-primary}"
    typography: "{typography.body}"
    rounded: "{rounded.bubble}"
    padding: "5px 7px"
---

# Design System: NotchChat

## Overview

**Creative North Star: "The Living Notch"**

NotchChat should feel like the physical display cutout has quietly gained a useful second state. Its visual world is native macOS glass cooled by a near-black wash, defined by one fine highlight edge, and animated as a single object growing down from the screen boundary. It is compact, technical, and calm—not a miniature social feed.

This is an Operate surface. Sender, message text, and reply remain immediately scannable while the interface recedes. Telegram blue supplies recognition and action; SF Symbols, system materials, and native focus behavior keep the surface at home on macOS. Custom application artwork belongs in the menu bar, not inside the notch panel.

The menu bar uses the dedicated transparent `MenuBarIcon.png` at 20-by-20 points. Its notch-and-plane mark fills almost the whole canvas for small-size legibility; the system paper-plane symbol is fallback-only when the resource cannot be loaded.

**Key Characteristics:**

- True system glass with a cool near-black tint
- A fine highlight edge and restrained ambient shadow
- Deliberately tight information density
- Telegram blue used for action, unread state, and outgoing messages
- Name-and-text conversation content with no decorative identity furniture
- Privacy-preserving collapsed state

## Colors

The palette is nearly monochrome glass, with one crisp Telegram-blue accent and opacity-driven neutral hierarchy.

### Primary

- **Telegram Signal Blue:** The sole branded accent for unread indicators, actionable links, enabled send controls, incoming sender labels, and outgoing bubbles.

### Neutral

- **Cool Obsidian Tint:** Washes the native glass material so the panel remains legible across changing desktop content.
- **Frosted White:** Primary copy and high-emphasis symbols.
- **Mist White:** Secondary copy, placeholders, inactive symbols, and offline state.
- **Raised Frost:** Pressed controls and quiet field surfaces.
- **Hairline Frost:** Separators and field or incoming-bubble outlines.
- **Glass Edge:** The single perimeter stroke that defines the object against the desktop.
- **Top Glint:** A short vertical highlight that concentrates light near the screen edge.

### Named Rules

**The One Signal Rule.** Telegram blue is the only routine chromatic accent; do not distribute chat-specific rainbow colors through the panel.

**The Glass Must Be Real Rule.** Begin with a native macOS material, then tint it. A flat opaque dark fill is not a substitute.

## Typography

**Display Font:** SF Pro Rounded with SF Pro Display and system fallbacks  
**Body Font:** SF Pro Text with system fallbacks

**Character:** Native, compact, and personable without becoming playful. Rounded bold faces identify the panel and major state; regular system text keeps dense message content effortless to scan.

### Hierarchy

- **Headline:** Reserved for authentication-step titles.
- **Title:** Panel titles, primary action labels, and compact high-emphasis controls.
- **Body:** Search, message previews, message text, instructions, and composer content.
- **Label:** Sender names, links, supporting status, and compact metadata.

### Named Rules

**The Native Voice Rule.** Use the Apple system family and SF Symbols; do not introduce a web font or ornamental display face.

**The Content Wins Rule.** Weight and opacity establish hierarchy. Avoid extra labels, timestamps, badges, or uppercase utility copy when name and message text are sufficient.

## Layout

The panel is centered on the active display and attached flush to its top edge. Its custom silhouette leaves the top corners square against the screen while rounding only the lower corners. The physical camera housing owns the top occlusion region, which must remain empty.

On a notched MacBook, the collapsed window exactly matches the physical notch gap and menu-bar height reported by macOS. It is fully transparent, with no content, edge, material, or shadow; the hardware supplies the visible black shape. Displays without a notch retain an invisible 148-by-12 hover target as a fallback. The app expands to a narrow 310-by-340-point working surface. Headers are 36 points high; list rows are 34 points high; search and composer regions use tight 4–8 point internal rhythms. Lists scroll without visible indicators.

Expansion is hover-first. Entering the hit region expands immediately; leaving the whole panel begins a 280 ms dismissal grace period. The panel also collapses on Escape or loss of keyboard focus.

## Elevation & Depth

Depth is a hybrid of native blur, translucent tonal layering, a short top glint, and one ambient shadow. The system material carries environmental context; the tint protects contrast; the edge and shadow separate the panel without making it look like a floating card stack. Nested inputs and incoming bubbles use thinner material, not opaque slabs.

### Shadow Vocabulary

- **Expanded Ambient:** Black at 32% opacity, 24-point blur radius, and 12-point downward offset. Use only for the expanded panel.
- **Collapsed:** No software shadow. The app must be visually indistinguishable from the physical notch.
- **Online Pinpoint:** A four-point green glow may accompany the tiny online indicator; it is a status signal, not decorative illumination.

### Named Rules

**The Single Object Rule.** Elevate the panel as one object. Do not give every row, control, or message its own drop shadow.

## Shapes

The signature form is the notch extension: square at the screen edge and continuously rounded along the lower edge. It shifts from a restrained compact curve to a generous expanded curve. Interior controls use compact continuous corners, while the send action and icon press states are circular. Hairlines stay at one point or below.

**The Screen-Edge Rule.** Never round, inset, or detach the panel's top edge; it must remain visually continuous with the display cutout.

## Components

### Notch Panel

- **Material:** Native ultra-thin material under the cool obsidian tint.
- **Edge:** One fine frosted perimeter stroke plus a shallow top glint.
- **States:** Compact is completely transparent and exactly overlays the physical notch; expanded reveals the working surface through a fast top-anchored scale-and-fade transition.
- **Motion:** Expansion uses a 340 ms snappy curve with almost no bounce. Collapse uses 260–280 ms and no bounce.

### Icon Buttons

- **Style:** SF Symbol only, secondary at rest, primary text color when pressed.
- **State:** Pressing introduces a circular raised-frost surface; there is no permanent button chrome.
- **Sizing:** Use compact 24-point targets in the working header and 26-point targets in the authentication header.

### Conversation Rows

- **Content:** Name and one-line preview only.
- **State:** Unread names become bold. Pressing reveals a quiet raised-frost rounded rectangle.
- **Density:** Maintain a fixed compact row height; do not add avatars, timestamps, unread-count pills, or secondary metadata.

### Messages

- **Incoming:** Thin native material, a hairline outline, Telegram-blue sender name, and primary text.
- **Outgoing:** Solid Telegram blue with dark sender and message text for contrast.
- **Content:** Sender and selectable message text, with a compact inline preview only when the Telegram message contains a photo or video. Opposing minimum insets preserve conversational direction.
- **Delivery:** A tiny status icon shares the sender line in outgoing bubbles: a check for “Sent”, changing to a filled check for “Read” from Telegram's live outbox read state. The words remain available to accessibility and pointer help without consuming another message line. Incoming bubbles omit delivery metadata.

### Media Viewer

- **Preview:** Media stays inside the existing message bubble at 174-by-104 points. Videos use the downloaded Telegram thumbnail and one centered play control; pending files show a quiet native progress indicator.
- **Viewer:** Selecting a preview replaces the working content with an in-panel glass viewer. Photos scale to fit; videos play through the native AVKit player. Escape and the close control return directly to the conversation, and video playback stops when the viewer closes.
- **Privacy:** Media never appears in the collapsed notch state and is not handed to an external application.

### Inputs

- **Search:** Thin material, magnifying-glass SF Symbol, hairline outline, and no decorative label.
- **Composer:** Thin material with a hairline outline, expanding from one to four lines.
- **Authentication:** Raised-frost fields with native focus behavior and slightly roomier density.

### Primary Actions

- **Authentication:** Full-width Telegram-blue button with dark type; unavailable actions reduce opacity.
- **Send:** Circular arrow-up control. It remains raised frost while disabled and turns Telegram blue only when a trimmed draft can be sent.

## Do's and Don'ts

### Do:

- **Do** preserve the physical notch as empty occlusion space.
- **Do** use native macOS materials, SF typography, SF Symbols, focus, keyboard, and accessibility behavior.
- **Do** reserve Telegram blue for meaningful action, unread state, links, sender emphasis, and outgoing messages.
- **Do** keep the working panel narrow, dense, and immediately dismissible.
- **Do** keep conversation rows and bubbles to name plus text.
- **Do** keep custom application artwork in the menu bar.

### Don't:

- **Don't** put contact avatars, timestamps, unread-count pills, reactions, decorative attachment chrome, or decorative metadata into the notch panel.
- **Don't** expose a name, preview, or exact unread count in the collapsed state.
- **Don't** replace true system glass with a flat dark rectangle, heavy gradient, or generic frosted-card treatment.
- **Don't** introduce multicolor chat accents, ornamental type, or custom illustrations inside this Operate surface.
- **Don't** detach the panel from the screen edge or round its top corners.
- **Don't** add bounce-heavy, slow, or attention-seeking motion.
