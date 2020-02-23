# LibClassicTalentQuery

Query talents from other players in classic (using the Details protocol)

Loosely based on [LibTalentQuery](https://www.wowace.com/projects/libtalentquery-1-0),
but uses addon messages instead of `NotifyInspect()`

```lua
local TalentQuery = LibStub:GetLibrary("LibClassicTalentQuery")
TalentQuery.RegisterCallback(MyAddon, "TalentQuery_Update")

TalentQuery:Query(unitOrGuid)

-- Update will fire for any query result, and also for any PARTY broadcasts made
-- by the Details addon.
function MyAddon:TalentQuery_Update(e, name, server, talents)
  -- ...
end
```
