# mari0
Runs on LÖVE 11.4

MIT License

## Mobile controls (Android/iOS)

On touch devices, player 1 is controlled with on-screen buttons (`mobilecontrols.lua`,
required from `main.lua` before `love.load`):

- `<` `>` `v` `^` — move (held = continuous movement)
- `A` — jump (release early for a short hop)
- `B` — run / fire
- `O` (blue, orange) — shoot portal 1 / portal 2
- `R` — remove portals, `E` — use, `||` — pause
- The unoccupied right side of the screen is an aim surface: drag to aim the
  portal gun, tap to shoot portal 1 in that direction.

In **Options → Controls**, the buttons can be dragged to any position; releasing
saves the layout to `mobilecontrols.txt` in the save directory. Overlapping
buttons still work: a touch activates the nearest one.

Desktop is unaffected: keyboard/mouse controls and the stock menu behavior are
only wrapped on Android/iOS (`love.system.getOS()`).

### Touch quirks handled

- Android synthesizes mouse events from touches; events that land on a control
  button (or the left zone) are swallowed so buttons don't fire portals or
  click hidden GUI. Taps in the aim area pass through on purpose.
- The keyboard-only pause menu is tappable: tap a row to select it, tap again
  to activate (prompts: tap left/right for yes/no).
- Gameplay globals (`checkkey`, `defaultconfig`, `mario.updateangle`) are
  wrapped inside the `love.load` hook, after `main.lua` requires its files.

### Dev test harness

`_DO_NOT_INCLUDE/test_mobilecontrols.lua` stubs the LÖVE API and runs ~28
checks (bindings, held keys, pause handling, mouse-swallow rules, layout
save/reload) without a device:

```sh
lua5.1 _DO_NOT_INCLUDE/test_mobilecontrols.lua
```
