-- Withdrawal regression in actual Kahlua; map/network/event objects are mocked.
local root = assert(arg[1])
local path = root .. "/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/VLS_NativeCabinOcclusion.lua"
local f = assert(io.open(path)); local body = f:read("*a"); f:close()
local checks = 0
local function check(ok, why) assert(ok, why); checks = checks + 1 end
local client = false
isClient = function() return client end
local V = {}
package.loaded.VLS_Config = V
require = function() return V end
local hooks = {}
Events = {}
for _, name in ipairs({"OnTick", "OnObjectAdded", "LoadGridsquare", "OnSave", "OnGameExit"}) do
    local event = { callbacks = {} }; hooks[name] = event
    event.Add = function(fn) event.callbacks[#event.callbacks + 1] = fn end
    event.Remove = function(fn)
        for i = #event.callbacks, 1, -1 do
            if event.callbacks[i] == fn then table.remove(event.callbacks, i) end
        end
    end
    Events[name] = event
end
local function square()
    local s = { objects = {}, loaded = true, packets = 0 }
    function s:getChunk() return self.loaded and {} or nil end
    function s:getSpecialObjects()
        return {size = function() return #self.objects end,
            get = function(_, i) return self.objects[i + 1] end}
    end
    function s:transmitRemoveItemFromSquare(o)
        for i, item in ipairs(self.objects) do
            if item == o then table.remove(self.objects, i); self.packets = self.packets + 1; return end
        end
        error("unregistered removal")
    end
    return s
end
local function object(s, tag)
    local o = {data = {}, render = false, noPicking = true}
    if tag ~= nil then o.data.vlsParkedCabinOcclusion = tag end
    function o:hasModData() return self.data.vlsParkedCabinOcclusion ~= nil end
    function o:getModData() return self.data end
    function o:getObjectIndex()
        for i, item in ipairs(s.objects) do if item == self then return i - 1 end end
        return -1
    end
    s.objects[#s.objects + 1] = o
    return o
end
local function load() return assert(loadstring(body))() end
local C = {edges = {}, creates = 0}
function C.plan() error("withdrawn planner must never run") end
function C.createCurtain() C.creates = C.creates + 1 end
function C.update() C.createCurtain() end
function C.tick() if C.failed then return end; C.update() end
function C.hide() end
function C.loadSquare() end
function C.clear() error("old clear must be replaced") end
V.NativeCabinOcclusion = C
local oldTick = C.tick
for name, fn in pairs({OnTick = C.tick, OnObjectAdded = C.hide,
        LoadGridsquare = C.loadSquare, OnSave = C.clear, OnGameExit = C.clear}) do
    hooks[name].Add(fn)
end
local first = square()
local owned = object(first, true)
local orphan = object(first, true)
local ordinary = object(first)
local falseTag = object(first, false)
local foreignTag = object(first, "other")
C.edges.a = {square = first, curtain = owned}
C.edges.b = {square = first, curtain = orphan}
local player = {invisible = false, ghost = false, sound = "native"}
local function forbidden() error("withdrawal must not touch player or create curtain") end
player.setInvisible, player.setGhostMode = forbidden, forbidden
IsoCurtain = {new = forbidden}
getOnlinePlayers, getSpecificPlayer, getCell = forbidden, forbidden, forbidden
check(load() == C, "reuse loaded singleton for live callback references")
check(C.disabled and C.failed, "withdrawn state disables old tick")
oldTick(); check(C.creates == 0, "captured old tick cannot recreate a barrier")
check(owned:getObjectIndex() < 0 and orphan:getObjectIndex() < 0, "remove owned and same-square marked orphan")
check(first.packets == 2, "one native removal per tagged object")
check(ordinary:getObjectIndex() >= 0 and falseTag:getObjectIndex() >= 0 and foreignTag:getObjectIndex() >= 0,
    "ordinary curtains and non-true tags preserved")
check(C.plan == nil and C.createCurtain == nil and C.update == nil and C.tick == nil and C.hide == nil,
    "remove all concealment entry points")
local edgeCount = 0; for _ in pairs(C.edges) do edgeCount = edgeCount + 1 end
check(edgeCount == 0, "release former ownership")
for _, name in ipairs({"OnTick", "OnObjectAdded", "OnSave", "OnGameExit"}) do
    check(#hooks[name].callbacks == 0, "detach old " .. name)
end
check(#hooks.LoadGridsquare.callbacks == 1, "only saved-object cleanup hook remains")
local saved = square(); local savedObject = object(saved, true); local nativeObject = object(saved)
check(C.loadSquare(saved) == 1 and savedObject:getObjectIndex() < 0, "clean loaded saved marker")
check(nativeObject:getObjectIndex() >= 0, "saved-object cleanup preserves native curtain")
check(C.loadSquare(saved) == 0 and C.clear() == 0, "cleanup is idempotent")
local unloaded = square(); unloaded.loaded = false; local deferred = object(unloaded, true)
check(C.loadSquare(unloaded) == 0 and deferred:getObjectIndex() >= 0, "unloaded chunks wait for native load")
unloaded.loaded = true; hooks.LoadGridsquare.callbacks[1](unloaded)
check(deferred:getObjectIndex() < 0, "native square load cleans deferred marker")
check(load() == C and #hooks.LoadGridsquare.callbacks == 1, "repeat reload does not duplicate cleanup")
client = true
local remote = square(); local received = object(remote, true)
C.edges.remote = {square = remote, curtain = received}
load()
check(received:getObjectIndex() >= 0 and remote.packets == 0, "client never removes authoritative objects")
check(#hooks.LoadGridsquare.callbacks == 0, "client registers no concealment or cleanup hooks")
check(C.loadSquare(remote) == 0, "client cleanup stays server-authorized")
check(player.invisible == false and player.ghost == false and player.sound == "native", "player state unchanged")
client = false; V.NativeCabinOcclusion = nil
local fresh = load()
check(fresh ~= C and fresh.disabled and fresh.tick == nil, "fresh startup cannot enable concealment")
check(fresh.clear() == 0 and #hooks.LoadGridsquare.callbacks == 1, "fresh startup installs only marker cleanup")
print("PARKED_CABIN_WITHDRAWAL_PASS checks=" .. checks)
