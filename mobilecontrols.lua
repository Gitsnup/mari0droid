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
		left    = {x=.10, y=.82, w=68, h=68, label="<"},
		right   = {x=.22, y=.82, w=68, h=68, label=">"},
		down    = {x=.16, y=.70, w=56, h=56, label="v"},
		up      = {x=.16, y=.56, w=48, h=48, label="^"},
		jump    = {x=.78, y=.78, w=76, h=76, label="A"},
		run     = {x=.90, y=.68, w=64, h=64, label="B"},
		portal1 = {x=.78, y=.58, w=58, h=58, label="O"},
		portal2 = {x=.90, y=.54, w=58, h=58, label="O"},
		reload  = {x=.08, y=.62, w=52, h=52, label="R"},
		use     = {x=.28, y=.67, w=52, h=52, label="E"},
		pause   = {x=.95, y=.10, w=46, h=46, label="||"},
	}
}
S.controls = mobile.controls

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
local function pausetap(x, y)
	local sc = scale
	if shaders and shaders.scale then sc = shaders.scale end
	if not width or not sc then return end
	local cx = width*8*sc

	if menuprompt or desktopprompt or suspendprompt then
		if y >= 100*sc and y <= 132*sc then
			local left = x < cx
			local sel = left and 1 or 2
			if pausemenuselected2 == sel then
				game_keypressed("return")
			else
				pausemenuselected2 = sel
				game_keypressed(left and "left" or "right")
			end
		end
		return
	end

	local boxx, boxy, boxw, boxh = cx-50*sc, 37*sc, 100*sc, 150*sc
	if x < boxx or x > boxx+boxw or y < boxy or y > boxy+boxh then return end
	for i = 1, #pausemenuoptions do
		local ry = 112*sc - 60*sc + (i-1)*25*sc
		if y >= ry-8*sc and y <= ry+20*sc then
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
		love.graphics.printf(b.label, x, y+h*0.28, w, "center")
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
					if S.ismobile and defaultconfig then prewrap() end
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
