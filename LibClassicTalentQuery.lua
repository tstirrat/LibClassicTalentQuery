local MAJOR, MINOR = "LibClassicTalentQuery", "0.9.0-@project-version@"
local lib = LibStub:NewLibrary(MAJOR, MINOR)

--[[
  Usage:

  local TalentQuery = LibStub:GetLibrary("LibClassicTalentQuery")
  TalentQuery.RegisterCallback(MyAddon, "TalentQuery_Update")

  TalentQuery:Query(unit)

  -- Update will fire for any query result, and also for any PARTY broadcasts made
  -- by the Details addon.
  function MyAddon:TalentQuery_Update(error, name, server, talents)
    raidTalents[UnitGUID(unitid)] = spec
  end
]]
local UPDATE_EVENT = "TalentQuery_Update"
local CONST_DETAILS_PREFIX = "DTLS"
local CONST_ASK_TALENTS = "AT"
local CONST_ANSWER_TALENTS = "AWT"

local _UnitName = UnitName
local _GetRealmName = GetRealmName

lib.debug = true
local function prdebug(...)
  if lib.debug == true then
    print("|cFFFF0000[ClassicTalentQuery]|r", ...)
  end
end

if not lib then
  return
end

lib.UPDATE_EVENT = UPDATE_EVENT
lib.realversion = "C195"

if not lib.events then
  lib.events = LibStub("CallbackHandler-1.0"):New(lib)
end

local frame = lib.frame
if not frame then
  frame = CreateFrame("Frame", MAJOR .. "_Frame")
  lib.frame = frame
end

function lib:Query(unit)
  prdebug("Query", unit)
  local targetName = Ambiguate(GetUnitName(unit, true), "none")

  if (targetName) then
    lib:SendCommMessage(
      CONST_DETAILS_PREFIX,
      lib:Serialize(
        CONST_ASK_TALENTS,
        UnitName("player"),
        GetRealmName(),
        lib.realversion,
        UnitGUID("player")
      ),
      "WHISPER",
      targetName
    )
  end
end

function ReceivedTalentsQuery(player, realm, core_version, playerSerial)
  lib.ask_talents_cooldown = lib.ask_Talents_cooldown or 0
  if (lib.ask_talents_cooldown > time()) then
    return
  end
  lib.ask_talents_cooldown = time() + 5

  local targetName = Ambiguate(player .. "-" .. realm, "none")
  prdebug("Recieved talent query from", player, targetName)
  -- lib:SendPlayerClassicInformation(targetName)
end

function ReceivedTalentsInformation(player, realm, core_version, serial, itemlevel, talents, spec)
  lib:ClassicSpecFromNetwork(player, realm, core_version, serial, itemlevel, talents, spec)
end

local COMM_HANDLERS = {
  [CONST_ASK_TALENTS] = ReceivedTalentsQuery,
  [CONST_ANSWER_TALENTS] = ReceivedTalentsInformation
}

local LibAceSerializer = LibStub("AceSerializer-3.0")
local _select = select

function lib:CommReceived(_, data, _, source)
  local prefix, player, realm, dversion, arg6, arg7, arg8, arg9 =
    _select(2, LibAceSerializer:Deserialize(data))

  prdebug("(debug) network received:", prefix, "length:", string.len(data))

  print("comm received", prefix, COMM_HANDLERS[prefix])

  local func = COMM_HANDLERS[prefix]
  if (func) then
    --todo: this call should be safe
    func(player, realm, dversion, arg6, arg7, arg8, arg9)
  else
    -- prdebug("comm prefix not found:", prefix)
  end
end

local aceComm = LibStub:GetLibrary("AceComm-3.0")
local LibDeflate = LibStub("LibDeflate")

if (aceComm and LibAceSerializer and LibDeflate) then
  aceComm:Embed(lib)
  lib:RegisterComm(CONST_DETAILS_PREFIX, "CommReceived")
end

