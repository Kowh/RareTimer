-----------------------------------------------------------------------------------------------
-- Client Lua Script for RareTimer
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "math"
require "string"
 
-----------------------------------------------------------------------------------------------
-- RareTimer Module Definition
-----------------------------------------------------------------------------------------------
local RareTimer = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("RareTimer", false) -- Configure = false
local L = Apollo.GetPackage("Gemini:Locale-1.0").tPackage:GetLocale("RareTimer", true) -- Silent = true
local GeminiLocale = Apollo.GetPackage("Gemini:Locale-1.0").tPackage


 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local version = 0.01
 
local Source = {
    Target = 0,
    Kill = 1,
    Create = 2,
    Destroy = 3,
    Combat = 4,
    Report = 5,
    Timer = 6,
}

local States = {
    Unknown = 0, -- Unseen, unreported
    Killed = 1, -- Player saw kill
    Dead = 2, -- Player saw corpse, but not the kill
    Pending = 3, -- Should spawn anytime now
    Alive = 4, -- Up and at full health
    InCombat = 5, -- In combat (not at 100%)
    Expired = 6, -- Been longer than MaxSpawn since last known kill
}

-----------------------------------------------------------------------------------------------
-- RareTimer OnInitialize
-----------------------------------------------------------------------------------------------
function RareTimer:OnInitialize()
    local defaults = {
        profile = {
            config = {
                SpamParty = false,
                SpamGuild = false,
                SpamZone = false,
                Slack = 600, --10m, EstMax + Slack = Expired
            },
            mobs = {
                ['**'] = {
                    --Name
                    State = States.Unknown,
                    --Killed
                    --Timestamp
                    --MinSpawn
                    --MaxSpawn
                    --Due
                    --Expires
                },
                {    
                    Name = L["Scorchwing"],
                    MinSpawn = 3600, --60m
                    MaxSpawn = 6600, --110m
                },
                {    
                    Name = L["Honeysting Barbtail"], 
                    MinSpawn = 120, --2m
                    MaxSpawn = 600, --10m
                }
            }
        }
    }
    self.db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(self, defaults, true)

    -- load our form file
    self.xmlDoc = XmlDoc.CreateFromFile("RareTimer.xml")
end

-----------------------------------------------------------------------------------------------
-- RareTimer OnEnable
-----------------------------------------------------------------------------------------------
function RareTimer:OnEnable()
    if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
        -- Init
        -- Slash commands
        Apollo.RegisterSlashCommand("raretimer", "OnRareTimerOn", self)

        -- Event handlers
        Apollo.RegisterEventHandler("CombatLogDamage", "OnCombatLogDamage", self)
        Apollo.RegisterEventHandler("TargetUnitChanged", "OnTargetUnitChanged", self)
        Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
        Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self)

        -- Status update channel
        self.chanICC = ICCommLib.JoinChannel("RareTimerChannel", "OnRareTimerChannelMessage", self)

        -- Timers
        --self.timer = ApolloTimer.Create(5.0, true, "onTimer", self) -- In seconds
    end
end

-----------------------------------------------------------------------------------------------
-- Slash commands
-----------------------------------------------------------------------------------------------

-- on SlashCommand "/raretimer"
function RareTimer:OnRareTimerOn(sCmd, sInput)
    local s = string.lower(sInput)
    if s ~= nil and s ~= '' and s ~= 'help' then
        if s == "list" then
            self:ShowList()
        elseif s == "spam" then
        elseif s == "debug" then
            self:PrintTable(self.db.profile.mobs)
        end
    else
        self:ShowHelp()
    end
    --Print(inspect(self.db))
    --for a,b in pairs(L) do
        --Print("A: " .. a .. " B: " .. b)
    --end
    --Print("RareTimer!")
    --self.wndMain:Show(true) -- show the window (Need to init before we can use)
end
function RareTimer:ShowHelp()
    self:CPrint("RareTimer commands:")
    self:CPrint("help <command>: Show help")
    self:CPrint("list: List the status of all mobs")
    self:CPrint("spam <name>: Broadcast the spawn timer")
