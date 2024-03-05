# Beyond All Buttplug Client Application
A standalone desktop client for Windows 10+ that provides a basic, interactive control and debug window.

## Tech Stack
- External API interface: Buttplug.io
- Backend/Application builder: Rust + Tauri
- Frontend: Javascript

### External API Interface
- Buttplug.io, as mentioned in the overall project documentation, is an open source API and library ecosystem designed to facilitate software communication with remote sex toys and other vibrating devices.
- The implementation used will be in Rust, as that is the language with the most guides and pre-existing code examples. It is also fast, efficient, lightweight and open source

### Backend/Application builder
- Tauri is a framework for building lightweight desktop applications with a Rust backend and web-based frontend. It accepts many front-end frameworks; in this case we will be using Javascript due to the language's ubiquity. 
- One advantage is that its quick-start commands/runner allow you to create a running application with very little setup. As this client will be extremely barebones in its first iteration, a solution like this is acceptable.
- Tauri using a Rust backend is also necessary to integrate with Buttplug.io

### Frontend
- Javascript is a basic and sufficiently capable language. The only front-end tasks needed of the client are to provide various buttons, display text, and potentially display images, all in a single window.