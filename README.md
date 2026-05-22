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
- `/scenes/player`: Modular player scene
- `/scenes/ui`: Reusable inventory/hotbar UI scenes
- `/scenes/world`: Reusable interactable world scenes
- `/autoload`: Global gameplay state managers
- `/assets`: Placeholder assets
- `/data`: Configuration and task data

## Active Runtime

- Canonical flow: `scenes/main_menu.tscn` -> `scenes/main.tscn`
- Active gameplay path: `scripts/main.gd` + `scripts/map_system.gd`
- Active interaction path: `scenes/player/Player.tscn` + `scripts/player/player.gd` + child `InteractableComponent` nodes
- Current MVP world interactables in `main.tscn`: telescope task start, coffee machine crafting station, mug pickup, store NPC, bed, desk container, computer

## Deprecated / Legacy Paths

- `scripts/main_room.gd`
- `scripts/room.gd`
- `scripts/world/interactable.gd`

These legacy room and interaction scripts are no longer part of the canonical gameplay runtime.

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
- E: Interact
- Tab / I: Toggle inventory

### MVP Features

- 2-4 players
- Top-down movement
- Telescope object for "observe" task (only at night)
- UI showing current phase, player name, current task
- Starter quest progression for pickup -> crafting station use -> observation completion
- Coffee machine crafting station with `resources/recipes/coffee_recipe.tres`

## Extensibility

- Add new tasks by editing `/data/tasks.json`
- Add or change starter/runtime quest logic in `/scripts/objectives/quest_manager.gd`
- Add crafting recipes under `/resources/recipes/`
- Add new systems in `/scripts/systems/`
- Add new rooms in `/scenes/rooms/`
- Managers communicate via signals for decoupling

## Manual QA Checklist

- Pick up the mug in `main.tscn` and confirm the quest tracker updates
- Use the coffee machine and confirm the crafting UI opens and brewing coffee refreshes inventory
- Start the telescope observation at night and confirm current task / quest progress update
- Sleep in the bed and confirm the daily summary includes completed tasks and observation totals
- Save, reload, and verify world/UI state restores without runtime errors
- Host and join a session and verify the local player can still interact with world stations