end

-----------------------------------------------------------------------------------------------
-- Event callbacks
-----------------------------------------------------------------------------------------------

-- Capture mobs as they're targeted
function RareTimer:OnTargetUnitChanged(targetID)
    self:UpdateStatus(targetID, Source.Target)
end

-- Capture mobs as they're killed/damaged
function RareTimer:OnCombatLogDamage(tEventArgs)
    if tEventArgs.bTargetKilled then
        self:UpdateStatus(tEventArgs.unitTarget, Source.Kill)
    else
        self:UpdateStatus(tEventArgs.unitTarget, Source.Combat)
    end
end

-- Capture newly loaded/spawned mobs
function RareTimer:OnUnitCreated(unit)
    self:UpdateStatus(unit, Source.Create)
end

-- Capture mobs as they despawn
function RareTimer:OnUnitDestroyed(unit)
    self:UpdateStatus(unit, Source.Destroy)
end

-----------------------------------------------------------------------------------------------
-- RareTimer Functions
-----------------------------------------------------------------------------------------------

-- Update the status of a rare mob
function RareTimer:UpdateStatus(unit, source)
    if self:IsMob(unit) and self:IsNotable(unit:GetName()) then
        if unit:IsDead() then
            if source == Source.Kill then
                self:SawKilled(unit)
            else
                self:SawDead(unit)
            end
        else
            self:SawAlive(unit)
        end
    end
end

-- Record a kill
function RareTimer:SawKilled(unit)
    local time = GameLib.GetServerTime()
    local entry = self:GetEntry(name) or {}
    entry.State = States.Killed
    entry.Killed = time
    entry.Timestamp = time
    --entry.Expires = time + entry.MaxSpawn + self.db.config.Slack
    --entry.Due = time + entry.MinSpawn
    local strKilled = string.format(L["StateKilled"], time.strFormattedTime)
    Print(string.format("%s %s", unit:GetName(), strKilled))
end

-- Record a corpse
function RareTimer:SawDead(unit)
    local time = GameLib.GetServerTime()
    local entry = self:GetEntry(name) or {}
    if entry.State ~= States.Killed then
        entry.State = States.Dead
        entry.Killed = time
        entry.Timestamp = time
        --entry.Expires = time + entry.MaxSpawn + self.db.config.Slack
        --entry.Due = time + entry.MinSpawn
    end
end

-- Record a live mob
function RareTimer:SawAlive(unit)
    local time = GameLib.GetServerTime()
    local entry = self:GetEntry(name)
    local health = self:GetHealth(unit)
    local strState
    if health ~= nil and entry ~= nil then
        if health == 100 then
            entry.State = States.Alive
            strState = L["StateAlive"]
        else
            entry.State = States.InCombat
            strState = L["StateInCombat"]
        end
        entry.Timestamp = time
        local strAlive = string.format(strState, time.strFormattedTime)
        Print(string.format("%s %s", unit:GetName(), strAlive))
    end
end

-- Announce data to other clients
function RareTimer:Announce(data)
    for _, val in pairs(data) do
        local t = {}
        t.name = GameLib.GetPlayerUnit():GetName()
        t.message = "Name State Timestamp RareTimerVersion"
        self.chanICC:SendMessage(t)
    end
end

-- Parse announcements from other clients
function RareTimer:OnRareTimerChannelMessage(channel, tMsg)
    self:CPrint("Msg Received on " .. channel)
    self.PrintTable(tMsg)
end

-- Trigger housekeeping/announcements
function RareTimer:OnTimer()
    Print("Timer triggered")
    --self.unitPlayerDisposition = GameLib.GetPlayerUnit()
    --if self.unitPlayerDisposition == nil or not self.unitPlayerDisposition:IsValid() or RegisteredUsers == nil then
        --self.tQueuedUnits = {}
        --return
    --end    
end

