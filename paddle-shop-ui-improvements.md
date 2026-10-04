# Paddle Shop UI: Improvement Notes

Target platforms: **web (desktop)** and **mobile**.
Screen reviewed: Shop > Paddles tab (Night Shift selected, paddle 6 / 7).

Priority key: **P1** = fix first, **P2** = important polish, **P3** = nice to have.

---

## 1. Layout and Overlap

### 1.1 Detail panel collides with the carousel (P1)
The Night Shift detail panel sits on top of the Inferno X Pro card. Borders, stat bars, and the faded "+42% / +40%" text overlap and become unreadable.

- Give the panel a solid (or heavily blurred) opaque background.
- Or shift the carousel right / reduce the panel width so the two never overlap.
- On desktop, consider a clean two-column layout: details on the left, carousel on the right, with a fixed gutter between them.

### 1.2 Mobile layout needs its own structure (P1)
The current layout is a desktop-style side-by-side arrangement. It will not fit a ~380px viewport.

- Stack vertically: carousel on top, detail panel and CTA below.
- Pin the "Unlock" CTA to the bottom of the screen so it is always reachable with the thumb.
- Collapse the detail panel into a bottom sheet that expands on tap.
- Keep side cards partially visible (peek) to signal that the carousel is swipeable.

### 1.3 Responsive breakpoints (P2)
- Define at least three: mobile (< 600px), tablet (600 to 1024px), desktop (> 1024px).
- Use relative units and clamp() for card sizes so the carousel scales smoothly instead of jumping.
- Test landscape mobile separately; the top bar and panel will eat most of the height.

---

## 2. Information Hierarchy

### 2.1 Duplicate information (P1)
Name, rarity, and price appear in both the detail panel and the selected card.

- Let the **card** show only: art, name, and a small rarity tag.
- Let the **panel** show: description, stats, and the price (inside the CTA).
- Remove the separate "1200" price under the card; the button already says it.

### 2.2 Truncated description (P1)
The text cuts off mid-word ("...where you ai...").

- Allow 2 to 3 lines with wrapping, or truncate at a word boundary with a proper ellipsis.
- Add a "More" toggle if descriptions can be long.

### 2.3 Stat comparison (P2)
Stats are shown in isolation, so players cannot tell whether Night Shift is an upgrade over what they own.

- Show a small delta against the currently equipped paddle (e.g. "+6 PWR").
- Make the "+43%" style boosts clearly explained (boost from what? a perk? a level?). A tooltip or info icon would help.
- Keep stat order identical across every paddle so players can compare by position.

---

## 3. Typography and Contrast

### 3.1 Small, low-contrast text (P1)
Rarity labels on side cards, prices, the "PADDLE 6 / 7" caption, and the faded boost percentages are too small and too dim.

- Minimum body text 14px on web, 16px on mobile; minimum 12px for secondary labels.
- Meet WCAG AA contrast (4.5:1 for normal text) against the dark navy background.
- The purple-on-dark "EPIC" and "MYSTIC" tags and the dim green "+42%" are the worst offenders.

### 3.2 Number readability (P3)
- Use tabular (monospaced) numerals for stats, gems, and coins so values align and do not jitter when they change.
- Consider abbreviating large currency values (10.4K) if the pill gets crowded on mobile.

---

## 4. Product Presentation

### 4.1 Paddle art is too small (P1)
In a shop, the item is the hero. The center paddle has a lot of empty space, and the thumbnail in the panel is tiny and nearly black.

- Scale the selected paddle art up to fill most of the card.
- Add a subtle rarity-colored glow or spotlight behind it.
- Add a gentle idle animation (slow float or rotation) on the selected item.
- Replace the dark silhouette thumbnail in the panel with a properly lit render, or remove it since the card already shows the paddle.

### 4.2 Art consistency (P2)
- Make sure all paddle renders share the same angle, lighting, and scale so the carousel feels cohesive.
- Locked items could show a darkened version of the real art rather than a different treatment.

### 4.3 Preview (P3)
- Add a "Try" or "Preview" button that shows the paddle in action (a short animation or a test rally).
- Allow tapping the paddle to rotate or zoom.

---

## 5. Carousel Behavior and Navigation

### 5.1 Arrow affordance (P2)
The yellow chevrons sit on the side cards and read as card decoration, not carousel controls.

- Move them outside the cards, vertically centered on the carousel edges.
- Make them larger with a visible tap target (44x44px minimum).
- On mobile, rely on swipe and hide the arrows, or keep them subtle.

