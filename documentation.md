# Beyond All Buttplug
An Internet of Sex Toys experimental project.
Published under GPL V2+ License

## Summary:
- The goal of this project is to produce a working proof-of-concept linkage between a physical vibrating device (sex toy or game pad) and the open-source RTS Beyond All Reason. The project is open source but limited copies will be officially distributed due to the sensitive and experimental nature of the work. There is no gurantee of anything working well or at all. Feel free to modify and/or distribute further at your own risk.


## Tech Stack:
- [Data Source](#data-source): Beyond All Reason engine
- [Data interpreter/exporter](#data-interpreterexporter): Beyond All Reason Lua Widget
- [Client](#client-egui--eframe): Rust egui + eframe
- [Software interface](#software-interface): Buttplug.io API
- [Hardware communication](#hardware-communication): Intiface
- [Effector](#effector): Intiface-compatible vibrating device

### Data Source:
Beyond All Reason is an open source game project developed on the Spring RTS engine. It is a spiritual successor to the game Total Annihilation, remastered with modern graphics and technologies. Most of the game data is easily accessible in real time with dev-supported tools and interfaces, such as the Widget system (see next point). Potential things to associate with vibration stimulus are:
- The player's "Commander", their main unit taking damage, destroying enemy units or using their signature weapon known as a "D-Gun"
- The player's units dealing damage
- The player constructing an expensive eco structure
- The player's economy performing poorly/well
- On-screen explosions (difficult)
- Other positive/negative stimulus for training purposes or just for fun

### Data Interpreter/exporter:
Widgets consist of Lua code that hook into the Spring engine. They are extremely powerful; capable of issuing real-time commands in the game simulation, writing text in-game or to files, and displaying graphics on the screen via GLSL shaders. There are currently almost no limits to their use in game, as long as they don't significantly lag out the simulation or issue too many commands. The project will be using one of these widgets to fill multiple roles:
- Determine the situations where the vibrator or other components should be turned on and off
- Communicate these actions to the wider system (currently via file-writes, updating up to 60 times/second)
- Potentially display indicators on screen when the device is activated/provide user-facing in-game settings that modify the vibration system (Not implemented)

Language: Lua

### Client: egui + eframe
egui is an extremely light weight and developer friendly UI package. The main advantages are that it's synchronous (async is painful to work with in Rust), has its own 60+/sec update loop, as well as being extremely easy to learn and use. egui is integrated into the eframe framework to provide a full application with GUI.

Language: Rust

#### The client's responsibilities: 
- File polling(in order to accept data from the BAR Lua Widget)
- Data sanitization and interpretation into commands
- Perform internal simulation on the effects of these commands (to yield an aggregate single value per motor/component that can be passed to the hardware)
- Communicate to the local Intiface server via the Buttplug API, as well as handle errors that occur
- Gracefully handle errors at all steps of this process, including shutting off the end device in the event of a sudden crash or stop condition (handled automatically by the Buttplug library).
#### The client's display:
- Connect/disconnect buttons
- Emergency stop
- The connection status/device
- Any error states that have occured
- A bar or other indicator of current motor values
- Debug information

Language: Rust

### Software Interface:

The Buttplug.io open-source software ecosystem provides a unified API and multiple libraries focused around communicating with various remote sex toy or vibration controller systems. It has been implemented into many games and software and serves as the main inspiration for this project. It allows for secure, regularly updated, and ever growing support for many common network protocols used by sex toys; in my case the Bluetooth Low Energy (BT4LE) protocol used by a low-end dual-motor vibrator purchased primarily for testing purposes. It also supports many higher-end app controlled devices (Lovense, Kiroo, etc), though they are currently out of my acceptable price range.

Language: Rust

### Hardware Communication:

Intiface is Buttplug.io's primary method of handling communication protocols with remote devices, serving as a locally-hosted server for the purposes of protocol management and secure communcation with such devices. It is a standalone application capable of running on desktop or android, and is open source and made by the same devs of Buttplug.io. The users of this project must have Intiface installed on their desktop and connect their sex toys via the Intiface application. The Beyond All Buttplug client will likewise needed to be connected to Intiface (intitiated from the client itself).

### Effector:

A device containing one or more vibration motors, capable of connecting remotely via an Intiface supported network protocol. Buttplug.io itself is protocol agnostic when paired with the Intiface system, allowing for many different devices to be controlled without significant developer overhead. This may include mundane items such as wireless game controllers, high end vibrators such as Lovense, Lelo, Kiroo etc, or much lower end ones that primarily use the aforementioned BT4LE protocol. Automated strokers and thrusters, as well as other more exotic devices may also be connected via Intiface, but are out of scope for the project at the moment.