function lib:SendRaidData(type, ...)
  local isInInstanceGroup = IsInRaid(LE_PARTY_CATEGORY_INSTANCE)

  if (isInInstanceGroup) then
    lib:SendCommMessage(
      CONST_DETAILS_PREFIX,
      LibAceSerializer:Serialize(type, _UnitName("player"), _GetRealmName(), lib.realversion, ...),
      "INSTANCE_CHAT"
    )
    prdebug("(debug) sent comm to INSTANCE raid group")
  else
    lib:SendCommMessage(
      CONST_DETAILS_PREFIX,
      LibAceSerializer:Serialize(type, _UnitName("player"), _GetRealmName(), lib.realversion, ...),
      "RAID"
    )
    prdebug("(debug) sent comm to LOCAL raid group")
  end
end

function lib:SendPartyData(type, ...)
  local isInInstanceGroup = IsInGroup(LE_PARTY_CATEGORY_INSTANCE)

  if (isInInstanceGroup) then
    lib:SendCommMessage(
      CONST_DETAILS_PREFIX,
      LibAceSerializer:Serialize(type, _UnitName("player"), _GetRealmName(), lib.realversion, ...),
      "INSTANCE_CHAT"
    )
    if (lib.debug) then
      lib:Msg("(debug) sent comm to INSTANCE party group")
    end
  else
    lib:SendCommMessage(
      CONST_DETAILS_PREFIX,
      LibAceSerializer:Serialize(type, _UnitName("player"), _GetRealmName(), lib.realversion, ...),
      "PARTY"
    )
    if (lib.debug) then
      lib:Msg("(debug) sent comm to LOCAL party group")
    end
  end
end

function lib:SendPlayerClassicInformation(targetPlayer)
  if (not targetPlayer) then
    if (time() > talentWatchClassic.cooldown) then
      --isn't in cooldown, set a new cooldown
      talentWatchClassic.cooldown = time() + 5
    else
      --it's on cooldown
      if (not talentWatchClassic.delayedUpdate or talentWatchClassic.delayedUpdate._cancelled) then
        talentWatchClassic.delayedUpdate = C_Timer.NewTimer(10, lib.SendPlayerClassicInformation)
      end
      return
    end

    --cancel any schedule
    if (talentWatchClassic.delayedUpdate and not talentWatchClassic.delayedUpdate._cancelled) then
      talentWatchClassic.delayedUpdate:Cancel()
    end
    talentWatchClassic.delayedUpdate = nil
  end

  --amount of tabs existing
  local numTabs = GetNumTalentTabs() or 3

  --store the background textures for each tab
  local pointsPerSpec = {}
  local talentsSelected = {}

  for i = 1, (MAX_TALENT_TABS or 3) do
    if (i <= numTabs) then
      --tab information
      local name, iconTexture, pointsSpent, fileName = GetTalentTabInfo(i)
      if (name) then
        tinsert(pointsPerSpec, {name, pointsSpent, fileName})
      end

      --talents information
      local numTalents = GetNumTalents(i) or 20
      local MAX_NUM_TALENTS = MAX_NUM_TALENTS or 20

      for talentIndex = 1, MAX_NUM_TALENTS do
        if (talentIndex <= numTalents) then
          local name, iconTexture, tier, column, rank, maxRank, isExceptional, available =
            GetTalentInfo(i, talentIndex)
          if (name and rank and type(rank) == "number") then
            --send the specID instead of the specName
            local specID = lib.textureToSpec[fileName]
            tinsert(talentsSelected, {iconTexture, rank, tier, column, i, specID, maxRank})
          end
        end
      end
    end
  end

  local MIN_SPECS = 4

  --put the spec with more talent point to the top
  table.sort(
    pointsPerSpec,
    function(t1, t2)
      return t1[2] > t2[2]
    end
  )

  --get the spec with more points spent
  local spec = pointsPerSpec[1]
  if (spec and spec[2] >= MIN_SPECS) then
    local specName = spec[1]
    local spentPoints = spec[2]
    local specTexture = spec[3]

    --add the spec into the spec cache
    lib.playerClassicSpec = {}
    lib.playerClassicSpec.specs = lib.GetClassicSpecByTalentTexture(specTexture)
    lib.playerClassicSpec.talents = talentsSelected

    --cache the player specId
    lib.cached_specs[UnitGUID("player")] = lib.playerClassicSpec.specs
    --cache the player talents
    lib.cached_talents[UnitGUID("player")] = talentsSelected

    if (lib.playerClassicSpec.specs == 103) then
      if (lib:GetRoleFromSpec(lib.playerClassicSpec.specs, UnitGUID("player")) == "TANK") then
        lib.playerClassicSpec.specs = 104
        lib.cached_specs[UnitGUID("player")] = lib.playerClassicSpec.specs
      end
    end

    local CONST_DETAILS_PREFIX = "DTLS"
    local CONST_ITEMLEVEL_DATA = "IL"
    local CONST_ASK_TALENTS = "AT"
    local CONST_ANSWER_TALENTS = "AWT"

    local compressedTalents = lib:CompressData(talentsSelected, "comm")

    if (targetPlayer) then
      lib:SendCommMessage(
        CONST_DETAILS_PREFIX,
        lib:Serialize(
          CONST_ANSWER_TALENTS,
          UnitName("player"),
          GetRealmName(),
          lib.realversion,
          UnitGUID("player"),
          0,
          compressedTalents,
          lib.playerClassicSpec.specs
        ),
        "WHISPER",
        targetPlayer
      )

      prdebug("(debug) sent talents data to: " .. (targetPlayer or "UNKNOWN-PLAYER"))
    elseif (IsInRaid()) then
      lib:SendRaidData(
        CONST_ITEMLEVEL_DATA,
        UnitGUID("player"),
        0,
        compressedTalents,
        lib.playerClassicSpec.specs
      )
      prdebug("(debug) sent talents data to Raid")
    elseif (IsInGroup()) then
      lib:SendPartyData(
        CONST_ITEMLEVEL_DATA,
        UnitGUID("player"),
        0,
        compressedTalents,
        lib.playerClassicSpec.specs
      )
      prdebug("(debug) sent talents data to Party")
    end
  end
