-- Mobile touch controls for Mari0 Droid.
-- Required from main.lua before love.load; hooks the callbacks main.lua
-- assigns to love.*, and on Android/iOS rewires player 1 to on-screen buttons.
-- Button layout is stored in mobilecontrols.txt (save directory) using
-- normalized screen coordinates. On the options screen (controls tab) you can
-- drag the buttons around; releasing saves the layout.
-- State lives in _G.__mobilecontrols so that reloads never strand stale
-- closures pointing at dead state.

local S = _G.__mobilecontrols or {}
_G.__mobilecontrols = S

local mobile = {
	opacity = 0.48,
	controls = {
		-- Labels must be characters the game's own font atlas can draw.
		-- fontglyphs (main.lua) only carries digits, UPPERCASE letters and
		-- .:/,'C-_>* !{}? -- so no lowercase and no "+". Anything outside that
		-- set renders as a blank circle.
		-- D-pad as a real cross: up above, down below, left and right flanking
		-- a shared centre, so each direction sits where a thumb expects it.
		-- The old layout put up/down on a vertical line beside the horizontals,
		-- which read as four unrelated buttons.
		-- Labels must map to a cell in font.png (main.lua's fontglyphs). That set
		-- is digits + LOWERCASE a-z + .:/,'C-_>* !{}? -- there are no uppercase
		-- letters and no "<" or "^", and a character outside the set draws
		-- nothing at all. The atlas has a right triangle (">") and a down
		-- triangle ("{"), but no up or left arrow, so those two say "up"/"lt".
		up      = {x=.155, y=.659, w=64, h=64, label="up"},
		down    = {x=.155, y=.811, w=64, h=64, label="{"},
		left    = {x=.102, y=.735, w=64, h=64, label="lt"},
		right   = {x=.208, y=.735, w=64, h=64, label=">"},
		jump    = {x=.78, y=.78, w=76, h=76, label="a"},
		run     = {x=.90, y=.68, w=64, h=64, label="b"},
		portal1 = {x=.78, y=.58, w=58, h=58, label="1"},
		portal2 = {x=.90, y=.54, w=58, h=58, label="2"},
		reload  = {x=.060, y=.600, w=52, h=52, label="r"},
		use     = {x=.265, y=.735, w=52, h=52, label="use"},
		pause   = {x=.95, y=.10, w=46, h=46, label="p"},
	}
}
S.controls = mobile.controls
-- A DEEP COPY of the shipped layout. S.controls is the same table as
-- mobile.controls, so load() mutates it in place when a save file exists; a
-- plain alias here would silently track those mutations instead of preserving
-- the defaults it claims to hold.
S.defaultcontrols = {}
for name, b in pairs(mobile.controls) do
	local c = {}
	for k, v in pairs(b) do c[k] = v end
	S.defaultcontrols[name] = c
end

local actions = {"left", "right", "down", "up", "jump", "run", "reload", "use", "portal1", "portal2"}

S.held = {}          -- control name -> true while held
local held = S.held
local fingers = {}   -- touch id -> control name | "aim" | "ignore"
local editing = false
local selected = nil
local loaded = false
S.ismobile = false
S.lastaim = nil      -- {x, y} in window pixels

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function ismobileos()
	return love.system ~= nil and (love.system.getOS() == "Android" or love.system.getOS() == "iOS")
end
local function size_for(b)
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	return b.w * (w / 800), b.h * (h / 480)
end
local function rect(name)
	local b = S.controls[name]
	local bw, bh = size_for(b)
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	return b.x*w - bw/2, b.y*h - bh/2, bw, bh
end
local function hit(name, x, y)
	local rx, ry, rw, rh = rect(name)
	return x >= rx and x <= rx+rw and y >= ry and y <= ry+rh
end
-- Nearest button whose rect contains the point (so an overlapping layout
-- never makes a button unreachable).
local function hitbutton(x, y)
	local best, bestd = nil, nil
	for name in pairs(S.controls) do
		if hit(name, x, y) then
			local b = S.controls[name]
			local w, h = love.graphics.getWidth(), love.graphics.getHeight()
			local d = (b.x*w - x)^2 + (b.y*h - y)^2
			if not best or d < bestd then best, bestd = name, d end
		end
	end
	return best
end

local function save()
	local out = {"version=1", "opacity=" .. string.format("%.3f", mobile.opacity)}
	for name, b in pairs(S.controls) do
		out[#out+1] = name .. "=" .. b.x .. "," .. b.y .. "," .. b.w .. "," .. b.h
	end
	love.filesystem.write("mobilecontrols.txt", table.concat(out, ";"))
end
local function load()
	if loaded then return end
	loaded = true
	if not love.filesystem.getInfo("mobilecontrols.txt") then return end
	local data = love.filesystem.read("mobilecontrols.txt") or ""
	for item in data:gmatch("[^;]+") do
		local name, x, y, w, h = item:match("([^=]+)=([%d%.%-]+),([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)")
		if name and S.controls[name] then
			local b = S.controls[name]
			b.x = tonumber(x); b.y = tonumber(y); b.w = tonumber(w); b.h = tonumber(h)
		elseif item:match("^opacity=") then
			mobile.opacity = tonumber(item:match("^opacity=([%d%.]+)")) or mobile.opacity
		end
	end
end

local function applytouchbindings()
	if not controls then return end
	controls[1] = controls[1] or {}
	for _, name in ipairs(actions) do
		controls[1][name] = {"touch", name}
	end
end

-- Store the aim point and immediately rotate player 1's portal gun toward it.
local function aimfrom(x, y)
	S.lastaim = {x = x, y = y}
	if not S.ismobile then return end
	local p = objects and objects.player and objects.player[mouseowner or 1]
	if p and p.pointingangle ~= nil and scale then
		local sc = scale
		if shaders and shaders.scale then sc = shaders.scale end
		p.pointingangle = math.atan2(p.x+6/16-xscroll-(x/16/sc), (p.y+6/16-.5)-(y/16/sc))
	end
end

local function activate(name, down)
	if down then held[name] = true else held[name] = nil end
	if gamestate ~= "game" then return end

	if down and endpressbutton then
		endpressbutton = false
		endgame()
		return
	end

	if pausemenuopen or menuprompt or desktopprompt or suspendprompt then
		if name == "pause" and not down then
			if menuprompt or desktopprompt or suspendprompt then
				menuprompt = false
				desktopprompt = false
				suspendprompt = false
			elseif not everyonedead then
				pausemenuopen = false
				playmusic()
			end
		end
		return
	end

	local p = objects and objects.player and objects.player[1]

	if not down then
		if name == "jump" and p then p:stopjump() end
		if name == "pause" and not everyonedead then
			pausemenuopen = true
			love.audio.pause()
			playsound(pausesound)
		end
		return
	end

	if not p then return end
	if name == "jump" then p:jump()
	elseif name == "run" then p:fire()
	elseif name == "reload" then p:removeportals()
	elseif name == "use" then p:use()
	elseif name == "portal1" or name == "portal2" then
		if playertype == "portal" then
			shootportal(1, name == "portal1" and 1 or 2, p.x+6/16, p.y+6/16, p.pointingangle)
		end
	end
end

function mobile_touchpressed(id, x, y)
	load()
	if gamestate == "options" and optionstab == 1 then
		editing = true
		local name = hitbutton(x, y)
		if name then
			selected = name
			fingers[id] = name
		end
		return true
	end
	if gamestate ~= "game" then return false end
	local name = hitbutton(x, y)
	if name then
		fingers[id] = name
		activate(name, true)
		return true
	end
	-- The unoccupied right side of the screen is an aim surface: dragging aims
	-- the portal gun, a quick tap also fires portal 1 (via the mouse event).
	if x > love.graphics.getWidth()*0.38 then
		fingers[id] = "aim"
		aimfrom(x, y)
		return true
	end
	fingers[id] = "ignore"
	return false
end

function mobile_touchmoved(id, x, y)
	local t = fingers[id]
	if editing then
		if type(t) == "string" and S.controls[t] then
			local b = S.controls[t]
			local w, h = love.graphics.getWidth(), love.graphics.getHeight()
			b.x = clamp(x/w, .04, .96)
			b.y = clamp(y/h, .08, .94)
		end
		return true
	elseif t == "aim" then
		aimfrom(x, y)
		return true
	end
	return t ~= nil
end

function mobile_touchreleased(id, x, y)
	local t = fingers[id]
	fingers[id] = nil
	if editing then
		editing = false
		selected = nil
		save()
		return true
	end
	if t and t ~= "aim" then
		activate(t, false)
		return true
	end
	return t ~= nil
end

-- Rows drawn by the main menu, as (top, bottom) in un-scaled gui units.
-- Taken straight from menu.lua's properprint calls: 122, 138, 154, 170, 186,
-- each glyph 8 units tall, each row 16 units apart. "continue game" only
-- exists when a suspend file is present.
--
-- Those calls sit inside a `love.graphics.translate(tx, ty)` with ty = scale
-- (the outline pass, which the final "i == 9" iteration sets to 0, +scale), so
-- every row is drawn one scale-unit lower than its literal coordinate. The
-- bands below are shifted by that one unit; without it a tap one pixel off the
-- row's top edge falls through and the menu ignores it.
local menu_rows = {
	{123, 138}, -- continue game
	{139, 154}, -- player game
	{155, 170}, -- level editor
	{171, 186}, -- select mappack
	{187, 202}, -- options
}
-- Exposed so the harness can derive tap coordinates from the same table the hit
-- test uses. A test that hardcodes its own copy silently drifts out of sync the
-- moment a band moves, which is exactly what happened here.
S.menu_rows = menu_rows

-- The menu, options and mappack screens are keyboard-driven: every action lives
-- in menu_keypressed, and nothing ever calls guielement:click for them
-- (menu_mousepressed is an empty stub). So a tap has to be translated into the
-- key presses the game already handles.
--
-- Rather than reimplement navigation, move `selection` to the tapped row and
-- then send "return", so there stays exactly one copy of the menu logic.
--
-- The coordinates: the menu draws its rows at (starty + row*16) * scale, and
-- horizontal positions between -(64*scale) and 92*scale. But `scale` is capped
-- so a logical width fits the screen, and `uispace` -- which is what the menu's
-- shifts and the window centring are built from -- is derived from the FULL
-- logical width. `x / scale` is therefore wrong: on a 1080p phone it lands at
-- 2.77x the intended row. The row's real screen x is its offset from the centre
-- of the logical width, scaled up.
local function tapspace()
	local sc = scale
	if shaders and shaders.scale then sc = shaders.scale end
	if not sc or sc <= 0 then return nil end
	local gw, gh = love.graphics.getWidth(), love.graphics.getHeight()
	local logw = width * 16
	if not logw or logw <= 0 then logw = gw / sc end
	local offx = (gw - logw * sc) / 2
	local offy = (gh - 224 * sc) / 2
	return sc, offx, offy, logw
end

local function menutap(x, y)
	if not S.ismobile then return false end
	if gamestate ~= "menu" and gamestate ~= "options" and gamestate ~= "mappackmenu" then
		return false
	end
	if not menu_keypressed then return false end

	local sc, offx, offy, logw = tapspace()
	if not sc then return false end

	local gui_y = (y - offy) / sc

	if gamestate == "menu" then
		-- Tapping a row is not enough on its own: selection 1 is "player game"
		-- unless a suspend exists, and "continue game" is row 0. Translate the
		-- tap into arrow presses instead, so the option list stays the single
		-- source of truth for what each row does.
		--
		-- The band list and the selection list must line up index for index.
		-- Without a suspend file the menu draws four rows, so the first band in
		-- menu_rows is not present on screen and its selection slot is skipped.
		local rows = {}
		if continueavailable then
			rows = {0, 1, 2, 3, 4}
		else
			-- No "continue game": the first band is not drawn on screen, so it
			-- holds a placeholder that the hit test treats as "nothing here".
			rows = {false, 1, 2, 3, 4}
		end

		for i, row in ipairs(menu_rows) do
			if gui_y >= row[1] and gui_y < row[2] and rows[i] then
				local want = rows[i]
				-- Walk selection to the tapped row using the game's own handler,
				-- and stop as soon as a press stops changing it. menu_keypressed
				-- clamps "up" at 1 unless a suspend file exists, so the walk can
				-- legitimately stall short of `want`; pressing on would just
				-- spin and then confirm the wrong row.
				local guard = 0
				while selection ~= want and guard < 10 do
					local before = selection
					guard = guard + 1
					menu_keypressed(selection > want and "up" or "down")
					if selection == before then break end
				end
				menu_keypressed("return")
				return true
			end
		end
		return false
	end

	-- Options and mappackmenu own their own cursors; both confirm whatever the
	-- cursor is on when they see "return".
	menu_keypressed("return")
	return true
end

-- True when a synthesized mouse event (Android reports the first touch as a
-- mouse) must be ignored so touching a button doesn't fire portals or click
-- hidden GUI. Taps in the aim area are allowed through: that's how you shoot.
local function swallowsynthetic(x, y)
	if not (S.ismobile and gamestate == "game") then return false end
	if pausemenuopen or menuprompt or desktopprompt or suspendprompt then return true end
	if x <= love.graphics.getWidth()*0.38 then return true end
	return hitbutton(x, y) ~= nil
end

-- Taps on the (keyboard-only) pause menu: select rows, confirm with a second
-- tap, adjust volume. Translated into the game's own key handling.
--
-- Coordinates come straight from game.lua's draw: the box spans
-- width*8*scale +/- 50*scale horizontally and (112-75)*scale..(112+75)*scale
-- vertically, rows sit at (112-60)*scale + (i-1)*25*scale with a second line
-- 10 units below for the wrapped "quit to menu"/"quit to desktop" labels, and
-- the yes/no prompt is at (112-24)..(112+24) with "yes" left of the centre.
local function pausetap(x, y)
	local sc, offx, offy = tapspace()
	if not sc or not width then return end

	local cx = offx + (width * 8) * sc
	local boxx = cx - 50*sc
	local boxy = offy + 37*sc

	if menuprompt or desktopprompt or suspendprompt then
		if y >= offy + 88*sc and y <= offy + 136*sc and x >= boxx and x <= boxx + 200*sc then
			local sel = x < cx and 1 or 2
			if pausemenuselected2 == sel then
				game_keypressed("return")
			else
				pausemenuselected2 = sel
				game_keypressed(sel == 1 and "left" or "right")
			end
		end
		return
	end

	if x < boxx or x > boxx + 100*sc or y < boxy or y > boxy + 150*sc then return end
	for i = 1, #pausemenuoptions do
		local ry = offy + (112*sc) - 60*sc + (i-1)*25*sc
		if y >= ry - 8*sc and y <= ry + 24*sc then
			if pausemenuselected == i then
				if pausemenuoptions[i] == "volume" then
					game_keypressed(x >= cx and "right" or "left")
				else
					game_keypressed("return")
				end
			else
				pausemenuselected = i
			end
			return
		end
	end
end

-- Button labels are drawn with the game's own 8x8 glyph atlas rather than
-- love's default font, which is a 12px outline face that reads badly at button
-- size. Centres the text, and steps the size down for anything longer than a
-- single glyph.
-- Draw a button label with the GAME'S OWN font, not love's default.
--
-- properprint scales every glyph by the global `scale` (currently ~4.8 on a
-- 1080-tall screen), which would blow an 8x8 glyph up to ~38px inside a 68px
-- button. So borrow the global for the duration of the call: save it, draw at a
-- fixed size, restore it. Nothing else runs between the save and the restore, so
-- the mutation never escapes this function.
local function drawlabel(label, x, y, w, h)
	if not label or label == "" then return end
	local n = string.len(label)
	-- Keep the label inside the button with a little breathing room. The clamp
	-- matters more than the division: a 3-glyph label in a 52px button works out
	-- to scale 1, i.e. 8px tall on a 2340px screen, which is unreadable. Allow a
	-- mild overflow rather than shrinking a word into noise.
	-- Floor of 2 keeps short words readable; ceiling of 4 stops a single glyph
	-- from ballooning to fill the whole circle and looking unlike the others.
	local size = math.floor(math.min(w, h) * 0.72 / (8 * n))
	if size < 2 then size = 2 end
	if size > 4 then size = 4 end
	-- ...but never let a long word run outside its circle.
	while n * 8 * size > w - 4 and size > 1 do size = size - 1 end
	local tw = n * 8 * size
	local saved = scale
	scale = size
	properprint(label, x + (w - tw) / 2, y + h / 2 - 4 * size)
	scale = saved
end

local function draw_controls()
	if gamestate ~= "game" then
		for k in pairs(S.held) do S.held[k] = nil end
	end
	if gamestate ~= "game" and not (gamestate == "options" and optionstab == 1) then return end
	if not S.ismobile then return end
	load()
	for name, b in pairs(S.controls) do
		local x, y, w, h = rect(name)
		local active = S.held[name] == true or (editing and selected == name)
		local r, g, bl = 0.05, 0.05, 0.05
		if name == "portal1" then r, g, bl = 0.25, 0.55, 1
		elseif name == "portal2" then r, g, bl = 1, 0.55, 0.15 end
		love.graphics.setColor(r, g, bl, mobile.opacity + (active and .25 or 0))
		love.graphics.circle("fill", x+w/2, y+h/2, math.min(w, h)/2)
		love.graphics.setColor(1, 1, 1, 0.85)
		love.graphics.circle("line", x+w/2, y+h/2, math.min(w, h)/2)
		drawlabel(b.label, x, y, w, h)
	end
	if editing then
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.print("drag buttons to move - release to save", 14, 14)
	end
	love.graphics.setColor(1, 1, 1, 1)
end

-- Wrappers for globals that only exist once love.load has required the
-- gameplay files (checkkey, mario). Idempotent via __mobile* flags so module
-- reloads never build stale wrapper chains.
local function postwrap()
	if checkkey and not S.ckwrapped then
		local oldcheckkey = checkkey
		checkkey = function(s)
			if s and s[1] == "touch" then return S.held[s[2]] == true end
			return oldcheckkey(s)
		end
		S.ckwrapped = true
	end

	if mario and mario.updateangle and not S.uawrapped then
		local oldupdateangle = mario.updateangle
		mario.updateangle = function(self)
			if not S.ismobile or self.playernumber ~= (mouseowner or 1) then
				return oldupdateangle(self)
			end
			if S.lastaim and scale then
				local sc = scale
				if shaders and shaders.scale then sc = shaders.scale end
				self.pointingangle = math.atan2(self.x+6/16-xscroll-(S.lastaim.x/16/sc), (self.y+6/16-.5)-(S.lastaim.y/16/sc))
			else
				self.pointingangle = -math.pi/2
			end
		end
		S.uawrapped = true
	end

	applytouchbindings()
end

-- Android ignores love.window.setMode's desktop size, so the game would render
-- at the raw device resolution with `scale` left at its desktop value. Pick a
-- scale from the real screen instead.
--
-- Only ONE constraint matters: 224 is the visible playfield height (14 blocks
-- of 16), so the screen height fixes the scale at h/224. The level scrolls
-- horizontally, so its full width never has to fit on screen at once, and a
-- width cap only ever shrinks the view and letterboxes the sides.
--
-- The scale is deliberately NOT floored. Flooring h/224 wastes the remainder as
-- dead space: on a 1080p phone the fit is 4.82, so flooring to 4 drew the
-- playfield 896px tall in a 1080px window and left 17% of the screen empty
-- above and below. Rounding down is only needed by callers that require whole
-- pixels, so it stays available via mobilescale(true, w, h).
local function mobilescale(integer, w, h)
	local s = h / 224
	if integer then s = math.floor(s) end
	return math.max(1, s)
end

local function wrapchangescale()
	if S.cswrapped then return end
	local oldchangescale = changescale
	if not oldchangescale then return end
	changescale = function(s, fullscreen, ...)
		if S.ismobile and love.graphics then
			local w, h = love.graphics.getWidth(), love.graphics.getHeight()
			if w > 0 and h > 0 then
				local newscale = mobilescale(false, w, h)
				if newscale ~= scale or fullscreen ~= fullscreenmode then
					fullscreenmode = fullscreen
					oldchangescale(newscale, fullscreen, ...)
					if shaders and shaders.refresh then pcall(function() shaders:refresh() end) end
					gamewidth, gameheight = w, h
					uispace = math.floor(width * 16 * scale / 4)
				end
				return
			end
		end
		return oldchangescale(s, fullscreen, ...)
	end
	S.cswrapped = true
end

-- On Android a Lua error shows a black screen with no console. Log it to
-- <save dir>/mari0droid-error.txt so failures are diagnosable.
local function wraperrorhandler()
	if S.errwrapped or not love.errorhandler then return end
	local olderrorhandler = love.errorhandler
	love.errorhandler = function(...)
		local msg = tostring((...))
		pcall(function()
			local log = {os.date("%Y-%m-%d %H:%M:%S"), msg}
			local trace = debug and debug.traceback and debug.traceback("", 2) or ""
			if trace and trace ~= "" then log[#log+1] = trace end
			love.filesystem.append("mari0droid-error.txt", table.concat(log, "\n") .. "\n\n")
		end)
		return olderrorhandler(msg)
	end
	S.errwrapped = true
end

local function prewrap()
	if defaultconfig and not S.cfgwrapped then
		local olddefaultconfig = defaultconfig
		defaultconfig = function(...)
			local r = olddefaultconfig(...)
			if S.ismobile then applytouchbindings() end
			return r
		end
		S.cfgwrapped = true
	end
end

local function install()
	local mt = getmetatable(love) or {}
	mt.__newindex = function(t, k, v)
		if type(v) == "function" then
			if k == "load" then
				local old = v
				v = function(...)
					S.ismobile = ismobileos()
					if S.ismobile then wraperrorhandler() end
					if S.ismobile and defaultconfig then prewrap() end
					if S.ismobile then wrapchangescale() end
					local r = old(...)
					if S.ismobile and checkkey and mario then postwrap() end
					return r
				end
			elseif k == "draw" then
				local old = v
				v = function(...)
					local r = old(...)
					draw_controls()
					return r
				end
			elseif k == "mousepressed" then
				local old = v
				v = function(x, y, button, istouch, ...)
					if istouch and S.ismobile then
						-- Menus are outside the game loop, so they get their own
						-- tap translation rather than the pause-menu handler.
						if menutap(x, y) then return end
						if pausemenuopen or menuprompt or desktopprompt or suspendprompt then
							pausetap(x, y)
							return
						end
						if swallowsynthetic(x, y) then return end
					end
					return old(x, y, button, istouch, ...)
				end
			elseif k == "mousereleased" then
				local old = v
				v = function(x, y, button, istouch, ...)
					if istouch and swallowsynthetic(x, y) then return end
					return old(x, y, button, istouch, ...)
				end
			end
		end
		rawset(t, k, v)
	end
	setmetatable(love, mt)
end

install()

love.touchpressed = mobile_touchpressed
love.touchmoved = mobile_touchmoved
love.touchreleased = mobile_touchreleased
