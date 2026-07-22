# Claude Development Notes

This file contains lessons learned and important notes for AI assistants working on this project.

## Rojo Configuration Lessons Learned

### Issue #1: Conflicting $className and $path directives

**Error Message:**
```
ClassName for Instance "CreativeCommons" was specified in both the project file (as "Folder")
and from the filesystem (as "ModuleScript").
If $className and $path are both set, $path must refer to a Folder.
```

**Root Cause:**
In Rojo, when a directory contains an `init.lua` file, Rojo automatically infers it as a ModuleScript. If you also specify `$className: "Folder"` in the project file, this creates a conflict.

**Solution:**
1. **If you want a Folder:** Remove the `init.lua` file from the directory, or use only `$path` without `$className`
2. **If you want a ModuleScript:** Remove the `$className: "Folder"` directive and let Rojo infer it from the `init.lua` file

**Key Rojo Rules:**
- Directory + `init.lua` = ModuleScript (Rojo infers automatically)
- Directory without `init.lua` = Folder (when using `$path`)
- When using `$path`, let Rojo infer the type from filesystem structure
- Only use explicit `$className` when pointing to a specific `.lua` file or when you need to override inference

**Current state:** The world is entirely code-generated, so `default.project.json` maps only scripts/modules - no Workspace model folders. The Build Tool is created in code too (`BuildingSandbox:GiveBuildTool`); its behavior lives in the `BuildToolClient` LocalScript in StarterPlayerScripts so no Script needs to be nested inside a Tool instance (Script source can't be authored at runtime).

### Correct Rojo Patterns

**Pattern 1: Individual Lua file as ModuleScript/Script**
```json
"MyModule": {
  "$path": "src/MyModule.lua"
}
```

**Pattern 2: Folder with contents**
```json
"MyFolder": {
  "$path": "src/MyFolder"
}
```

**Pattern 3: Explicit children without $path**
```json
"MyFolder": {
  "$className": "Folder",
  "Child1": { "$path": "src/Child1.lua" },
  "Child2": { "$path": "src/Child2.lua" }
}
```

## Project Structure Notes

### World Generation
- The entire world is built by code on every server start - there is no "run once in Studio" step
- `WorldBuilder:BuildWorld()` builds terrain/river/hill/structures/spawns and sets `Workspace:GetAttribute("WorldBuilt")`
- Right after, `Init.server.lua` runs the additional builders in order (all destroy any previous copy of their output folder first, so they stay idempotent):
  1. `PolishBuilder` - Lighting (Atmosphere/ColorCorrection/Bloom/SunRays, ClockTime 17.2, ShadowMap), Clouds, Hub-to-zone cobble paths (they bridge the river), lampposts, Hub fountain
  2. `NatureBuilder` - Seeded (`NATURE.TREE_SEED`) tree/flower scatter with keep-outs (river, paths, hill+swing, zone structures, all attraction areas)
  3. `BuildingSandbox`, `ObbyManager`, `SoccerManager`, `StageManager`, `NutcrackerBuilder`, `FamilyBuilder` - the attractions
- `WorldUtils` provides `DistanceToRiver` (recomputes the meander from `Constants.WORLD`), `DistanceToSegment2D`, and `DistanceToNearestPath` - reuse these for any new scatter/placement logic
- Terrain:FillCylinder's axis runs along the CFrame's **Z axis** - rotate 90 degrees to make horizontal layers. For cylinder PARTS, the axis runs along the part's **X axis** - rotate about Z (`CFrame.Angles(0, 0, math.rad(90))`) to stand them up (fountain basin, candy canes, nutcracker hat)

### Positions and Constants
- All attraction positions/sizes/rewards/cooldowns live in `Constants` (`LIGHTING`, `NATURE`, `PATHS`, `HUB`, `BUILDING_SANDBOX`, `OBBY`, `SOCCER`, `STAGE`, `NUTCRACKER`, `FAMILY`) - never hardcode coordinates in builders
- New attractions were placed far from the river diagonal (RIVER_START (-300,-100) to RIVER_END (300,100) passes through the Hub with a ±30-stud meander). Always check `WorldUtils:DistanceToRiver` before placing anything new near the map center

### Economy and Rewards
- ALL currency awards go through `CurrencyManager:AddCurrency` server-side with per-player cooldown tables keyed by `UserId` (obby winner 5 min, soccer goal 1 min, stage perform 2 min, sandbox rate limit 0.15 s)
- Cooldown/state tables are cleaned up in `Players.PlayerRemoving`

### Leaderstats
- `ObbyManager` creates `leaderstats["Obby Stage"]`; `SoccerManager` adds `leaderstats["Goals"]`. Both create the `leaderstats` folder if missing and guard with `FindFirstChild`, so init order between them doesn't matter
- `ZoneManager` only teleports to the Hub on the FIRST `CharacterAdded` per player - later respawns belong to the Obby checkpoint system (it teleports the character to its highest checkpoint pad after death)

### Notifications
- Server modules fire the shared `NotifyPlayer` RemoteEvent (created by `NutcrackerBuilder` if missing); `ClientController:ShowNotification(text)` renders a toast. Reuse this for any new one-liner world events

### Building Sandbox
- Blocks are session-only (`Workspace/PlayerBuilds/<UserId>`), cap 200/player, 2-stud grid snap, owner-only delete. Persistence via `Constants.BUILDING`/DataStore is future work

### Stage Audio
- `Constants.STAGE.CHOIR_SONGS` is intentionally EMPTY. Never invent audio asset IDs - the owner uploads/licenses audio and pastes `rbxassetid://...` IDs; `StageManager` only plays when the list is non-empty

### Server Initialization Order (as implemented in Init.server.lua)
1. PlayerDataService - Must initialize first (data dependency)
2. CurrencyManager - Depends on PlayerDataService
3. WorldBuilder:BuildWorld() - Terrain/structures/spawns BEFORE anything that needs them
4. PolishBuilder, NatureBuilder - Visual pass on top of the base world
5. BuildingSandbox, ObbyManager, SoccerManager, StageManager - Attractions (currency-aware ones receive CurrencyManager)
6. NutcrackerBuilder, FamilyBuilder - Decorative corners
7. ZoneManager - Needs the spawn locations WorldBuilder created
8. WordleManager - Depends on PlayerDataService and CurrencyManager
9. InteractionManager - Waits on the `WorldBuilt` attribute, then creates ProximityPrompts

### Client-Server Communication
- RemoteEvents are created in server-side managers (at module load where clients `WaitForChild` them, e.g. `BuildPlaceRequest`, `NotifyPlayer`)
- Client fires, server validates (placement, purchases); server fires, client renders (currency, notifications, UI opens)

## Git Configuration

Commits go directly to `main`. **CRITICAL:** Always push commits to remote immediately - the user only sees what's pushed to GitHub.

## Development Workflow

### Testing Checklist
- [ ] Check Output window for errors on server start
- [ ] Verify player spawns at Hub, lighting looks warm, clouds visible
- [ ] HUD displays (currency, zone name); M opens the zone map
- [ ] Wordle round and boutique purchase still work
- [ ] Build Tool: place/delete in-plot only, grid snap, cap, Clear My Plot
- [ ] Obby: checkpoints, checkpoint respawn after death, winner cooldown
- [ ] Soccer: kick direction, goal scoring, ball reset watchdog
- [ ] Stage: Perform! cooldown + billboard; Nutcracker tree toast
- [ ] Swing still swings; no trees/grass in the river

## Terrain and Positioning Lessons Learned

### Issue #2: FillBlock Y is the CENTER, not the bottom
- Base terrain Y=0 to Y=10 (center Y=5); ground level `Constants.WORLD.GROUND_LEVEL = 10`
- Spawn locations need `CanCollide = true` or players fall through

### Issue #3: River/Water Construction
- Carve with Air FIRST (wider), Sand bed SECOND, Water THIRD; water surface at Y=9.8
- `CreateRiver` runs after the hill pass so carving removes hill grass from the water
- Keep all new scatter/structures out of the channel: use `WorldUtils:IsNearRiver(pos, clearance)`

## Common Issues

### DataStore/Wordle API Errors in Studio
Enable **Game Settings → Security → Enable Studio Access to API Services**; otherwise PlayerDataService falls back to default data and Wordle uses its offline list.

### Player Doesn't Spawn
Check ZoneManager init, spawn locations exist in Workspace, and `spawn.CanCollide = true`.

### Currency Not Updating
Verify `CurrencyChanged` RemoteEvent exists and the client listener is connected.

### Obby respawns at the wrong place
ZoneManager must stay "Hub on first spawn only" - if it teleports on every CharacterAdded it will fight the Obby checkpoint respawn.

## Future Improvements
- [ ] Fashion Boutique: apply purchased items visually to the character
- [ ] Persist Building Area builds via DataStore
- [ ] Owner-provided stage songs (`Constants.STAGE.CHOIR_SONGS`)
- [ ] Add zone icons to Constants.ZONES
- [ ] Implement mock DataStore for offline testing
- [ ] Add admin commands for testing currency/zones
- [ ] Add automated tests for core systems

## Roblox Development Best Practices

- **Use `task.*` library** - `task.wait()`, `task.spawn()`, `task.delay()`; never deprecated `wait()`/`spawn()`
- **No `_G`** - share via ModuleScripts and RemoteEvents
- **Server-authoritative economy** - clients request, the server validates and pays
- **Playtest with specific goals** - test each attraction's full loop (reward + cooldown)
- **Think about your audience** - Elland is for an 11-year-old; keep mechanics simple and forgiving

## Resources
- [Rojo Documentation](https://rojo.space/docs)
- [Roblox DataStore Guide](https://create.roblox.com/docs/cloud-services/data-stores)
- [Roblox Remote Events](https://create.roblox.com/docs/scripting/events/remote)

---

**Last Updated:** 2025-11-29
**Project Version:** 0.2.0