end

function lib:ClassicSpecFromNetwork(
  player,
  realm,
  core,
  serialNumber,
  itemLevel,
  talentsSelected,
  currentSpec)
  prdebug(
    "(debug) Received PlayerInfo Data: " ..
      (player or "Invalid Player Name") ..
        " | " ..
          (itemLevel or "Invalid Item Level") ..
            " | " ..
              (currentSpec or "Invalid Spec") .. " | {} | " .. (serialNumber or "Invalid Serial")
  )

  if (type(talentsSelected) == "string") then
    talentsSelected = lib:DecompressData(talentsSelected, "comm")
  end

  if (not player) then
    return
  end

  --> older versions of details wont send serial nor talents nor spec
  if (not serialNumber or not itemLevel or not talentsSelected or not currentSpec) then
    --if any data is invalid, abort
    return
  end

  if (type(serialNumber) ~= "string") then
    return
  end

  --> won't inspect this actor
  -- lib.trusted_characters[serialNumber] = true

  --store the item level
  if (type(itemLevel) == "number") then
  -- lib.item_level_pool[serialNumber] = {name = player, ilvl = itemLevel, time = time()}
  end

  --emit talents
  if (type(talentsSelected) == "table") then
    if (talentsSelected[1]) then
      -- lib.cached_talents[serialNumber] = talentsSelected
      self.events:Fire(UPDATE_EVENT, nil, player, realm, serialNumber, talentsSelected)
    end
  end
end

lib.validSpecIds = {
  [250] = true,
  [252] = true,
  [251] = true,
  [102] = true,
  [103] = true,
  [104] = true,
  [105] = true,
  [253] = true,
  [254] = true,
  [255] = true,
  [62] = true,
  [63] = true,
  [64] = true,
  [70] = true,
  [65] = true,
  [66] = true,
  [257] = true,
  [256] = true,
  [258] = true,
  [259] = true,
  [260] = true,
  [261] = true,
  [262] = true,
  [263] = true,
  [264] = true,
  [265] = true,
  [266] = true,
  [267] = true,
  [71] = true,
  [72] = true,
  [73] = true
}

