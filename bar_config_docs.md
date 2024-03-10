# Beyond All Buttplug Widget Documentation
A Lua based modification (mod) integrated into the Beyond All Reason application that communicates in-game states to external applications via text file logging.

## Usage
- Extract the "bab.zip" zip folder into your BAR installation, in the subdirectory Beyond-All-Reason\data\LuaUI\Widgets
- The folder contains:
- bab.lua: The mod folder
- Place the bab.lua file inside
- TODO

## Config File
- Each bind consists of a BAR event followed by optional params, then a BAB event followed by optional params
- BAR events are mapped to things happening in game, BAB events are interpreted by the Client as commands for the connected vibrators/other devices
- The format is: \
BAR_EVENT PARAM1:VALUE PARAM2:VALUE ... PARAMN:VALUE \
BAB_EVENT PARAM1:VALUE PARAM2:VALUE ... PARAMN:VALUE
- Invalid event binds are ignored and noted in the logs; duplicate binds overwrite the oldest. There is currently no support for multiple binds per event.

## Supported BAR Events
- INTERVAL
- ON_START
- ON_END
## Supported BAB Events
- VIBRATE
- POWER
- RESET

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

### BAB EVENT: VIBRATE
- Enables one or more vibration motors on the connected device for a pulse. By default, it activates all motors at 20% power, falling off rapidly. 
- NOTE: Vibration power stacks - multiple pulses close together/overlapping combine their output power. This can be toggled.
- Params:
    - Motor: Which Motor (-1 for all, 0 for 1st, 1 for 2nd etc)
    - Strength: Strength (between 0 and 1, floating point)
    - Duration: Hold duration (how many seconds to vibrate at this power before falling off)

### BAB EVENT: POWER
- Set the power of one or more vibration motors on the connected device permanantly. By default sets 10%.
- Resets after receiving another POWER command with 0%
- NOTE: Stacks with other vibration commands
- Params:
    - Motor: Which Motor (-1 for all, 0 for 1st, 1 for 2nd etc)
    - Strength: Strength (between 0 and 1, floating point)

### BAB EVENT: RESET
- Disables all motors and clears any queued/ongoing events. Useful as an emergency shut-off.