---@diagnostic disable: duplicate-set-field
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
--Acknowledgements:
--hihoman23: the "export data as csv" BAR widget, which served as the skeleton/reference for much of this code

local COM_ID

local globalPath = "LuaUI/Widgets/bpio/"
local frameInterval = 1 -- in frames
local printInterval = 2 -- in frames

local frame = 0
local lastProcessedFrame = 0
local isSpec
local teamList = Spring.GetTeamList()
local teamCount = 0

local corComDefID = UnitDefNames.corcom.id
local armComDefID = UnitDefNames.armcom.id

local corAfusDefID = UnitDefNames.corafus.id
local armAfusDefID = UnitDefNames.armafus.id

local spamUnitDefIDs = {
    ["tick"] = UnitDefNames.armflea.id,
    ["pawn"] = UnitDefNames.armpw.id,
    ["rover"] = UnitDefNames.armfav.id,
    ["grunt"] = UnitDefNames.corak.id,
    ["rascal"] = UnitDefNames.corfav.id,
}
-- local sp_GetPlayerInfo = Spring.GetPlayerInfo
-- local sp_GetTeamStatsHistory = Spring.GetTeamStatsHistory
-- local sp_GetAIInfo = Spring.GetAIInfo
-- local sp_GetTeamInfo = Spring.GetTeamInfo
-- local sp_GetGaiaTeamID = Spring.GetGaiaTeamID

local userComID

local userTeamID = Spring.GetLocalTeamID()
-- local playerTable = {}
local EVENT_BINDS = {
    ["INTERVAL"] = {
        ["PARAMS"] = { ["Interval"] = 10, ["Randomness"] = 2 },
        ["COMMAND"] = "VIBRATE",
        ["C_PARAMS"] = { ["Motor"] = -1, ["Strength"] = 0.2, ["Duration"] = 1 },
        ["C_PARAMS_SCALED"] = {["Strength"] = 1, ["Duration"] = 1}
    },
    ["ON_START"] = {
        ["PARAMS"] = {},
        ["COMMAND"] = "VIBRATE",
        ["C_PARAMS"] = { ["Motor"] = -1, ["Strength"] = 0.2, ["Duration"] = 5 },
        ["C_PARAMS_SCALED"] = {["Strength"] = 1},
    },
    ["ON_END"] = {
        ["PARAMS"] = {},
        ["COMMAND"] = "RESET",
        ["C_PARAMS"] = {}
    },
    ["ON_GET_KILL"] = {
        ["PARAMS"] = {},
        ["COMMAND"] = "VIBRATE",
        ["C_PARAMS"] = { ["Motor"] = -1, ["Strength"] = 0.1, ["Duration"] = 0.1 },
        ["C_PARAMS_SCALED"] = {["Strength"] = 1},
    },
    ["ON_LOSE_UNIT"] = {
        ["PARAMS"] = {},
        ["COMMAND"] = "VIBRATE",
        ["C_PARAMS"] = { ["Motor"] = -1, ["Strength"] = 0.1, ["Duration"] = 0.1 },
        ["C_PARAMS_SCALED"] = {["Strength"] = 1},
    },
    ["ON_BUILD_AFUS"] = {
        ["PARAMS"] = {},
        ["COMMAND"] = "VIBRATE",
        ["C_PARAMS"] = { ["Motor"] = -1, ["Strength"] = 0.5, ["Duration"] = 3 },
        ["C_PARAMS_SCALED"] = {["Strength"] = 1},
    },
    ["ON_COM_DAMAGED"] = {
        ["PARAMS"] = {},
        ["COMMAND"] = "VIBRATE",
        ["C_PARAMS"] = { ["Motor"] = -1, ["Strength"] = 0.2, ["Duration"] = 0.1 },
        ["C_PARAMS_SCALED"] = {["Strength"] = 1},
        ["QUANTITY_PER_SCALE_FACTOR"] = 100
    }

}

-- Commands recognized by the BAB client. Unsupported commands won't crash the client, but won't do anything either
local SUPPORTED_COMMANDS = {
    ["VIBRATE"] = true,
    ["POWER"] = true,
    ["RESET"] = true
}
-- Enabled by default. Binding events also enables them
local EVENT_ENABLED = 
{
    ["INTERVAL"] = false,
    ["ON_START"] = false,
    ["ON_END"] = true,
    ["ON_GET_KILL"] = false,
    ["ON_LOSE_UNIT"] = false,
    ["ON_BUILD_AFUS"] = false,
    ["ON_COM_DAMAGED"] = false,
}