-- Calculate % mob health
function RareTimer:GetHealth(unit)
    if unit ~= nil then
        local health = unit:GetHealth()
        local maxhealth = unit:GetMaxHealth()
        if health ~= nil and maxhealth ~= nil then
            assert(type(health) == "number", "GetHealth returned invalid number")
            assert(type(maxhealth) == "number", "GetMaxHealth returned invalid number")
            if maxhealth > 0 then
                return math.floor(health / maxhealth * 100)
            end
        end
    end
end

-- Is this a mob we are interested in?
function RareTimer:IsNotable(name)
    if name == nil then
        return false
    end
    for _, entry in pairs(self.db.profile.mobs) do
        if entry.Name == name then
            return true
        end
    end
    return false
end

-- Is this a mob?
function RareTimer:IsMob(unit)
    if unit ~= nil and unit:IsValid() and unit:GetType() == 'NonPlayer' then
        return true
    else
        return false
    end
end

-- Spam status of a given mob
function RareTimer:Spam(name, channel)
    --Guild/zone/party
    --Spam health if alive, last death if dead
end

-- Get the db entry for a mob
function RareTimer:GetEntry(name)
    for _, mob in pairs(self.db.profile.mobs) do
        if mob.Name == name then
            return mob
        end
    end
end

-- Print to the Command channel
function RareTimer:CPrint(msg)
    ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, msg, "")
end

-- Print the contents of a table to the Command channel
function RareTimer:PrintTable(table, depth)
    if depth == nil then
        depth = 0
    end
    if depth > 5 then
        return
    end

    local indent = string.rep(' ', depth*2)
    for name, value in pairs(table) do
        if type(value) == 'table' then
            if value.strFormattedTime ~= nil then
                local strTimestamp = string.format('%i-%i-%i %s', value.nYear, value.nMonth, value.nDay, tostring(value.strFormattedTime))
                self:CPrint(string.format("%s%s: %s", indent, name, strTimestamp))
            else
                self:CPrint(string.format("%s%s: {", indent, name))
                self:PrintTable(value, depth + 1)
                self:CPrint(string.format("%s}", indent))
            end
        else
            self:CPrint(string.format("%s%s: %s", indent, name, tostring(value)))
        end
    end
end    

-----------------------------------------------------------------------------------------------
-- RareTimerForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function RareTimer:OnOK()
    self.wndMain:Show(false) -- hide the window
end

-- when the Cancel button is clicked
function RareTimer:OnCancel()
    self.wndMain:Show(false) -- hide the window
end

-- Print status list
function RareTimer:ShowList()
    self:CPrint("Not yet implemented")
end

-----------------------------------------------------------------------------------------------
-- Junk !
-----------------------------------------------------------------------------------------------

  --local disposition = unit:GetDispositionTo(GameLib.GetPlayerUnit())

--  if unit:IsValid() and not unit:IsDead() and not unit:IsACharacter() and 
--     (table.find(unitName, self.rareNames) or table.find(unitName, self.customNames)) then
--    local item = self.rareMobs[unit:GetName()]
--    if not item then
--      if self.broadcastToParty and GroupLib.InGroup() then
--        -- no quick way to party chat, need to find the channel first
--        for _,channel in pairs(ChatSystemLib.GetChannels()) do
--          if channel:GetType() == ChatSystemLib.ChatChannel_Party then
--            channel:Send("Rare detected: " .. unit:GetName())
--          end
--        end
--      end
--    end
--  end
--
    --Yellowtail Fury: id 5380606, Elite 0, ClassId 23, Archetype[idArchetype] = 20 (Tank)
    --Perfect Stag: id: 4403258, Elite 0, ClassId 23, Archetype = 10 (MeleeDPS)
    --Sproutlings: nil name, nil archetype
    --Galactium Node: Archetype 29
    --Scorchwing: Elite 2, archetype 17 (Vehicle)

    --Rares table:
    --Name
    --Dead
    --Timestamp
    --Expires

    --Time table: { nDay, nDayOfWeek, nHour, nMonth, nSecond, nYear, strFormattedTime }

            --local strKilled = string.format("%s %s %s", name, strVerb, localTime.strFormattedTime)
