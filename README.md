# AstroValley

A modular multiplayer framework for 2D pixel-art games using Godot 4.x.

## Features

- LAN multiplayer with client-server architecture
- Server-authoritative time system with day phases
- Data-driven task system
- Shared resource locking
- Modular architecture with autoload managers

## Project Structure

- `/scenes`: Game scenes
- `/scripts/core`: Core managers (autoloads)
- `/scripts/systems`: Gameplay systems
- `/scripts/entities`: Game entities
- `/assets`: Placeholder assets
- `/data`: Configuration and task data

## Running the Game

### Prerequisites

- Godot 4.x

### Hosting a Game

1. Open the project in Godot Editor.
2. Run the project.
3. In the console or via script, call `NetworkManager.host_game(4242)` to start hosting on port 4242.

### Joining a Game

1. Open the project in Godot Editor.
2. Run the project.
3. Call `NetworkManager.join_game("192.168.1.100", 4242)` where "192.168.1.100" is the host's IP.

### Controls

- Arrow keys or WASD: Move
- Space: Interact with objects (e.g., telescope)

### MVP Features

- 2-4 players
- Top-down movement
- Telescope object for "observe" task (only at night)
- UI showing current phase, player name, current task

## Extensibility

- Add new tasks by editing `/data/tasks.json`
- Add new systems in `/scripts/systems/`
- Add new rooms in `/scenes/rooms/`
- Managers communicate via signals for decoupling