local user_total_kills = 0
local user_total_losses = 0
local user_enemy_kill_counts = {}
local user_kills_by_unit_type = {}

local bab_event_CurrentIntervalTime = 0
local bab_event_IntervalTime = EVENT_BINDS["INTERVAL"]["PARAMS"]["Interval"] * 30
local bab_event_OldKills = 0
local bab_event_CurrentKills = 0
local bab_event_OldLosses = 0
local bab_event_CurrentLosses = 0
local bab_event_OldComHitpoints = 0
local bab_event_CurrentComHitpoints = 0
local bab_event_OldAfusCount = 0
local bab_event_BuiltAfusCount = 0


local function print_table(tbl, indent)
    indent = indent or 0
    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            Spring.Echo(formatting)
            print_table(v, indent + 1)
        else
            Spring.Echo(formatting .. tostring(v))
        end
    end
end

local function split_string(str, delim)
    if not str then
        Spring.Echo("Splitting nil string")
        return nil
    end
    if delim == nil then
        delim = "%s"
    end
    local t = {}
    for word in string.gmatch(str, "([^" .. delim .. "]+)") do
        t[#t+1] = word
    end
    -- Spring.Echo(str.." has been split into: \n" )
    -- print_table(t)
    return t
end

local function load_binds()
    local file = io.open(globalPath .. "bab_binds.txt", "r")
    -- Spring.Echo("Event binds table:")
    -- print_table(EVENT_BINDS, 1)
    if file then
        local bound_event
        for line in file:lines() do
            local line_words = split_string(line, nil)
            if line_words then
                if line_words[1] == "BIND" then --Add/configure client event
                    bound_event = line_words[2]
                    EVENT_ENABLED[bound_event] = true --All events in config are enabled by default
                    for i = 3, #line_words, 1 do
                        if EVENT_BINDS[bound_event] then
                            local param_pair = split_string(line_words[i], ":")
                            if not param_pair or #param_pair ~= 2 then
                                Spring.Echo("Invalid param when binding" .. bound_event)
                                break
                            end
                            if EVENT_BINDS[bound_event]["PARAMS"][param_pair[1]] then
                                EVENT_BINDS[bound_event]["PARAMS"][param_pair[1]] = param_pair[2]
                            else
                                Spring.Echo("Binding new parameter: " .. param_pair[1] .. "with value: " .. param_pair
                                    [2])
                                Spring.Echo("Are you sure this was spelled correctly?")
                                EVENT_BINDS[bound_event]["PARAMS"][param_pair[1]] = param_pair[2]
                            end
                        end
                    end
                    Spring.Echo("Event: "..bound_event.." has: "..#EVENT_BINDS[bound_event]["PARAMS"].." parameters bound")
                elseif line_words[1] == "TO" then --Add commands to event
                    local bound_command = line_words[2]
                    Spring.Echo("Binding new command: " .. bound_command .. " to event: " .. bound_event)
                    if not SUPPORTED_COMMANDS[bound_command] then
                        Spring.Echo(
                            "This command: "..bound_command.." is not listed as being supported. Are you sure this was spelled correctly?")
                    end
                    EVENT_BINDS[bound_event]["COMMAND"] = bound_command
                    for i = 3, #line_words, 1 do
                        -- print_table(EVENT_BINDS[bound_event]["C_PARAMS"],1)
                        local c_param_pair = split_string(line_words[i], ":")
                        if not c_param_pair or #c_param_pair ~= 2 then
                            Spring.Echo("Invalid param when binding command" .. bound_command)
                            break
                        end
                        -- print_table(EVENT_BINDS[bound_event]["C_PARAMS"],1)
                        if EVENT_BINDS[bound_event]["C_PARAMS"][c_param_pair[1]] then
                            -- Spring.Echo("Binding existing command parameter: " ..
                            --     c_param_pair[1] .. "with value: " .. c_param_pair[2])
                            EVENT_BINDS[bound_event]["C_PARAMS"][c_param_pair[1]] = c_param_pair[2]
                            -- print_table(EVENT_BINDS[bound_event]["C_PARAMS"],1)
                        else
                            Spring.Echo("Binding new command parameter: " ..
                                c_param_pair[1] .. "with value: " .. c_param_pair[2])
                            Spring.Echo("Are you sure the parameter: "..c_param_pair[1].." was spelled correctly?")
                            EVENT_BINDS[bound_event]["C_PARAMS"][c_param_pair[1]] = c_param_pair[2]
                            -- print_table(EVENT_BINDS[bound_event]["C_PARAMS"],1)
                        end
                    end
                    Spring.Echo("Command: "..bound_command.." has: "..#EVENT_BINDS[bound_event]["C_PARAMS"].." command parameters bound")
                end
            end
        end
    end
    Spring.Echo("Event binds table:")
    print_table(EVENT_BINDS, 1)
end

local playerTable = {}
local function createPlayerTable()
    for _, team in ipairs(teamList) do
        local playerName
        local _, leader, _, ai = Spring.GetTeamInfo(team)
        if leader then
            if ai then
                _, playerName = Spring.GetAIInfo(team)
            else
                playerName = Spring.GetPlayerInfo(leader)
            end
            if not playerName then
                playerName = "Player Not Found"
            end
        end
        playerTable[team] = playerName
    end
end

local function init_event_metrics()
    bab_event_CurrentIntervalTime = 0
    bab_event_IntervalTime = EVENT_BINDS["INTERVAL"]["PARAMS"]["Interval"] * 30
    bab_event_OldKills = 0
    bab_event_CurrentKills = 0
    bab_event_OldComHitpoints = 0
    bab_event_CurrentComHitpoints = 0
    bab_event_OldAfusCount = 0
    bab_event_BuiltAfusCount = 0
end

local queuedCommands = {}
local function append_queued_commands_to_file()
    if #queuedCommands == 0 then return end
    Spring.Echo(#queuedCommands .. " commands waiting to be written.")
    local file, err = io.open(globalPath .. "cmdlog.txt", "a")
    Spring.Echo(err)
    if file then
        for _, command in pairs(queuedCommands) do
            Spring.Echo("Writing to file: "..command)
            file:write(command, "\n")
        end
        queuedCommands = {}
        file:close()
    end
end

local function format_command_string(commandFrame, commandName, commandParams, scaling_factor, scaled_params)
    scaling_factor = scaling_factor or 1
    scaled_params = scaled_params or {}
    local assembled_command_string = commandFrame.." "
    assembled_command_string = assembled_command_string..commandName.." "
    if commandParams then
        for c_paramk, c_paramv in pairs(commandParams) do
            -- scale relevant parameters
            if scaled_params[c_paramk] then
                c_paramv = c_paramv * scaling_factor
            end
            assembled_command_string = assembled_command_string..c_paramk..":"..c_paramv.." "
        end
    end
    return string.sub(assembled_command_string, 1, #assembled_command_string-1)
end

local function insert_bound_command(commandFrame, eventName, scaling_factor)
    scaling_factor = scaling_factor or 1
    local commandName = EVENT_BINDS[eventName]["COMMAND"]
    if not commandName then
        Spring.Echo("No command bound to event: "..eventName)
        return nil 
    end
    local commandParams = EVENT_BINDS[eventName]["C_PARAMS"]
    local scaled_params = EVENT_BINDS[eventName]["C_PARAMS_SCALED"] or {}
    queuedCommands[#queuedCommands+1] = format_command_string(commandFrame, commandName, commandParams, scaling_factor, scaled_params)
end

local function bab_eventf_calc_kills()
    -- OLD: just here for convention
    return user_total_kills
end

local function bab_eventf_calc_losses()
    -- OLD: just here for convention
    return user_total_losses
end

local function bab_eventf_calc_afuses()
    -- OLD: just here for convention
    return bab_event_BuiltAfusCount
end
local function bab_eventf_calc_com_hitpoints()
    if Spring.ValidUnitID(userComID) then
        return Spring.GetUnitHealth(userComID)
    end
    return 0
end

local function do_metrics()
    local killed,died, _, _, _, _ = Spring.GetTeamUnitStats (userTeamID)
    user_total_kills = killed
    user_total_losses = died
    --Interval
    if EVENT_ENABLED["INTERVAL"] then
        bab_event_CurrentIntervalTime = bab_event_CurrentIntervalTime + frame - lastProcessedFrame
    end
    if EVENT_ENABLED["ON_GET_KILL"] then
        bab_event_CurrentKills = bab_eventf_calc_kills()
    end
    if EVENT_ENABLED["ON_LOSE_UNIT"] then
        bab_event_CurrentLosses = bab_eventf_calc_losses()
    end
    if EVENT_ENABLED["ON_BUILD_AFUS"] then
        bab_event_BuiltAfusCount = bab_eventf_calc_afuses()
        -- this if statement is now obsolete; BuiltAfusCount can never go down
        if bab_event_BuiltAfusCount < bab_event_OldAfusCount then
            bab_event_OldAfusCount = bab_event_BuiltAfusCount
        end
    end
    if EVENT_ENABLED["ON_COM_DAMAGED"] then
        bab_event_CurrentComHitpoints = bab_eventf_calc_com_hitpoints()
        if bab_event_CurrentComHitpoints > bab_event_OldComHitpoints then
            bab_event_OldComHitpoints = bab_event_CurrentComHitpoints
        end
    end
end

local function check_events()
    --Interval
    if EVENT_ENABLED["INTERVAL"] and bab_event_CurrentIntervalTime >= bab_event_IntervalTime then
        insert_bound_command(frame, "INTERVAL")
        Spring.Echo("Event: INTERVAL triggered on frame: "..frame)
        bab_event_CurrentIntervalTime = 0
        bab_event_IntervalTime = math.floor((EVENT_BINDS["INTERVAL"]["PARAMS"]["Interval"] + (math.random()-0.5) * EVENT_BINDS["INTERVAL"]["PARAMS"]["Randomness"]) * 30)
    end
    if EVENT_ENABLED["ON_GET_KILL"] and bab_event_CurrentKills > bab_event_OldKills then
        insert_bound_command(frame, "ON_GET_KILL", bab_event_CurrentKills - bab_event_OldKills)
        Spring.Echo("Event: ON_GET_KILL triggered on frame: "..frame)
        bab_event_OldKills = bab_event_CurrentKills
    end
    if EVENT_ENABLED["ON_LOSE_UNIT"] and bab_event_CurrentLosses > bab_event_OldLosses then
        insert_bound_command(frame, "ON_LOSE_UNIT", bab_event_CurrentLosses - bab_event_OldLosses)
        Spring.Echo("Event: ON_LOSE_UNIT triggered on frame: "..frame)
        bab_event_OldLosses = bab_event_CurrentLosses
    end
    if EVENT_ENABLED["ON_BUILD_AFUS"] and bab_event_BuiltAfusCount > bab_event_OldAfusCount then
        insert_bound_command(frame, "ON_BUILD_AFUS", bab_event_BuiltAfusCount - bab_event_OldAfusCount)
        Spring.Echo("Event: ON_BUILD_AFUS triggered on frame: "..frame)
        bab_event_OldAfusCount = bab_event_BuiltAfusCount
    end
    if EVENT_ENABLED["ON_COM_DAMAGED"] and bab_event_CurrentComHitpoints < bab_event_OldComHitpoints then
        insert_bound_command(frame, "ON_COM_DAMAGED", 
            (bab_event_CurrentComHitpoints - bab_event_OldComHitpoints)/EVENT_BINDS["ON_COM_DAMAGED"]["QUANTITY_PER_SCALE_FACTOR"])
        Spring.Echo("Event: ON_COM_DAMAGED triggered on frame: "..frame)
        bab_event_OldComHitpoints = bab_event_CurrentComHitpoints
    end
end

local function process_events(force)
    if frame % frameInterval == 0 or force then
        do_metrics()
        check_events()

        lastProcessedFrame = frame
    end
end

local function bab_reset(fromAction)
    Spring.Echo("Emergency Stop Triggered")
    insert_bound_command(frame, "ON_END")
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    -- Something built by player
    if unitTeam == userTeamID then
        if unitDefID == armAfusDefID or unitDefID == corAfusDefID then
            bab_event_BuiltAfusCount = bab_event_BuiltAfusCount + 1
        end
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    -- if unitTeam then
    --     if unitTeam == userTeamID then
    --         Spring.Echo("Your unit just died")
    --         user_total_losses = user_total_losses + 1
    --     end
    -- end
    
    -- if not unitDefID then
    --     Spring.Echo("Something died without a unitDefID")
    --     return
    -- end
    -- if not attackerTeam then
    --     Spring.Echo(UnitDefs[unitDefID].name .. "was killed by unknown team")
    -- end
    -- if not attackerDefID then
    --     Spring.Echo("Attacker def unknown")
    -- end
    -- if attackerID then
    --     Spring.Echo(attackerID.." got a kill")
    --     local teamUnitTable = Spring.GetTeamUnits(userTeamID)
    --     if teamUnitTable then
    --         if teamUnitTable[attackerID] then
    --             Spring.Echo("This is your unit")
    --         end
            
    --     end
    -- else
    --     Spring.Echo("AttackerID missing as well")
    -- end
    -- if not attackerTeam or not unitDefID or not attackerDefID then
    --     return
    -- end
    -- -- TODO: Check if Gaia triggers this so random debris/trees aren't recorded
    -- -- Player killed a unit
    -- Spring.Echo("Unit has died. Killed by team: "..attackerTeam)
    -- if attackerTeam == userTeamID then
    --     user_total_kills = user_total_kills + 1
    --     Spring.Echo("Player has: "..user_total_kills.. " kills")
    --     if not attackerDefID then
    --         Spring.Echo("An unknown player unit killed a"..UnitDefs[unitDefID].name)
    --         return 
    --     end
    --     -- Add kill to overall player kills of a unit type
    --     if not user_enemy_kill_counts[unitDefID] then
    --         user_enemy_kill_counts[unitDefID] = 0
    --     end
    --     user_enemy_kill_counts[unitDefID] = user_enemy_kill_counts[unitDefID] + 1
    --     -- Add kill to player's killcount by a specific unit
    --     if not user_kills_by_unit_type[attackerDefID] then
    --         user_kills_by_unit_type[attackerDefID] = 0
    --     end
    --     user_kills_by_unit_type[attackerDefID] = user_kills_by_unit_type[attackerDefID] + 1
    -- end
    -- -- Don't care about other kills
end

function widget:GameFrame(n)
    frame = n
    -- Spring.Echo("Frame: "..frame)
    -- teamCount = 0
    process_events(false)
    if frame % printInterval == 0 then
        append_queued_commands_to_file()
    end
    if frame % 600 == 0 then
        
        -- print_table(sp_GetTeamStatsHistory(0))
    end
    -- Spring.GetTeamUnitsByDefs(0, )
end

local function reset_event_file()
    local file, err = io.open(globalPath .. "cmdlog.txt", "w")
    Spring.Echo(err)
    if file then
        file:close()
    else --not sure if this is necessary
        file = io.open(globalPath .. "cmdlog.txt", "w")
        if file then
            file:close()
        end
    end
end

function widget:Initialize()
    isSpec = Spring.GetSpectatingState()
    if isSpec then
        Spring.Echo("Spectator events are currently not supported.")
        widgetHandler:RemoveWidget(self)
        return
    end
    -- timeInterval = timeInterval*30
    widgetHandler:AddAction("emergency device stop", bab_reset, nil, "p")
    load_binds()
    init_event_metrics()
    reset_event_file()
    
    Spring.Echo("Team ID List:")
    for _, teamID in ipairs(teamList) do
        Spring.Echo("Team: ", teamID)
    end
    createPlayerTable()
    print_table(playerTable, 1)
    Spring.Echo("Arm commander UnitDefID: "..armComDefID)
    Spring.Echo("Cor commander UnitDefID: "..corComDefID)
end

function widget:GameStart()
    -- createPlayerTable()
    insert_bound_command(0, "ON_START")
    Spring.Echo("Looking for commanders")
    -- jank, refactor and consider multi-com scenarios
    local userComIDs = Spring.GetTeamUnitsByDefs(userTeamID, {armComDefID, corComDefID})
    if userComIDs and #userComIDs > 0 then
        userComID = userComIDs[1]
        Spring.Echo("Commander unitID: "..userComID)
        if Spring.ValidUnitID(userComID) then
            Spring.Echo("[Commander info: ]")
            print_table(
                {
                    health = Spring.GetUnitHealth(userComID),
                    exp = Spring.GetUnitHealth(userComID),
                },
                1
            )
        else
            Spring.Echo("Invalid commander unitID")
        end
    
    else
        Spring.Echo("No commanders found")
    end
end

function widget:GameOver()
    -- saveData()
    -- Spring.Echo("Game Over")
    -- insert_bound_command(frame, "ON_END")
    -- append_queued_commands_to_file()
    -- Spring.Echo("Finished writing last commands to file")
end

function widget:Shutdown()
    Spring.Echo("Game Over")
    insert_bound_command(frame, "ON_END")
    append_queued_commands_to_file()
    Spring.Echo("Finished writing last commands to file")
end