lib.textureToSpec = {
  DruidBalance = 102,
  DruidFeralCombat = 103,
  DruidRestoration = 105,
  HunterBeastMaster = 253,
  HunterMarksmanship = 254,
  HunterSurvival = 255,
  MageArcane = 62,
  MageFrost = 64,
  MageFire = 63,
  PaladinCombat = 70,
  PaladinHoly = 65,
  PaladinProtection = 66,
  PriestHoly = 257,
  PriestDiscipline = 256,
  PriestShadow = 258,
  RogueAssassination = 259,
  RogueCombat = 260,
  RogueSubtlety = 261,
  ShamanElementalCombat = 262,
  ShamanEnhancement = 263,
  ShamanRestoration = 264,
  WarlockCurses = 265,
  WarlockDestruction = 266,
  WarlockSummoning = 267,
  WarriorArm = 71,
  WarriorArms = 71,
  WarriorFury = 72,
  WarriorProtection = 73
}

lib.specToTexture = {
  [102] = "DruidBalance",
  [103] = "DruidFeralCombat",
  [105] = "DruidRestoration",
  [253] = "HunterBeastMaster",
  [254] = "HunterMarksmanship",
  [255] = "HunterSurvival",
  [62] = "MageArcane",
  [64] = "MageFrost",
  [63] = "MageFire",
  [70] = "PaladinCombat",
  [65] = "PaladinHoly",
  [66] = "PaladinProtection",
  [257] = "PriestHoly",
  [256] = "PriestDiscipline",
  [258] = "PriestShadow",
  [259] = "RogueAssassination",
  [260] = "RogueCombat",
  [261] = "RogueSubtlety",
  [262] = "ShamanElementalCombat",
  [263] = "ShamanEnhancement",
  [264] = "ShamanRestoration",
  [265] = "WarlockCurses",
  [266] = "WarlockDestruction",
  [267] = "WarlockSummoning",
  [71] = "WarriorArms",
  [72] = "WarriorFury",
  [73] = "WarriorProtection"
}

function lib.IsValidSpecId(specId)
  return lib.validSpecIds[specId]
end

function lib.GetClassicSpecByTalentTexture(talentTexture)
  return lib.textureToSpec[talentTexture] or 0
end

-- ~compress ~zip ~export ~import ~deflate ~serialize
function lib:CompressData(data, dataType)
  local LibDeflate = LibStub:GetLibrary("LibDeflate")
  local LibAceSerializer = LibStub:GetLibrary("AceSerializer-3.0")

  if (LibDeflate and LibAceSerializer) then
    local dataSerialized = LibAceSerializer:Serialize(data)
    if (dataSerialized) then
      local dataCompressed = LibDeflate:CompressDeflate(dataSerialized, {level = 9})
      if (dataCompressed) then
        if (dataType == "print") then
          local dataEncoded = LibDeflate:EncodeForPrint(dataCompressed)
          return dataEncoded
        elseif (dataType == "comm") then
          local dataEncoded = LibDeflate:EncodeForWoWAddonChannel(dataCompressed)
          return dataEncoded
        end
      end
    end
  end
end

function lib:DecompressData(data, dataType)
  local LibDeflate = LibStub:GetLibrary("LibDeflate")
  local LibAceSerializer = LibStub:GetLibrary("AceSerializer-3.0")

  if (LibDeflate and LibAceSerializer) then
    local dataCompressed

    if (dataType == "print") then
      -- data = DetailsFramework:Trim(data)

      dataCompressed = LibDeflate:DecodeForPrint(data)
      if (not dataCompressed) then
        print("couldn't decode the data.")
        return false
      end
    elseif (dataType == "comm") then
      dataCompressed = LibDeflate:DecodeForWoWAddonChannel(data)
      if (not dataCompressed) then
        print("couldn't decode the data.")
        return false
      end
    end

    local dataSerialized = LibDeflate:DecompressDeflate(dataCompressed)
    if (not dataSerialized) then
      print("couldn't uncompress the data.")
      return false
    end

    local okay, data = LibAceSerializer:Deserialize(dataSerialized)
    if (not okay) then
      print("couldn't unserialize the data.")
      return false
    end

    return data
  end
end
