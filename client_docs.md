# Beyond All Buttplug Client Application
A standalone desktop client for Windows 10+ that provides a basic, interactive control and debug window.

## Tech Stack
- Data Input/Parsing: Rust
- Simulation: Rust
- [External API Interface](#external-api-interface): Buttplug.io
- [Backend + Application builder](#backend--application-builder): Rust
- [Frontend](#frontend): egui (Rust)


### Data Input/Parsing
- Data is fed in via a text file updated in real time by the Lua widget. This file, "cmdlog.txt", is located in the \Beyond-All-Reason\data\LuaUI\Widgets\bpio folder. Each line contains one command for the Client to process and execute, with no gurantees on validity (the Client must clean and validate these commands before execution)
- Implementation: The Rust code reads this synchronously on a single thread and operates read-only to prevent any race conditions.
### Simulation
- The internal simulation orchestrates the state of each end effector on the connected device based on recieved commands and runs at 60 frames/second. It handles the merging of different command inputs, falloff rates of vibration/other effects, and issues commands per update interval (ex: 10 times per second) to the end device via the Buttplug API.
- Implementation: Piggybacks off the GUI code to update 60 times per second, inside the update method.
### External API Interface
- Buttplug.io, as mentioned in the overall project documentation, is an open source API and library ecosystem designed to facilitate software communication with remote sex toys and other vibrating devices.
- The implementation used will be in Rust, as that is the language with the most guides and pre-existing code examples. It is also fast, efficient, lightweight and open source

### Backend + Application builder
- No longer applicable; the program now operates as a single thread combining IO, simulation and UI.

### Frontend
- egui is an an extremely light weight, Rust-only GUI system useful for small projects like this. It operates synchronously, updating 60 frames per second, and processes user interactions with an update loop. Being synchronous makes this application far easier to code and debug than any async solution.