### 5.2 Input support (P1)
- **Mobile:** swipe with momentum and snap-to-card.
- **Desktop:** arrow keys, click on side cards to focus them, mouse drag, and scroll wheel.
- **Gamepad/keyboard:** visible focus ring on the active card.

### 5.3 Pagination indicator (P2)
- The "PADDLE 6 / 7" caption and the dots say the same thing. Pick one, or make the dots larger and tappable.
- The dots are tiny; enlarge them or replace them with a segmented bar.

### 5.4 Wrap-around and ordering (P3)
- Decide whether the carousel loops. If not, disable the chevron at the ends.
- Offer sorting or filtering (rarity, owned/unowned, price) once the paddle count grows.

---

## 6. States and Feedback

### 6.1 Lock state is ambiguous (P1)
The small padlock does not say why an item is locked.

- Define clear states: **Owned**, **Equipped**, **Locked (purchasable)**, **Locked (requirement)**.
- Show a visible label or badge, not only an icon.
- If an item is locked by a requirement (level, quest), say what it is on the card or panel.

### 6.2 Purchase flow (P1)
- Add a confirmation step for spending 1200 gems (modal or press-and-hold), especially on mobile where mis-taps are common.
- Show the resulting balance ("8161 > 6961") in the confirmation.
- Show a success animation and switch the CTA to "Equip".

### 6.3 Insufficient funds (P1)
- If the player cannot afford the item, the button should change (disabled style or "Get more gems") and link to Bank & Perks.
- Show how many gems are missing.

### 6.4 Loading, error, and empty states (P2)
- Skeleton cards while the shop loads.
- A clear error state with a retry button if a purchase fails.
- Handle the case where the network drops mid-purchase.

---

## 7. Visual Design and Consistency

### 7.1 Color and rarity system (P2)
- Epic and Mythic both read as purple in the screenshot, which weakens the rarity hierarchy. Give each tier a clearly distinct hue (for example: Common grey, Rare blue, Epic purple, Legendary gold, Mythic red or pink).
- Use the same colors for borders, tags, glows, and stat accents everywhere in the game.

### 7.2 Currency clarity (P2)
- Gold coin and gem icons are small and close in color to the surrounding pills. Increase icon size and contrast.
- Add a "+" affordance that is obviously tappable and leads to the store.

### 7.3 Spacing and alignment (P3)
- Standardize padding and corner radius across the panel, cards, and pills.
- Align the stat grid so labels and values line up in clean columns.
- Reduce the visual weight of the heavy glow borders; the panel and selected card both glow gold, which competes for attention.

### 7.4 Top navigation (P2)
- The tab bar (Paddles / Players / Bank & Perks) is good. Add a clear active-state indicator beyond color alone.
- On mobile, consider a bottom tab bar for thumb reach.

---

## 8. Accessibility

- Do not rely on color alone for rarity or stat meaning; pair color with text or icons.
- Add alt text / aria-labels for icon-only controls (chevrons, lock, gem).
- Support keyboard navigation and visible focus states on web.
- Respect reduced-motion settings: disable the idle float, glow pulse, and carousel easing.
- Ensure tap targets are at least 44x44px on mobile.
- Test with color-blind simulations, especially green boosts versus red bars.

---

## 9. Performance (Web and Mobile)

- Lazy-load paddle art for off-screen cards; preload only neighbors of the active card.
- Use compressed formats (WebP/AVIF) and sprite or atlas sheets for icons.
- Avoid heavy blur and box-shadow stacking on mobile; it hurts frame rate on low-end devices.
- Animate with transform and opacity only.

---

## 10. Suggested Order of Work

1. Fix panel/carousel overlap and build the mobile layout (1.1, 1.2).
2. Remove duplicated info and fix text truncation (2.1, 2.2).
3. Raise text size and contrast (3.1).
4. Enlarge paddle art (4.1).
5. Define lock/owned/equipped states and the purchase confirmation flow (6.1 to 6.3).
6. Improve carousel controls and input support (5.1, 5.2).
7. Polish: rarity colors, stat deltas, preview, accessibility, performance.

---

## Quick Checklist

- [ ] Panel no longer overlaps cards
- [ ] Mobile layout stacked, CTA pinned to bottom
- [ ] Name / rarity / price shown once
- [ ] Description wraps or truncates cleanly
- [ ] All text meets minimum size and contrast
- [ ] Paddle art enlarged with glow
- [ ] Clear Owned / Equipped / Locked states
- [ ] Purchase confirmation and insufficient-funds handling
- [ ] Larger chevrons, swipe and keyboard support
- [ ] Distinct rarity colors
- [ ] Reduced-motion and keyboard accessibility
