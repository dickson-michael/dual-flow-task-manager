# Dual Flow Task Manager (Icons + Text & Minimized Icons) for KDE Plasma 6

A custom KDE Plasma 6 task manager plasmoid that splits open and minimized windows across the panel with distinct presentation and flow:

- **Open Windows (Left Side)**: Displayed from **left to right** with **Icons + Text labels**, indicating active/focused state with Breeze task styling.
- **Center Elastic Spacer**: Dynamically pushes minimized tasks to the far right edge of the panel (or configurable).
- **Minimized Windows (Right Side)**: Displayed from **right to left** with compact **Icons only**, featuring subtle minimized indicators and rich hover tooltips.

---

## Features

1. **Dual-Model Separation & Grouping Control**:
   - Uses native `org.kde.taskmanager` with two separate `TasksModel` filters:
     - `filterMinimized: true` for open windows.
     - `filterNotMinimized: true` for minimized windows.
   - **Four Open Window Grouping Options**:
     1. **`No grouping`**: Every window gets its own dedicated button on the panel with its own icon and title.
     2. **`Compact window list (textual list popup)`**: Clicking a grouped app opens a clean compact list popup showing all windows with icons, full titles, active indicators, and individual close (`X`) buttons.
     3. **`Present Windows / Exposé effect`**: Clicking a grouped app directly triggers KWin's built-in Present Windows (Exposé) grid (`org.kde.KWin.Effect.WindowView1`) for that application's windows.
     4. **`Bring application to foreground`**: Clicking brings all windows of that application to the front, and cycles focus between them on repeated clicks.
   - **Ungrouped Minimized Windows (macOS Style)**:
     - Minimized windows **always remain ungrouped** as individual icons on the right side, regardless of grouping settings.
   - When a window is minimized, it smoothly transitions from the left-side text list to the right-side icon dock.
   - When clicked on the right side, it unminimizes/activates and immediately returns to the left-side open list.

2. **KWin Minimize/Restore Geometry**:
   - Publishes window geometry coordinates to KWin via `requestPublishDelegateGeometry()`.
   - Minimize animations fly directly to and from their respective delegate buttons!

3. **Rich Task Context Menu**:
   - Right-click menu with:
     - Restore / Minimize
     - Maximize / Restore
     - Move to Virtual Desktop (with dynamic desktop listing)
     - Bring All to Foreground / Minimize All (for groups)
     - Close window / Close All Windows

4. **Configurable Behavior & Appearance**:
   - Open window grouping strategy selector (No grouping, Compact list, Exposé, Bring to front).
   - Push minimized windows to right edge (toggle on/off).
   - Minimized window flow direction (right-to-left toggle).
   - Min / Max task button width for open windows.
   - Dim minimized icons until hovered.
   - Filter by current screen / virtual desktop / activity.
   - Configurable middle-click action (Close window, Toggle minimize, New instance).

---

## Installation & Adding to Panel

The widget is installed in:
`~/.local/share/plasma/plasmoids/org.kde.plasma.splitflowtasks`

### How to Add:
1. Right-click on your KDE Plasma panel and select **"Enter Edit Mode"** (or press `Meta+Alt+D`).
2. Click **"Add Widgets..."**.
3. Search for **"Dual Flow Task Manager"**.
4. Drag it onto your panel (or replace the existing task manager).
5. Open windows will appear on the left (Icons + Text) and minimized windows will appear on the right (Icons only).

### Reloading Plasma Shell:
```bash
plasmashell --replace &
```
