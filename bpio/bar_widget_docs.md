# Beyond All Buttplug Widget Documentation
A Lua based modification (mod) integrated into the Beyond All Reason application that communicates in-game states to external applications via text file logging.

## Usage
- Extract the "bab.zip" zip folder into your BAR installation, in the subdirectory Beyond-All-Reason\data\LuaUI\Widgets
- The folder contains:
- ``bpio/``: The mod's data folder
- ``bpio/bab_binds.txt``: User configurable binding for event configuration
- ``bpio/cmdlog.txt``: Contains each command sent to the Client for execution. The main way the Lua code communicates with the wider system.
- ``bpio/bab_client.exe``: Client that interprets commands and provides debug/control features. Used to run the Buttplug.io library.
- ``beyond_all_buttplug.lua``: The widget itself. Handles event binding, identifying events in game, and communicating commands to the client.

## Config File
- Each bind consists of a BAR event followed by optional params, then a BAB event followed by optional params
- BAR events are mapped to things happening in game, BAB events are interpreted by the Client as commands for the connected vibrators/other devices
- The format is: \
BIND BAR_EVENT PARAM1:VALUE PARAM2:VALUE ... PARAMN:VALUE \
TO BAB_EVENT PARAM1:VALUE PARAM2:VALUE ... PARAMN:VALUE
- Invalid event binds are ignored and noted in the logs; duplicate binds overwrite the oldest. There is currently no support for multiple binds per event.

## Supported BAR Events
- (✅: Working,🛠️: Experimental ❌: Not working)
- [INTERVAL](#bar-event-interval)✅
- [ON_START](#bar-event-on_start)✅
- [ON_END](#bar-event-on_end)✅
- [ON_BUILD_AFUS](#bar-event-on_build_afus)✅
- [ON_GET_KILL](#bar-event-on_get_kill)✅
- [ON_LOSE_UNIT](#bar-event-on_lose_unit)🛠️
- [ON_COM_DAMAGED](#bar-event-on_com_damaged)✅
## Supported BAB Events
- [VIBRATE](#bab-event-vibrate)✅
- [POWER](#bab-event-power)✅
- [RESET](#bab-event-reset)✅

# BAR EVENTS

### BAR EVENT: INTERVAL
- Trigger once every time period, default 10 seconds (600 sim frames)
- Params:
    - Interval: Interval time (seconds)
    - Randomness: Randomness (seconds)

### BAR EVENT: ON_START
- Trigger at game start (after commanders spawn in)
- Params: N/A

### BAR EVENT: ON_END
- Triggers at game end
- Params: N/A

### BAR EVENT: ON_BUILD_AFUS
- Triggers once an advanced fusion reactor is completed by the player
- Params: N/A

### BAR EVENT: ON_GET_KILL
- Triggers when the player's kill count increases
- Params: N/A

### BAR EVENT: ON_LOSE_UNIT
- Triggers when the player loses a unit. Currently includes reclaimed units and unbuilt structures.
- Params: N/A

### BAR EVENT: ON_COM_DAMAGED
- Triggers whenever the player's commander takes damage
- Params: N/A

# BAB EVENTS

### BAB EVENT: VIBRATE
- Enables one or more vibration motors on the connected device for a pulse. By default, it activates all motors at 20% power, falling off rapidly. 
- NOTE: Vibration power stacks - multiple pulses close together/overlapping combine their output power. This can be toggled.
- Params:
    - Motor: Which Motor (-1 for all, 0 for 1st, 1 for 2nd etc)
    - Strength: Strength (between 0 and 1, floating point)
    - Duration: Hold duration (how many seconds to vibrate at this power before falling off)

### BAB EVENT: POWER
- Set the power of one or more vibration motors on the connected device permanantly (5 minutes). By default sets 10%.
- Resets after receiving another POWER command with 0%
- NOTE: Stacks with other vibration commands
- Params:
    - Motor: Which Motor (-1 for all, 0 for 1st, 1 for 2nd etc)
    - Strength: Strength (between 0 and 1, floating point)

### BAB EVENT: RESET
- Disables all motors and clears any queued/ongoing events. Useful as an emergency shut-off.