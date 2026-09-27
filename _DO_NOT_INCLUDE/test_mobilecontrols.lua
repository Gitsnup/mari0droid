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

-- The real main.lua requires mobilecontrols BEFORE defining love.load, so the
-- assignment hook catches it. Mirror that ordering here.
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
love.load = function() end  -- re-triggers the new module's load wrapper
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

print(table.concat(out, "\n"))
print("---")
print(failures .. " failed")
