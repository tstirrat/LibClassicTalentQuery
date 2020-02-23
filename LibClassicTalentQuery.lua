local MAJOR, MINOR = "LibClassicTalentQuery", "0.9.0-@project-version@"
local LibClassicTalentQuery = LibStub:NewLibrary(MAJOR, MINOR)

--[[
  Usage:

  local TalentQuery = LibStub:GetLibrary("LibClassicTalentQuery")
  TalentQuery.RegisterCallback(MyAddon, "TalentQuery_Update")

  TalentQuery:Query(unitOrGuid)

  -- Update will fire for any query result, and also for any PARTY broadcasts made
  -- by the Details addon.
  function MyAddon:TalentQuery_Update(e, name, server, talents)
    raidTalents[UnitGUID(unitid)] = spec
  end
]]
local UPDATE_EVENT = "TalentQuery_Update"

local function prdebug(...)
  print("|cFFFF0000[ClassicTalentQuery]|r", ...)
end

if not lib then
  return
end
if not lib.events then
  lib.events = LibStub("CallbackHandler-1.0"):New(lib)
end

local frame = lib.frame
if not frame then
  frame = CreateFrame("Frame", MAJOR .. "_Frame")
  lib.frame = frame
end
frame:UnregisterAllEvents()
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript(
  "OnEvent",
  function(this, event, ...)
    return lib[event](lib, ...)
  end
)

function lib:Query(unit)
  prdebug("Query", unit)
end

local aceComm = LibStub("AceComm-3.0")
local LibAceSerializer = LibStub("AceSerializer-3.0")
local LibDeflate = LibStub("LibDeflate")

function lib:CHAT_MSG_ADDON(prefix, message, channel, sender, target, ...)
  prdebug("CHAT_MSG_ADDON", prefix, message, channel, sender, target, ...)


end
