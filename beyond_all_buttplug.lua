function widget:GetInfo()
    return {
      name = "Beyond All Buttplug",
      desc = "Buttplug.io integration for Beyond All Reason",
      author = "Tomruler",
      date = "2024",
      license = "GNU GPL, v2 or later",
      layer = 0,
      enabled = false
    }
end

-- Notes for next time:
-- Store commands and output as key-value pairs, where value is a list containing the command then the params
-- By default initialize the basic commands, as well as keep them in the default config file
-- Each command stored in the list should be a line including the frame-based timestamp, the client command and its params (not messing with JSON since that's a pain)
-- Make individual functions per command?
-- Diagnostics?
-- One way communication with client? (BAR write only, client read only?)
-- Maybe save old file each time - probably not
-- File stores entire history? - sure
-- Client time travel? What about pauses/dropped frames? Do frames scale with time dilation?
-- Test game sim stepping

local globalPath = "LuaUI/Widgets/bpio/"
local frameInterval = 10 -- in frames
-- local timeInterval = 10 -- in seconds, will get converted to frames later
-- local ignoreList = {
--     time = true,
--     frame = true,
--     unitsOutCaptured = true
-- }

-- local data = {}
local frame = 0
-- local isSpec
-- local teamList = Spring.GetTeamList()
-- local teamCount = 0

local GetPlayerInfo = Spring.GetPlayerInfo
local GetTeamStatsHistory = Spring.GetTeamStatsHistory
local GetAIInfo = Spring.GetAIInfo
local GetTeamInfo = Spring.GetTeamInfo
local GetGaiaTeamID = Spring.GetGaiaTeamID

local playerTable = {}
local EVENT_BINDS = {
    ["INTERVAL"] = {
        ["PARAMS"] = {["Interval"] = 10, ["Randomness"] = 2},
        ["COMMAND"] = "VIBRATE",
        ["C_PARAMS"] = {["Motor"]=-1, ["Strength"]=0.2, ["Duration"]=1}
    },
    ["ON_START"] = {
        ["PARAMS"] = {},
        ["COMMAND"] = "VIBRATE",
        ["C_PARAMS"] = {["Motor"]=-1, ["Strength"]=0.2, ["Duration"]=5}
    },
    ["ON_END"] = {
        ["PARAMS"] = {},
        ["COMMAND"] = "RESET",
        ["C_PARAMS"] = {}
    }
}
local SUPPORTED_COMMANDS = {
    "VIBRATE",
    "POWER",
    "RESET"
}

local function split_string(str, delim)
    if not str then 
        Spring.Echo("Splitting nil string")
        return nil 
    end
    if delim == nil then
        delim = "%s"
    end
    local t={}
    for word in string.gmatch(str, "([^"..delim.."]+)") do
        table.insert(t, word)
    end
    return t
end

local function load_binds()
    local file = io.open(globalPath.."bab_binds.txt", "r")
    if file then
        local bound_event
        for line in file:lines() do
            local line_words = split_string(line, nil)
            if line_words then
                if line_words[1] == "BIND" then
                    bound_event = line_words[2]
                    for i=2, #line_words, 1 do
                    if EVENT_BINDS[bound_event] then
                        local param_pair = split_string(line_words[i], ":")
                        if not param_pair or #param_pair ~= 2 then
                            Spring.Echo("Invalid param when binding"..bound_event)
                            break
                        end
                        local existing_param_name = EVENT_BINDS[bound_event]["PARAMS"][param_pair[1]]
                        if existing_param_name then
                            EVENT_BINDS[bound_event]["PARAMS"][existing_param_name] = param_pair[2]
                        else
                            Spring.Echo("Binding new parameter: "..param_pair[1].."with value: "..param_pair[2])
                            Spring.Echo("Are you sure this was spelled correctly?")
                            EVENT_BINDS[bound_event]["PARAMS"][param_pair[1]] = param_pair[2]
                        end
                    end
                end
            end
        end
    end
end

local queuedCommands = {}
-- local function createPlayerTable()
--     for _, team in ipairs(teamList) do
--         local playerName
--         local _, leader, _, ai = GetTeamInfo(team)
--         if leader then
--             if ai then
--                 _, playerName = GetAIInfo(team)
--             else
--                 playerName = GetPlayerInfo(leader)
--             end
--             if not playerName then
--                 playerName = "Player Not Found"
--             end
--         end
--         playerTable[team] = playerName
--     end
-- end

-- local function lines_from(file)
--     if not file then return {} end
    
-- end

local function append_queued_commands_to_file()
    local file = io.open(globalPath.."cmdlog.txt", "a")
    if file then
        for command in queuedCommands do
            file:write(command)
        end
        queuedCommands = {}
        file:close()
    end
end


-- local function checkLock()
--     local file = io.open(globalPath.."lock.txt", "r")
--     if file then
--         file:close()
--     end
-- end

-- local function tableToCSV(tbl, name, finalFrame)
--     local file = io.open(globalPath..name, "w")
--     if file then
--         local heading = ""
--         for i = 0, finalFrame, timeInterval do
--             heading = heading .. i/1800 .. ","
--         end
--         if not ((finalFrame%timeInterval)==0) then
--             heading = heading .. finalFrame/1800
--         end
--         for stat, globalData in pairs(tbl) do
--             file:write(stat.."\n")
--             file:write("AllyTeamID,TeamID,Player Name,"..heading.."\n")
--             for i = 0, teamCount - 1 do
--                 local team = i
--                 local data = globalData[team]
--                 local _, _, _, _, _, allyTeamID = GetTeamInfo(team)

--                 if playerTable[team] then
--                     local dataString = allyTeamID..","..team..","..playerTable[team] .. ","
--                     for _, val in ipairs(data) do
--                         dataString = dataString .. val .. ","
--                     end
--                     dataString = dataString .. "\n"
--                     file:write(dataString)
--                 end
--             end
--             file:write("\n")
--         end
--         file:close()
--     end
-- end

local function addStats(hist)
    hist.damageEfficiency = 0
    if not (hist.damageReceived == 0) then
        hist.damageEfficiency = (hist.damageDealt/hist.damageReceived)*100
    end

    return hist
end

local function createTable()
    teamCount = 0
    local dataTable = {}
    local finalFrame
    timeInterval = math.ceil(timeInterval/450)
    for _,teamID in ipairs(teamList) do
        if teamID ~= GetGaiaTeamID() then
            local range = GetTeamStatsHistory(teamID)
            local history = GetTeamStatsHistory(teamID,0,range)
            if history then
                teamCount = teamCount + 1
                for i = 1, range, timeInterval do
                    for stat, val in pairs(addStats(history[i])) do
                        if not ignoreList[stat] then
                            local statTable = dataTable[stat]
                            if statTable then
                                local playerStat = dataTable[stat][teamID]
                                if playerStat then
                                    playerStat[#playerStat+1] = val
                                else
                                    statTable[teamID] = {val}
                                end
                            else
                                dataTable[stat] = {[teamID] = {val}}
                            end
                        end
                    end
                end
                if not ((range%timeInterval)==0) then
                    for stat, val in pairs(history[#history]) do
                        if stat == "frame" then
                            finalFrame = val
                        end
                        if not ignoreList[stat] then
                            local playerStat = dataTable[stat][teamID]
                            if playerStat then
                                playerStat[#playerStat+1] = val
                            end
                        end
                    end
                end
                if not finalFrame then
                    finalFrame = range
                end
            end
        end
    end
    data = dataTable
    timeInterval = timeInterval*450
end

local function addCurrentData(force)
    if ((frame%timeInterval)==0) or force then
        for _,teamID in ipairs(teamList) do
            if teamID ~= GetGaiaTeamID() then
                local range = GetTeamStatsHistory(teamID)
                local history = GetTeamStatsHistory(teamID,0,range)
                if history then
                    teamCount = teamCount + 1
                    history = history[#history]

                    for stat, val in pairs(addStats(history)) do
                        if not ignoreList[stat] then
                            local statTable = data[stat]
                            if statTable then
                                local playerStat = data[stat][teamID]
                                if playerStat then
                                    playerStat[#playerStat+1] = val
                                else
                                    statTable[teamID] = {val}
                                end
                            else
                                data[stat] = {[teamID] = {val}}
                            end
                        end
                    end
                end
            end
        end
    end
end

function widget:GameFrame(n)
    frame =  n
    teamCount = 0
    addCurrentData(false)
end

local function createName()
    local mapName = Game.mapName
    local timeDate = os.date("%Y-%m-%d_%H-%M".."_"..mapName..".csv")
    return timeDate
end

local function saveData(fromAction)
    if isSpec then
        addCurrentData(true)
    else
        createTable()
        Spring.Echo("Save will be more low resolution")
    end
    tableToCSV(data, createName(), frame)
    Spring.Echo("Resource Data Saved")
end

function widget:Initialize()
    timeInterval = timeInterval*30
    widgetHandler:AddAction("save_resource_data", saveData, nil, "p")

    isSpec = Spring.GetSpectatingState()
end

function widget:GameStart()
    createPlayerTable()
end


function widget:GameOver()
    saveData()
end