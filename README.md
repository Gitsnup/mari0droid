# mari0 (droid)
Mario + Portal platformer for Android. Runs on LÖVE 11.4.

Based on Maurice Guégan's Mari0, with touch controls for phones/tablets.

## Mobile controls

On Android/iOS the game shows an on-screen control layer:

- **D-pad** (left side) — move; hold **down** for pipes.
- **A** (right) — jump (release early for a shorter jump).
- **B** — run / shoot fireballs.
- **O** (blue) / **O** (orange) — shoot portal 1 / portal 2.
- **R** — remove portals. **E** — use (levers, doors...).
- **| |** (top right) — pause menu. The pause menu rows are tappable.
- The unoccupied right side of the screen is an aim surface: drag to aim the
  portal gun, quick tap to fire portal 1 at the tapped direction.
- The bottom half of the map screen is a virtual mouse for the level editor.

Touching a button never leaks a mouse click, so buttons don't fire portals or
click hidden menu items. Desktop builds are unaffected (keyboard/mouse only).

### Layout editing

Open **Options → Controls** and drag the buttons to rearrange them; release to
save. The layout persists in `mobilecontrols.txt` in the save directory.

### Testing

`_DO_NOT_INCLUDE/test_mobilecontrols.lua` is a dev-only stub harness that
exercises the control layer end-to-end without a device:

```
lua5.1 _DO_NOT_INCLUDE/test_mobilecontrols.lua
```

## Building

Uses [makelove](https://github.com/rameshvarun/makelove) (see `makelove.toml`)
for desktop targets; Android builds via the LÖVE 11.4 APK wrapper.

MIT License

## Mobile controls
On Android/iOS, on-screen touch controls are enabled automatically: a d-pad (left/right/down/up), jump (A), run/fire (B), portal gun buttons (blue/orange circles), portal reset (R), interact (E) and pause (||). The empty right side of the screen is an aim surface — drag to aim the portal gun, tap to shoot portal 1.

The layout can be customized: in **Options → Controls**, drag the buttons to move them, then release to save (stored in `mobilecontrols.txt` in the save directory).

Desktop (keyboard/mouse) behavior is unchanged; the touch layer only activates on Android/iOS.

## Development
`_DO_NOT_INCLUDE/test_mobilecontrols.lua` is a standalone harness that simulates an Android LÖVE environment and exercises the touch control module without a device:

```
lua5.1 _DO_NOT_INCLUDE/test_mobilecontrols.lua
```
