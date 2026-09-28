-- Clean stub harness: simulates an Android LÖVE environment around mobilecontrols.lua
local out, failures = {}, 0
local function expect(name, cond)
	if not cond then failures = failures + 1 end
	out[#out+1] = (cond and "PASS " or "FAIL ") .. name
end

local savedata = nil
love = {  -- the love table (V avoids clashing with anything)
	graphics = {
		getWidth = function() return 800 end,
		getHeight = function() return 480 end,
		circle = function() end, printf = function() end,
		setColor = function() end, print = function() end,
	},
	filesystem = {
		write = function(_, d) savedata = d end,
		read = function() return savedata end,
		getInfo = function() return savedata ~= nil end,
		setIdentity = function() end,
		getSaveDirectory = function() return "/tmp" end,
	},
	system = { getOS = function() return "Android" end },
	audio = { pause = function() end },
}

gamestate, optionstab = "game", 1
pausemenuopen, menuprompt, desktopprompt, suspendprompt = nil, false, false, false
everyonedead, endpressbutton, playertype = false, false, "portal"
xscroll, scale, width = 0, 1.15, 25
mouseowner, pausemenuselected = 1, 3
pausesound = {}
pausemenuoptions = { "resume", "suspend", "volume", "", "" }
pausemenuoptions2 = { "", "", "", "menu", "desktop" }

gamekeys = {}
function playmusic() end
function playsound() end
function shootportal(pl, i, x, y, d) gamekeys[#gamekeys+1] = "portal" .. i end
function endgame() gamekeys[#gamekeys+1] = "endgame" end
function game_keypressed(key)
	gamekeys[#gamekeys+1] = key
	if pausemenuopen and key == "return" and pausemenuoptions[pausemenuselected] == "resume" then
		pausemenuopen = false
	end
end

local fired = {}
local p = {
	x = 4, y = 8, pointingangle = -1.57, playernumber = 1,
	jump = function() fired[#fired+1] = "jump" end,
	stopjump = function() fired[#fired+1] = "stopjump" end,
	fire = function() fired[#fired+1] = "fire" end,
	removeportals = function() fired[#fired+1] = "removeportals" end,
	use = function() fired[#fired+1] = "use" end,
}
objects = { player = { p } }

checkkey = function(s) return false end  -- game.lua's keyboard/joy branch
defaultconfig = function()
	controls = {{ right={"d"}, left={"a"}, down={"s"}, up={"w"}, run={"lshift"},
		jump={"space"}, aimx={""}, aimy={""}, portal1={""}, portal2={""}, reload={"r"}, use={"e"} }}
	mouseowner = 1
end
mario = { updateangle = function(self) self.pointingangle = 0.01 end }
setmetatable(p, { __index = mario })

-- Menu state the tap translation talks to. menu_keypressed is the game's own
-- keyboard handler, so the harness records what a tap translated into.
menu_log = {}
selection = 1
continueavailable = false
players = 1
function menu_keypressed(key)
	menu_log[#menu_log+1] = key
	-- Mirror menu.lua's real navigation, so the tap translation is exercised
	-- against the game's actual clamping instead of a stub that moves selection
	-- freely. menu_keypressed clamps "up" at 1 when there is no suspend file and
	-- "down" at 4; a walk that ignores that must fail here.
	if key == "up" then
		local floor = continueavailable and 0 or 1
		if selection > floor then selection = selection - 1 end
	elseif key == "down" then
		if selection < 4 then selection = selection + 1 end
	end
end
-- Mirrors menu.lua's menu_load: enter the menu in a known state. It resets
-- continueavailable from the suspend file, so tests that need it set must do so
-- AFTER calling this.
function menu_load()
	gamestate = "menu"
	selection = 1
	players = 1
	continueavailable = false
end

-- The game's font: properprint draws fontquads[char] scaled by the global
-- `scale`, and fontquads is keyed by every character in fontglyphs. This is the
-- ground truth for "can a label actually be drawn".
fontglyphs = "0123456789abcdefghijklmnopqrstuvwxyz.:/,'C-_>* !{}?"
fontquads = {}
for i = 1, string.len(fontglyphs) do
	fontquads[string.sub(fontglyphs, i, i)] = true
end
-- Record what a label would actually draw. A character missing from fontquads
-- produces NO quad, i.e. nothing rendered -- the blank-circle bug.
drawn_glyphs = {}
function properprint(str, x, y)
	str = tostring(str)
	drawn_glyphs[#drawn_glyphs+1] = str
	for i = 1, string.len(str) do
		local c = string.sub(str, i, i)
		if not fontquads[c] then
			undrawable[#undrawable+1] = c
		end
	end
end
undrawable = {}
love.graphics.print = function() end
love.graphics.printf = function() end
love.graphics.circle = function() end
love.graphics.setColor = function() end
love.graphics.rectangle = function() end

-- The real main.lua requires mobilecontrols BEFORE defining love.load, so the
-- assignment hook catches it. Mirror that ordering here.
rawchangescale = function(s, fullscreen)
	scale = s
	uispace = math.floor(width*16*scale/4)
	gamewidth, gameheight = love.graphics.getWidth(), love.graphics.getHeight()
end
changescale = rawchangescale

-- Every module load goes through boot_module(). Two ordering rules matter:
--   1. clear any handler left by a previous boot, or the key exists and the
--      module's __newindex wrap hook never fires again;
--   2. load the module FIRST so it installs the metatable, THEN assign the
--      handler, because the wrap only applies to an assignment made after the
--      metatable exists.
-- Screen centre of a named control, read from the module's own layout. Keeps
-- the touch tests from silently pointing at wherever a button USED to be.
local function btn(name)
	local b = __mobilecontrols.controls[name]
	local gw, gh = love.graphics.getWidth(), love.graphics.getHeight()
	return b.x * gw, b.y * gh
end

local function boot_module()
	love.mousepressed = nil
	love.mousereleased = nil
	dofile("mobilecontrols.lua")
	love.mousepressed = function(x, y, b, it) mouse_log = (mouse_log or 0) + 1 end
	love.mousereleased = function(x, y, b, it) mouse_log = (mouse_log or 0) + 1 end
end


boot_module()

local load_ran = false
function love.load() load_ran = true; defaultconfig() end
love.load()
expect("load-ran", load_ran)
expect("touch-bindings", controls[1]["left"][1] == "touch" and controls[1]["left"][2] == "left"
	and controls[1]["up"][2] == "up" and controls[1]["portal2"][2] == "portal2")
expect("desktop-keyboard-untouched", controls[1]["aimx"][1] == "")

-- 1. movement buttons poll through checkkey
love.touchpressed(1, btn("left"))
expect("held-left", checkkey({"touch", "left"}) == true)
love.touchreleased(1, btn("left"))
expect("released-left", checkkey({"touch", "left"}) == false)

-- 2. action buttons fire player methods
love.touchpressed(2, btn("jump"))
expect("jump-held", checkkey({"touch", "jump"}) == true)
love.touchreleased(2, btn("jump"))
expect("jump-taps-jump+stopjump", fired[1] == "jump" and fired[2] == "stopjump")
love.touchpressed(3, btn("run")); love.touchreleased(3, btn("run"))
love.touchpressed(4, btn("reload")); love.touchreleased(4, btn("reload"))
love.touchpressed(5, btn("use")); love.touchreleased(5, btn("use"))
love.touchpressed(6, btn("portal1")); love.touchreleased(6, btn("portal1"))
love.touchpressed(7, btn("portal2")); love.touchreleased(7, btn("portal2"))
expect("run-reload-use-portal12", fired[3] == "fire" and fired[4] == "removeportals"
	and fired[5] == "use" and gamekeys[1] == "portal1" and gamekeys[2] == "portal2")

-- 3. aim surface: press aims immediately, dragging follows, updateangle uses it
love.touchpressed(8, 700, 460)
expect("aim-press-rotates-gun", p.pointingangle ~= -1.57 and p.pointingangle ~= 0.01)
local after_press = p.pointingangle
love.touchmoved(8, 760, 300)
p:updateangle()
expect("aim-move-follows-finger", p.pointingangle ~= after_press and p.pointingangle ~= 0.01)
love.touchreleased(8, 760, 300)

-- 4. pause: opens on release, closes on second release
love.touchpressed(9, btn("pause"))
expect("pause-not-yet", pausemenuopen ~= true)
love.touchreleased(9, btn("pause"))
expect("pause-open", pausemenuopen == true)
love.touchpressed(9, btn("pause"))
love.touchreleased(9, btn("pause"))
expect("pause-close", pausemenuopen == false)

-- 5. gameplay actions ignored while paused (except the pause button)
love.touchpressed(9, btn("pause")); love.touchreleased(9, btn("pause")) -- open
local nfired = #fired
love.touchpressed(10, btn("jump"))
expect("paused-jump-held-but-ignored", checkkey({"touch","jump"}) == true and #fired == nfired)
love.touchreleased(10, btn("jump"))
expect("paused-no-stopjump", #fired == nfired)
love.touchpressed(9, btn("pause")); love.touchreleased(9, btn("pause")) -- close
expect("unpaused", pausemenuopen == false)

-- 6. end-of-level: a button press advances instead of acting
endpressbutton = true
love.touchpressed(11, btn("jump"))
expect("endpressbutton-advances", gamekeys[#gamekeys] == "endgame" and endpressbutton == false)

-- 7. pause menu rows: first tap selects, second tap activates
gamestate = "game"
love.touchpressed(12, btn("pause")); love.touchreleased(12, btn("pause")) -- open
pausemenuselected = 2
-- The panel is centred in the window, so its drawn centre is
-- (gw - w*16*scale)/2 + (w*8)*scale, which is only w*8*scale when the drawn
-- width happens to equal the window width. Keep the two axes separate: a single
-- `local a = x, y` keeps only x and silently reuses it on the y axis.
local pgw, pgh = love.graphics.getWidth(), love.graphics.getHeight()
local pspx, pspy = (pgw - width*16*scale)/2, (pgh - 224*scale)/2
local cx = pspx + (width*8)*scale
local row1y = pspy + (112*scale) - 60*scale + 6*scale  -- inside row 1's band
mouse_log = 0
love.mousepressed(cx, row1y, 1, true)
expect("pause-row-select", pausemenuselected == 1)
love.mousepressed(cx, row1y, 1, true)
expect("pause-row-resume", pausemenuopen ~= true)
-- a tap outside the box must not select a row that isn't drawn there
pausemenuopen = true
pausemenuselected = 3
love.mousepressed(cx, pspy - 100, 1, true)
expect("pause-tap-outside-box", pausemenuselected == 3)
pausemenuopen = nil

-- 8. synthetic mouse: swallowed on controls + left zone, allowed in aim zone
mouse_log = 0
love.touchpressed(13, 80, 393)   -- finger lands on the left button
love.mousepressed(80, 393, 1, true)
expect("swallow-press-on-control", mouse_log == 0)
love.mousereleased(80, 393, 1, true)
expect("swallow-release-on-control", mouse_log == 0)
love.touchreleased(13, 80, 393)
love.mousepressed(100, 100, 1, true)
expect("swallow-left-zone", mouse_log == 0)
love.mousepressed(700, 460, 1, true)
expect("pass-aim-zone-tap", mouse_log == 1)
love.mousepressed(700, 460, 1, false)
expect("pass-desktop-mouse", mouse_log == 2)

-- 9. layout editing: drag the left button in options, release saves
gamestate = "options"; optionstab = 1
local oldgx, oldgy = btn("left")
local GW_, GH_ = love.graphics.getWidth(), love.graphics.getHeight()
local newgx, newgy = 0.25 * GW_, 0.90 * GH_
love.touchpressed(14, oldgx, oldgy)
love.touchmoved(14, newgx, newgy)
love.touchreleased(14, newgx, newgy)
-- the module trims trailing zeros, so assert on the parsed value, not the text
local want = string.format("left=%s,%s", tostring(newgx/GW_), tostring(newgy/GH_))
expect("editing-stopped", savedata ~= nil and savedata:find(want, 1, true) ~= nil)

-- 10. fresh module boot loads the saved layout
boot_module()
love.load = nil  -- __newindex only fires for NEW keys: clear first
love.load = function() end  -- re-triggers the load wrapper
love.load()
gamestate = "game"; optionstab = 1
love.touchpressed(15, oldgx, oldgy)  -- old position: nothing there anymore
expect("old-spot-empty", checkkey({"touch", "left"}) == false)
love.touchreleased(15, oldgx, oldgy)
local mgx, mgy = btn("left")  -- the reloaded layout's position
love.touchpressed(16, mgx, mgy)
expect("layout-reloaded", checkkey({"touch", "left"}) == true)
love.touchreleased(16, mgx, mgy)

-- 11. stuck held keys clear when leaving the game state
love.touchpressed(17, btn("left"))
gamestate = "menu"
love.draw = function() end
love.draw()  -- the draw wrapper runs draw_controls internally
expect("held-cleared-on-state-change", checkkey({"touch", "left"}) == false)

-- 12c. every button label must be drawable by the game's own font.
--
-- The atlas (graphics/SMB/font.png, 64 cells) is addressed by main.lua's
-- fontglyphs string: digits, LOWERCASE a-z, then .:/,'C-_>* !{}?. It has no
-- uppercase letters, no "<" and no "^". A character outside the set has no quad
-- and draws NOTHING, which is what put blank circles on the controls before.
drawlabel_for_test = nil
undrawable = {}
-- Render each label through the production draw path.
for name in pairs(__mobilecontrols.controls) do
	local b = __mobilecontrols.controls[name]
	if b.label then
		properprint(b.label, 0, 0)
	end
end
expect("labels-all-drawable", #undrawable == 0)
if #undrawable > 0 then
	io.write("  undrawable chars: " .. table.concat(undrawable, " ") .. "\n")
end

-- Direct check of the glyph set, independent of the draw path, so a future
-- label cannot slip through by never being drawn.
local BAD = {}
for name, b in pairs(__mobilecontrols.controls) do
	if b.label then
		for i = 1, string.len(b.label) do
			local c = string.sub(b.label, i, i)
			if not fontquads[c] then BAD[#BAD+1] = name .. ":" .. c end
		end
	end
end
expect("labels-in-glyph-set", #BAD == 0)
if #BAD > 0 then io.write("  bad: " .. table.concat(BAD, " ") .. "\n") end

-- And the D-pad must read as a cross: up above down on the same x, left and
-- right flanking them on a shared y, all four centred on one point.
--
-- This must inspect the DEFAULT layout. An earlier test drags `left` and saves
-- it, so reading the live table here would test a mutated layout instead.
-- Read the SHIPPED layout from the module, not a copy. A hardcoded table here
-- would pass no matter what the source did, which is the flaw this suite keeps
-- running into.
local DC = __mobilecontrols.defaultcontrols
expect("default-controls-exposed", DC ~= nil)
if not DC then
	print(table.concat(out, "\n")); print("---"); print("ABORTED: defaultcontrols missing"); os.exit(1)
end
local D = {
	up    = DC.up,
	down  = DC.down,
	left  = DC.left,
	right = DC.right,
}
expect("dpad-up-above-down", D.up.y < D.down.y and math.abs(D.up.x - D.down.x) < 0.02)
expect("dpad-left-right-flank", D.left.x < D.right.x and math.abs(D.left.y - D.right.y) < 0.02)
expect("dpad-cross-centred",
	math.abs((D.left.x + D.right.x)/2 - D.up.x) < 0.03
	and math.abs((D.up.y + D.down.y)/2 - D.left.y) < 0.03)

-- The arms must not overlap, or a tap between two directions picks one at
-- random. Measure in units of the button size (which is in screen px) rather
-- than raw pixels, so this holds at any window size the suite runs at.
do
	local GW_, GH_ = love.graphics.getWidth(), love.graphics.getHeight()
	local size = __mobilecontrols.controls.up.w
	local gapx = math.abs(D.left.x - D.right.x) * GW_
	local gapy = math.abs(D.up.y - D.down.y) * GH_
	expect("dpad-arms-do-not-overlap", gapx >= size and gapy >= size)
end

-- 12d. labels must be big enough to read and small enough to stay inside the
-- button. A 3-glyph word in a 52px circle works out to scale 1 (8px) if the
-- size is unclamped, which is unreadable on a phone.
do
	local C = __mobilecontrols.defaultcontrols
	-- Test at a REAL device height, with the size the button will actually be
	-- drawn at. Asserting at the harness's 480px window would demand legibility
	-- at a resolution no phone has, and would flag a button that is fine on device.
	local RH = 1080
	local ref = 480
	for name, b in pairs(C) do
		if b.label then
			local n = string.len(b.label)
			local px = b.w * (RH / ref)          -- drawn size on a 1080-tall screen
			local sz = math.floor(px * 0.72 / (8 * n))
			if sz < 2 then sz = 2 end
			if sz > 4 then sz = 4 end
			while n * 8 * sz > px - 4 and sz > 1 do sz = sz - 1 end
			expect("label-fits-" .. name, n * 8 * sz <= px - 4)
			expect("label-readable-" .. name, sz >= 2)
		end
	end
end

-- 12e. no two controls may overlap at a real device resolution. The buttons
-- scale with screen height while their positions are fractions, so a layout that
-- is fine at 480px can collapse into a blob on a phone. This is exactly how the
-- d-pad shipped overlapping: it was only ever checked at the harness size.
do
	local C = __mobilecontrols.defaultcontrols
	local W_, H_ = 2340, 1080
	local ref = 480
	-- The controls are drawn as CIRCLES, so test circle separation. Comparing
	-- bounding boxes flags diagonal neighbours as colliding when the discs are
	-- comfortably apart.
	local discs = {}
	local names = {}
	for name, b in pairs(C) do
		local rad = b.w * (H_ / ref) / 2
		discs[name] = {b.x * W_, b.y * H_, rad}
		names[#names+1] = name
	end
	table.sort(names)
	for i = 1, #names do
		for j = i+1, #names do
			local A, B = discs[names[i]], discs[names[j]]
			local dx, dy = A[1] - B[1], A[2] - B[2]
			local d = math.sqrt(dx*dx + dy*dy)
			local gap = d - (A[3] + B[3])
			-- Assert a USABLE gap, not just non-intersection. The shipped d-pad
			-- cleared by 4.7px, which is geometrically "not overlapping" and
			-- visually one blob. 15px is the floor at which two discs read as
			-- separate at a glance.
			expect("gap-" .. names[i] .. "-" .. names[j], gap >= 15)
		end
	end
end

-- 13. menu taps: a tap selects the row under the finger and confirms it
--
-- Coordinates are derived from the module's OWN band table (S.menu_rows) rather
-- than hardcoded, so a band that moves in mobilecontrols.lua cannot silently
-- desync the test. That is exactly how the earlier hardcoded copy went wrong.
local MR = __mobilecontrols.menu_rows
expect("menu-rows-exposed", MR ~= nil)
if not MR then
	MR = {{123,138},{139,154},{155,170},{171,186},{187,202}}
end
-- Screen y of a row's centre: panel vertically centred, rows drawn one
-- scale-unit low inside their translate.
local function tap_y(band, gh, sc)
	return (gh - 224*sc)/2 + ((band[1] + band[2]) / 2) * sc
end

scale, width = 2, 25
local GW, GH = love.graphics.getWidth(), love.graphics.getHeight()

-- With no suspend file, band 1 ("continue game") is not drawn, so band i maps
-- to selection i-1. Every real band must hit its own row.
menu_load()
for i = 2, #MR do
	selection = 1
	menu_log = {}
	love.mousepressed(160, tap_y(MR[i], GH, scale), 1, true)
	expect("menutap-band" .. i .. "-selects", selection == i - 1)
	expect("menutap-band" .. i .. "-confirms", menu_log[#menu_log] == "return")
end

-- the undrawn band 1 must fall through rather than select something
menu_load()
selection = 1
menu_log = {}
love.mousepressed(160, tap_y(MR[1], GH, scale), 1, true)
expect("menutap-absent-continue-falls-through", selection == 1 and #menu_log == 0)

-- a tap above the rows does nothing
menu_log = {}
love.mousepressed(160, tap_y(MR[1], GH, scale) - 40, 1, true)
expect("menutap-ignores-gap", #menu_log == 0)

-- with a suspend file, band i maps to selection i-1 (band 1 is selection 0)
continueavailable = true
menu_load()
continueavailable = true
for i = 1, #MR do
	selection = 4
	menu_log = {}
	love.mousepressed(160, tap_y(MR[i], GH, scale), 1, true)
	expect("menutap-suspend-band" .. i .. "-selects", selection == i - 1)
end
menu_load()

-- letterboxed: same gui band, offset by the window. 720x480 at scale 1 draws a
-- 400-wide panel starting at x 160.
scale, width = 1, 25
love.graphics.getWidth = function() return 720 end
love.graphics.getHeight = function() return 480 end
menu_load()
selection = 1
menu_log = {}
love.mousepressed(160 + 200, tap_y(MR[5], 480, 1), 1, true)
expect("menutap-letterboxed-row", selection == 4 and menu_log[#menu_log] == "return")
love.graphics.getWidth = function() return 800 end
love.graphics.getHeight = function() return 480 end

-- high-dpi: the row must be found at its drawn position, not at y/scale. On a
-- 1080-tall window the old y/scale maths landed roughly 2.7x off.
love.graphics.getWidth = function() return 2400 end
love.graphics.getHeight = function() return 1080 end
scale, width = 1080/224, 25
menu_load()
selection = 1
menu_log = {}
love.mousepressed(160, tap_y(MR[5], 1080, scale), 1, true)
expect("menutap-highdpi-row", selection == 4 and menu_log[#menu_log] == "return")
love.graphics.getWidth = function() return 800 end
love.graphics.getHeight = function() return 480 end
scale, width = 2, 25
menu_load()

-- a desktop mouse click must not be translated into key presses
love.system.getOS = function() return "Linux" end
playertype, mario = playertype, mario
boot_module()
love.load = nil
love.load = function() end
love.load()
gamestate = "menu"
selection = 3
menu_log = {}
love.mousepressed(160, 160*scale, 1, false)
expect("menutap-desktop-passthrough", #menu_log == 0)
love.system.getOS = function() return "Android" end
boot_module()
love.load = nil
love.load = function() end
love.load()
gamestate = "game"

--- 12b. mobile scale: driven by the screen height alone
---
--- The level scrolls, so the playfield's full width never has to fit on screen
--- and there is no width cap. scale is h/224, deliberately NOT floored, so the
--- playfield fills the height exactly instead of leaving dead space.
--- (harness boots as Android, so the module is already in mobile mode)
scale = 2; uispace = 100; gamewidth, gameheight = 800, 448
love.graphics.getWidth = function() return 2400 end
love.graphics.getHeight = function() return 1080 end
changescale(2)
expect("mobile-scale-fills-height", math.abs(scale*224 - 1080) < 0.001)
expect("mobile-scale-is-fractional", scale > 4)
expect("mobile-uispace", uispace == math.floor(width*16*scale/4))

-- His phone, the case in the screenshot. Pre-fix this floored to 4 and drew an
-- 896px playfield in a 1080px window: 17% of the screen left empty.
love.graphics.getWidth = function() return 2340 end
love.graphics.getHeight = function() return 1080 end
changescale(2)
expect("mobile-phone-fills-height", math.abs(scale*224 - 1080) < 0.001)
expect("mobile-phone-not-floored", scale > 4)

-- Portrait phone: still purely height-driven.
love.graphics.getWidth = function() return 720 end
love.graphics.getHeight = function() return 1280 end
changescale(2)
expect("mobile-portrait-fills-height", math.abs(scale*224 - 1280) < 0.001)

-- Landscape tablet.
love.graphics.getWidth = function() return 1600 end
love.graphics.getHeight = function() return 900 end
changescale(2)
expect("mobile-tablet-fills-height", math.abs(scale*224 - 900) < 0.001)

-- A tiny screen must never yield a sub-1 scale.
love.graphics.getWidth = function() return 320 end
love.graphics.getHeight = function() return 200 end
changescale(2)
expect("mobile-tiny-screen-floor", scale == 1)

love.graphics.getWidth = function() return 800 end
love.graphics.getHeight = function() return 480 end
-- desktop: fresh boot with a desktop OS; changescale passes through untouched
love.system.getOS = function() return "Linux" end
boot_module()
love.load = function() end
love.load()
love.graphics.getWidth = function() return 800 end
love.graphics.getHeight = function() return 448 end
changescale(2)
expect("desktop-scale-passthrough", scale == 2 and gameheight == 448)

print(table.concat(out, "\n"))
print("---")
print(failures .. " failed")
