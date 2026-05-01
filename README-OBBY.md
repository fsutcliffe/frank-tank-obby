# Frank the Tank OBBY

A procedurally-generated obstacle course (OBBY) for Roblox, built with Luau and Rojo.

## Course Overview

A straight-line obstacle course along the X axis with 6 sections:

| Section | Location | Description |
|---------|----------|-------------|
| **1. Start Platform** | x=-80 to x=-60 | Large spawn platform with neon trim |
| **2. Simple Jumps** | x=-60 to x=-30 | 5 floating platforms of decreasing size, each 2.5 studs higher |
| **3. Moving Platforms** | x=-30 to x=0 | 3 platforms sliding on Z axis — time your jumps |
| **4. Tricky Section** | x=0 to x=30 | 1-stud-wide beams + rising wall jumps (wedges) |
| **5. Crumbling Run** | x=30 to x=60 | Platforms that destroy 2s after you step on them |
| **6. Finish** | x=60 to x=80 | Gold platform + "FRANK THE TANK" billboard + fireworks |

### Features
- **Checkpoints** at key section boundaries (respawn on fall)
- **Timer** — starts when you hit the first checkpoint, stops at finish
- **Best time tracking** per player
- **Crumbling platforms** — stand too long and they fall
- **Fireworks** celebration on completion

### Estimated Clear Time
~30 seconds for a casual player.

---

## How to Use

### Prerequisites
- [Roblox Studio](https://create.roblox.com/)
- [Rojo](https://rojo.space/) (`rojo serve` or `rojo build`)
- (Optional) [Selene](https://github.com/Kampfkarren/selene) for linting

### Option A: Rojo Serve (Live Sync)

```bash
cd /opt/henderson/roblox-reference
rojo serve
```

1. Open Roblox Studio
2. Click the **Rojo** plugin tab → **Connect**
3. Enter the address shown by `rojo serve` (default: `127.0.0.1:6587`)
4. The game will sync and the scripts will build the course on start

### Option B: Build & Open

```bash
cd /opt/henderson/roblox-reference
rojo build --output frank-tank-obby.rbxlx
```

Then open `frank-tank-obby.rbxlx` in Roblox Studio.

### What Happens on Start

When the game runs (in studio playtest or live server):
1. `Main.server.lua` runs as entry point
2. `ObbyBuilder.server.lua` procedurally generates all platforms, obstacles, beams, and decorations
3. `ObbyGameLogic.server.lua` sets up checkpoints, timer, fall detection, crumbling platforms, and the finish trigger
4. The course is ready for players to run

### Testing

```bash
# Lint all scripts
selene src/ServerScriptService/

# Build to a temp file
rojo build --output /tmp/obby-test.rbxlx
```

---

## Script Architecture

### `src/ServerScriptService/`
- **`Main.server.lua`** — Entry point, requires builder and game logic
- **`ObbyBuilder.server.lua`** — Module: procedurally builds all course parts
- **`ObbyGameLogic.server.lua`** — Module: checkpoints, timer, fall detection, finish logic

### Design
- All course geometry is generated at runtime via `Instance.new("Part")`
- Color theme: Neon purple/cyan/pink with gold finish
- No external dependencies or asset files needed
- All scripts use `--!strict` type checking
