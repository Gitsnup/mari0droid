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
function menu_keypressed(key)
	menu_log[#menu_log+1] = key
end

-- The real main.lua requires mobilecontrols BEFORE defining love.load, so the
-- assignment hook catches it. Mirror that ordering here.
rawchangescale = function(s, fullscreen)
	scale = s
	uispace = math.floor(width*16*scale/4)
	gamewidth, gameheight = love.graphics.getWidth(), love.graphics.getHeight()
end
changescale = rawchangescale

dofile("mobilecontrols.lua")

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
local sc, cx = scale, width*8*scale
local row1y = (112*scale - 60*scale)
-- synthesized mouse stubs (hook wraps them as they're assigned)
love.mousepressed = function(x, y, b, it) mouse_log = (mouse_log or 0) + 1 end
love.mousereleased = function(x, y, b, it) mouse_log = (mouse_log or 0) + 1 end
mouse_log = 0
love.mousepressed(cx, row1y, 1, true)
expect("pause-row-select", pausemenuselected == 1)
love.mousepressed(cx, row1y, 1, true)
expect("pause-row-resume", pausemenuopen ~= true)

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
dofile("mobilecontrols.lua")
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
gamestate = "menu"
scale, width = 2, 25
continueavailable = false
menu_log = {}
-- row 2 ("level editor") spans gui y 149..175, so 160*scale is inside it
love.mousepressed(160, 160*scale, 1, true)
expect("menutap-selects-row", selection == 2)
expect("menutap-confirms", menu_log[1] == "return" and #menu_log == 1)

-- a tap in the gap between the title and the rows does nothing
menu_log = {}
love.mousepressed(160, 110*scale, 1, true)
expect("menutap-ignores-gap", #menu_log == 0)

-- with a suspend file present every row shifts down by one
continueavailable = true
selection = 1
menu_log = {}
love.mousepressed(160, 160*scale, 1, true)
expect("menutap-continue-shift", selection == 1 and menu_log[1] == "return")

-- a desktop mouse click must not be translated into key presses
love.system.getOS = function() return "Linux" end
playertype, mario = playertype, mario
dofile("mobilecontrols.lua")
love.load = nil
love.load = function() end
love.load()
gamestate = "menu"
selection = 3
menu_log = {}
love.mousepressed(160, 160*scale, 1, false)
expect("menutap-desktop-passthrough", #menu_log == 0)
love.system.getOS = function() return "Android" end
dofile("mobilecontrols.lua")
love.load = nil
love.load = function() end
love.load()
gamestate = "game"

--- 12b. mobile scale: fits BOTH the height and the width of the screen
--- (harness boots as Android, so the module is already in mobile mode)
scale = 2; uispace = 100; gamewidth, gameheight = 800, 448
love.graphics.getWidth = function() return 2400 end
love.graphics.getHeight = function() return 1080 end
changescale(2)
-- 2400x1080 would let 4x fill the height, but 4*400 = 1600 <= 2400 so width
-- also allows it; the full 224-unit playfield has to fit vertically.
expect("mobile-scale-fits-height", scale*224 <= 1080 and (scale+1)*224 > 1080)
expect("mobile-scale-fits-width", scale*16*25 <= 2400)
expect("mobile-uispace", uispace == math.floor(width*16*scale/4))

-- A 16:9 phone: the height allows more scale than the width does. This is the
-- case that used to overshoot and push the view off the bottom of the screen.
love.graphics.getWidth = function() return 720 end
love.graphics.getHeight = function() return 1280 end
changescale(2)
expect("mobile-phone-fits-width", scale*16*25 <= 720)
expect("mobile-phone-fits-height", scale*224 <= 1280)
expect("mobile-phone-picks-width-limit", scale == 1)

-- Narrow portrait: width is the binding constraint.
love.graphics.getWidth = function() return 1000 end
love.graphics.getHeight = function() return 1600 end
changescale(2)
expect("mobile-scale-narrow-caps", scale == math.floor(1000/(16*25)))

-- Landscape tablet: height is the binding constraint.
love.graphics.getWidth = function() return 1600 end
love.graphics.getHeight = function() return 900 end
changescale(2)
expect("mobile-tablet-fits-height", scale == math.floor(900/224))
expect("mobile-tablet-fits-width", scale*16*25 <= 1600)

love.graphics.getWidth = function() return 800 end
love.graphics.getHeight = function() return 480 end
-- desktop: fresh boot with a desktop OS; changescale passes through untouched
love.system.getOS = function() return "Linux" end
dofile("mobilecontrols.lua")
love.load = function() end
love.load()
love.graphics.getWidth = function() return 800 end
love.graphics.getHeight = function() return 448 end
changescale(2)
expect("desktop-scale-passthrough", scale == 2 and gameheight == 448)

print(table.concat(out, "\n"))
print("---")
print(failures .. " failed")
