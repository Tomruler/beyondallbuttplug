# Beyond All Buttplug Client Application
A standalone desktop client for Windows 10+ that provides a basic, interactive control and debug window.

## Tech Stack
- Data Input/Parsing: Rust
- Simulation: Rust
- [External API Interface](#external-api-interface): Buttplug.io
- [Backend + Application builder](#backend--application-builder): Rust + Tauri
- [Frontend](#frontend): Javascript


### Data Input/Parsing
- Data is fed in via a text file updated in real time by the Lua widget. This file, "cmdlog.txt", is located in the \Beyond-All-Reason\data\LuaUI\Widgets\bpio folder. Each line contains one command for the Client to process and execute, with no gurantees on validity (the Client must clean and validate these commands before execution)
- Implementation: The Rust code reads this asynchronously on a single thread and operates read-only to prevent any race conditions.
### Simulation
- The internal simulation orchestrates the state of each end effector on the connected device based on recieved commands and runs at 60 frames/second. It handles the merging of different command inputs, falloff rates of vibration/other effects, and issues commands per update interval (ex: 10 times per second) to the end device via the Buttplug API.
- Implementation: This is also Rust code, and operates asynchronously with a clock using the Tokio package. Care must be taken about race conditions here, due to the need to rapidly update/delete/read from the same variables - the ARC rust package will help here by providing library functions that automatically handle concurrency issues for variables and simple data structures such as arrays.
### External API Interface
- Buttplug.io, as mentioned in the overall project documentation, is an open source API and library ecosystem designed to facilitate software communication with remote sex toys and other vibrating devices.
- The implementation used will be in Rust, as that is the language with the most guides and pre-existing code examples. It is also fast, efficient, lightweight and open source

### Backend + Application builder
- Tauri is a framework for building lightweight desktop applications with a Rust backend and web-based frontend. It accepts many front-end frameworks; in this case we will be using Javascript due to the language's ubiquity. 
- One advantage is that its quick-start commands/runner allow you to create a running application with very little setup. As this client will be extremely barebones in its first iteration, a solution like this is acceptable.
- Tauri using a Rust backend is also necessary to integrate with Buttplug.io

### Frontend
- Javascript is a basic and sufficiently capable language. The only front-end tasks needed of the client are to provide various buttons, display text, and potentially display images, all in a single window.