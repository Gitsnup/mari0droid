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
love.touchpressed(1, 80, 393)
expect("held-left", checkkey({"touch", "left"}) == true)
love.touchreleased(1, 80, 393)
expect("released-left", checkkey({"touch", "left"}) == false)

-- 2. action buttons fire player methods
love.touchpressed(2, 800*0.78, 480*0.78)
expect("jump-held", checkkey({"touch", "jump"}) == true)
love.touchreleased(2, 800*0.78, 480*0.78)
expect("jump-taps-jump+stopjump", fired[1] == "jump" and fired[2] == "stopjump")
love.touchpressed(3, 800*0.90, 480*0.68); love.touchreleased(3, 800*0.90, 480*0.68)
love.touchpressed(4, 800*0.08, 480*0.62); love.touchreleased(4, 800*0.08, 480*0.62)
love.touchpressed(5, 800*0.28, 480*0.67); love.touchreleased(5, 800*0.28, 480*0.67)
love.touchpressed(6, 800*0.78, 480*0.58); love.touchreleased(6, 800*0.78, 480*0.58)
love.touchpressed(7, 800*0.90, 480*0.54); love.touchreleased(7, 800*0.90, 480*0.54)
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
love.touchpressed(9, 800*0.95, 480*0.10)
expect("pause-not-yet", pausemenuopen ~= true)
love.touchreleased(9, 800*0.95, 480*0.10)
expect("pause-open", pausemenuopen == true)
love.touchpressed(9, 800*0.95, 480*0.10)
love.touchreleased(9, 800*0.95, 480*0.10)
expect("pause-close", pausemenuopen == false)

-- 5. gameplay actions ignored while paused (except the pause button)
love.touchpressed(9, 800*0.95, 480*0.10); love.touchreleased(9, 800*0.95, 480*0.10) -- open
local nfired = #fired
love.touchpressed(10, 800*0.78, 480*0.78)
expect("paused-jump-held-but-ignored", checkkey({"touch","jump"}) == true and #fired == nfired)
love.touchreleased(10, 800*0.78, 480*0.78)
expect("paused-no-stopjump", #fired == nfired)
love.touchpressed(9, 800*0.95, 480*0.10); love.touchreleased(9, 800*0.95, 480*0.10) -- close
expect("unpaused", pausemenuopen == false)

-- 6. end-of-level: a button press advances instead of acting
endpressbutton = true
love.touchpressed(11, 800*0.78, 480*0.78)
expect("endpressbutton-advances", gamekeys[#gamekeys] == "endgame" and endpressbutton == false)

-- 7. pause menu rows: first tap selects, second tap activates
gamestate = "game"
love.touchpressed(12, 800*0.95, 480*0.10); love.touchreleased(12, 800*0.95, 480*0.10) -- open
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
love.touchpressed(14, 80, 393)
love.touchmoved(14, 200, 400)
love.touchreleased(14, 200, 400)
expect("editing-stopped", savedata ~= nil and savedata:match("left=0%.25,0%.8333") ~= nil)

-- 10. fresh module boot loads the saved layout
boot_module()
love.load = nil  -- __newindex only fires for NEW keys: clear first
love.load = function() end  -- re-triggers the load wrapper
love.load()
gamestate = "game"; optionstab = 1
love.touchpressed(15, 80, 393)  -- old position: nothing there anymore
expect("old-spot-empty", checkkey({"touch", "left"}) == false)
love.touchreleased(15, 80, 393)
love.touchpressed(16, 230, 420)  -- moved position: button found (non-overlapping probe)
expect("layout-reloaded", checkkey({"touch", "left"}) == true)
love.touchreleased(16, 230, 420)

-- 11. stuck held keys clear when leaving the game state
love.touchpressed(17, 200, 400)
gamestate = "menu"
love.draw = function() end
love.draw()  -- the draw wrapper runs draw_controls internally
expect("held-cleared-on-state-change", checkkey({"touch", "left"}) == false)

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
