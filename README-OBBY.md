# Frank the Tank OBBY

A straight-line obstacle course (OBBY) for Roblox, built with Rojo 7 `.model.json` files and Luau game logic.

## Course Overview

A straight-line obstacle course along the X axis with 6 sections:

| Section | Location | Description |
|---------|----------|-------------|
| **1. Start Platform** | x=-80 to x=-60 | Large neon-green spawn platform |
| **2. Simple Jumps** | x=-60 to x=-30 | 5 floating platforms of decreasing size, each 3 studs higher |
| **3. Moving Platforms** | x=-30 to x=0 | 3 platforms sliding on Z axis — time your jumps |
| **4. Tricky Section** | x=-10 to x=30 | 3 thin yellow beams + 2 wider landing platforms |
| **5. Crumbling Run** | x=35 to x=80 | 10 red platforms that crumble 2s after you step on them |
| **6. Finish** | x=80 to x=100 | Gold platform with pillars + "FRANK THE TANK" billboard + fireworks |

### Features
- **Checkpoints** at key section boundaries (respawn on fall)
- **Timer** — starts when you hit the first checkpoint, stops at finish
- **Best time tracking** per player
- **Crumbling platforms** — stand too long and they fall
- **Moving platforms** — sliding on Z axis
- **Fireworks** celebration on completion

### Estimated Clear Time
~30 seconds for a casual player.

---

## What's New — Real 3D Models

The course is now built with **real 3D `.model.json` files** instead of procedural scripting. This means:

- ✅ **The world is visible in Studio immediately** — no need to press Play
- ✅ Parts have proper positions, sizes, materials, and colors
- ✅ Moving platforms have embedded server scripts
- ✅ Crumbling platforms have embedded server scripts
- ✅ Ground, death zone, checkpoints, and finish area are all real objects

### What's Still Scripted
- **Checkpoint detection** (touching a checkpoint updates your respawn point)
- **Timer** (starts on first checkpoint, stops at finish)
- **Fall detection** (respawns you at last checkpoint)
- **Finish detection** (triggers fireworks, updates billboard)
- **FRANK THE TANK billboard** (updates with your time on completion)

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
4. The game will sync — you'll see the full 3D course immediately
5. Press **Play** to run the course

### Option B: Build & Open

```bash
cd /opt/henderson/roblox-reference
rojo build --output frank-tank-obby.rbxlx
```

Then open `frank-tank-obby.rbxlx` in Roblox Studio.

### What Happens on Start

When the game runs (in studio playtest or live server):
1. `Main.server.lua` runs as entry point
2. `ObbyGameLogic.server.lua` sets up checkpoints, timer, fall detection, and the finish trigger
3. Moving platforms auto-move via embedded scripts
4. Crumbling platforms auto-destruct when touched via embedded scripts
5. The course is ready for players to run

### Testing

```bash
# Build to a temp file
rojo build --output /tmp/obby-test.rbxmx

# Lint all scripts
selene src/ServerScriptService/
```

---

## Project Structure

### `src/ServerScriptService/`
- **`Main.server.lua`** — Entry point, requires game logic
- **`ObbyGameLogic.server.lua`** — Module: checkpoints, timer, fall detection, finish logic

### `src/Workspace/ObbyCourse/`
- **`StartPlatform.model.json`** — Start platform part
- **`JumpPlatforms.model.json`** — Folder with 5 jump platforms
- **`MovingPlatforms.model.json`** — Folder with 3 moving platforms + embedded Scripts
- **`TrickySection.model.json`** — Folder with 3 beams + 2 landing platforms
- **`CrumblingPlatforms.model.json`** — Folder with 10 crumbling platforms + embedded Scripts
- **`Finish.model.json`** — Folder with finish platform + 4 corner pillars
- **`FinishTrigger.model.json`** — Finish line touch trigger part
- **`FrankTheTank.model.json`** — BillboardGui with title + subtitle
- **`Ground.model.json`** — Ground plane below the course
- **`DeathZone.model.json`** — Invisible kill plane below everything
- **`Checkpoints/`** — Folder with 3 neon checkpoint parts
- **`Obstacles/`** — Empty folder (reserved)

### Design
- All course geometry is defined in `.model.json` files synced by Rojo
- Game logic is in `ServerScriptService` with `--!strict` type checking
- Color theme: Cyan jumps, orange moving platforms, yellow tricky section, red crumbling, gold finish
