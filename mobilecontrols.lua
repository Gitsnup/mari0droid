-- Mobile touch controls for Mari0 Droid.
-- The layout is stored in mobilecontrols.txt using normalized coordinates.
local mobile = {
  enabled = true,
  opacity = 0.48,
  size = 68,
  controls = {
    left = {x=.10,y=.82,w=68,h=68,label="<"},
    right = {x=.22,y=.82,w=68,h=68,label=">"},
    down = {x=.16,y=.70,w=56,h=56,label="v"},
    jump = {x=.78,y=.78,w=76,h=76,label="A"},
    run = {x=.90,y=.68,w=64,h=64,label="B"},
    portal1 = {x=.78,y=.58,w=58,h=58,label="O"},
    portal2 = {x=.90,y=.54,w=58,h=58,label="O"},
    reload = {x=.08,y=.62,w=52,h=52,label="R"},
    use = {x=.28,y=.67,w=52,h=52,label="E"},
    pause = {x=.95,y=.10,w=46,h=46,label="||"}
  }
}

local fingers = {}
local editing = false
local selected = nil
local loaded = false
local old_update, old_draw

local function clamp(v,a,b) return math.max(a, math.min(b,v)) end
local function size_for(b)
  local w,h = love.graphics.getWidth(), love.graphics.getHeight()
  return b.w * (w / 800), b.h * (h / 480)
end
local function rect(name)
  local b = mobile.controls[name]
  local w,h = love.graphics.getWidth(), love.graphics.getHeight()
  local bw,bh = size_for(b)
  return b.x*w-bw/2, b.y*h-bh/2, bw, bh
end
local function hit(name,x,y)
  local rx,ry,rw,rh = rect(name)
  return x >= rx and x <= rx+rw and y >= ry and y <= ry+rh
end
local function save()
  local out = {"version=1", "opacity="..tostring(mobile.opacity)}
  for name,b in pairs(mobile.controls) do
    out[#out+1] = name.."="..b.x..","..b.y..","..b.w..","..b.h
  end
  love.filesystem.write("mobilecontrols.txt", table.concat(out,";"))
end
local function load()
  if loaded then return end
  loaded = true
  if not love.filesystem.getInfo("mobilecontrols.txt") then return end
  local data = love.filesystem.read("mobilecontrols.txt") or ""
  for item in data:gmatch("[^;]+") do
    local name,x,y,w,h = item:match("([^=]+)=([%d%.%-]+),([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)")
    if name and mobile.controls[name] then
      local b=mobile.controls[name]; b.x=tonumber(x); b.y=tonumber(y); b.w=tonumber(w); b.h=tonumber(h)
    elseif item:match("opacity=") then mobile.opacity=tonumber(item:match("opacity=([%d%.]+)")) or mobile.opacity end
  end
end
local function pressed(name) return fingers[name] ~= nil end
local function activate(name, down)
  if down then fingers[name] = true else fingers[name] = nil end
  if not down or not objects or not objects.player then return end
  local p = objects.player[1]
  if not p then return end
  if name=="jump" then p:jump()
  elseif name=="run" then p:fire()
  elseif name=="reload" then p:removeportals()
  elseif name=="use" then p:use()
  elseif name=="portal1" or name=="portal2" then
    shootportal(1, name=="portal1" and 1 or 2, p.x+6/16,p.y+6/16,p.pointingangle)
  elseif name=="pause" then
    pausemenuopen = not pausemenuopen
    if pausemenuopen then love.audio.pause() else playmusic() end
  end
end

function mobile_touchpressed(id,x,y)
  load()
  if gamestate=="options" and optionstab==1 then
    editing=true
    for name in pairs(mobile.controls) do if hit(name,x,y) then selected=name; fingers[id]=name; return true end end
    return true
  end
  for name in pairs(mobile.controls) do
    if hit(name,x,y) then fingers[id]=name; activate(name,true); return true end
  end
  -- The unoccupied right half is a virtual mouse/aim surface.
  if gamestate=="game" and x > love.graphics.getWidth()*.38 then
    fingers[id]="aim"; love.mouse.setPosition(x,y); return true
  end
  return false
end
function mobile_touchmoved(id,x,y)
  local old=fingers[id]
  if editing and type(old)=="string" and mobile.controls[old] then
    local b=mobile.controls[old]; local w,h=love.graphics.getWidth(),love.graphics.getHeight()
    b.x=clamp(x/w,.04,.96); b.y=clamp(y/h,.08,.94); return true
  elseif old=="aim" then love.mouse.setPosition(x,y); return true end
  return false
end
function mobile_touchreleased(id,x,y)
  local name=fingers[id]; fingers[id]=nil
  if editing then editing=false; selected=nil; save(); return true end
  if name and name~="aim" then activate(name,false); return true end
  return name~=nil
end
function mobile_isdown(action)
  for _,name in pairs(fingers) do if name==action then return true end end
  return false
end

local function draw_controls()
  if not mobile.enabled then return end
  if gamestate~="game" and not (gamestate=="options" and optionstab==1) then return end
  load()
  for name,b in pairs(mobile.controls) do
    local x,y,w,h=rect(name)
    local active=mobile_isdown(name) or (editing and selected==name)
    love.graphics.setColor(0.05,0.05,0.05, mobile.opacity + (active and .22 or 0))
    love.graphics.circle("fill",x+w/2,y+h/2,math.min(w,h)/2)
    love.graphics.setColor(1,1,1,0.85)
    love.graphics.circle("line",x+w/2,y+h/2,math.min(w,h)/2)
    love.graphics.printf(b.label,x,y+h*.38,w,"center")
  end
  if editing then
    love.graphics.setColor(1,1,1,1)
    love.graphics.print("drag buttons to move • release to save",18,18)
  end
  love.graphics.setColor(1,1,1,1)
end

local function install()
  load()
  local mt=getmetatable(love) or {}
  local oldindex=mt.__newindex
  mt.__newindex=function(t,k,v)
    if k=="load" and type(v)=="function" then
      old_update=v
      v=function(...) local r=old_update(...); load(); return r end
    elseif k=="update" and type(v)=="function" then
      old_update=v
      v=function(dt,...) local r=old_update(dt,...); return r end
    elseif k=="draw" and type(v)=="function" then
      old_draw=v
      v=function(...) local r=old_draw(...); draw_controls(); return r end
    end
    rawset(t,k,v)
  end
  mt.__index=mt.__index
  setmetatable(love,mt)
end
install()

love.touchpressed = mobile_touchpressed
love.touchmoved = mobile_touchmoved
love.touchreleased = mobile_touchreleased

-- Make the existing gameplay polling API understand virtual buttons.
local old_checkkey = checkkey
function checkkey(s)
  if s and s[1]=="touch" then return mobile_isdown(s[2]) end
  if old_checkkey then return old_checkkey(s) end
  return false
end

-- Default player controls are virtual; desktop controls remain available through keyboard events.
local old_defaultconfig = defaultconfig
function defaultconfig(...)
  local r=old_defaultconfig(...)
  if controls and controls[1] then
    for _,name in ipairs({"left","right","down","jump","run","reload","use","portal1","portal2"}) do
      controls[1][name]={"touch",name}
    end
  end
  return r
end
