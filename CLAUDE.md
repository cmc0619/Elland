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
  2. `NatureBuilder` - Seeded (`NATURE.TREE_SEED`) tree/flower scatter with keep-outs (river, paths, hill+swing, zone structures, all attraction areas including Pet Corner, the Bake Shop, and the Algebra Academy)
  3. `BuildingSandbox`, `ObbyManager`, `SoccerManager`, `StageManager`, `TalentShowManager`, `NutcrackerBuilder`, `FamilyBuilder`, `PetManager`, `BakeryManager`, `HuntManager`, `AlgebraManager` - the attractions
  4. `SeasonManager` - seasonal overlay LAST among builders (it decorates what the others built: lampposts, canopies, plaza snow)
- `WorldUtils` provides `DistanceToRiver` (recomputes the meander from `Constants.WORLD`), `DistanceToSegment2D`, and `DistanceToNearestPath` - reuse these for any new scatter/placement logic
- Terrain:FillCylinder's axis runs along the CFrame's **Z axis** - rotate 90 degrees to make horizontal layers. For cylinder PARTS, the axis runs along the part's **X axis** - rotate about Z (`CFrame.Angles(0, 0, math.rad(90))`) to stand them up (fountain basin, candy canes, nutcracker hat, cupcake wrappers)

### Positions and Constants
- All attraction positions/sizes/rewards/cooldowns live in `Constants` (`LIGHTING`, `NATURE`, `PATHS`, `HUB`, `BUILDING_SANDBOX`, `OBBY`, `SOCCER`, `STAGE`, `TALENT_SHOW`, `NUTCRACKER`, `SEASONS`, `ALGEBRA`, `FAMILY`, `PETS`, `BAKERY`, `HUNT`) - never hardcode coordinates in builders. New sections should be purely additive tables like these
- New attractions were placed far from the river diagonal (RIVER_START (-300,-100) to RIVER_END (300,100) passes through the Hub with a ±30-stud meander). Always check `WorldUtils:DistanceToRiver` before placing anything new near the map center
- When adding a structure anywhere the NatureBuilder scatter might reach, add a keep-out circle in `NatureBuilder`'s `buildKeepOuts()` (see the PETS/BAKERY/ALGEBRA entries)

### Economy and Rewards
- ALL currency awards go through `CurrencyManager:AddCurrency` server-side with per-player cooldown tables keyed by `UserId` (obby winner 5 min, soccer goal 1 min, stage perform 2 min, talent show 10 min server-wide, sandbox rate limit 0.15 s, bake perfect bonus 2 min, Linear Lab 5 min + 10-coin session cap, graph bonus 5 min)
- Cooldown/state tables are cleaned up in `Players.PlayerRemoving`

### Wave 2: Talent Show (TalentShowManager / TalentShowUI)
- Extends Ella's Stage (requires StageManager to init first - it looks up `Workspace.EllasStage`)
- Server-managed state machine: one `activeShow` table; `task.delay` opens the voting window (last 30s) and ends the show; a host leaving mid-show triggers `EndShow` via PlayerRemoving
- Remotes: `TalentShowEvent` (server→all: phases start/voting/end) + `TalentShowVote` (client→server: "applause"/"star", rate-limited 1/sec per player server-side, performer blocked)
- Payout: `min(floor(totalVotes / VOTES_PER_COIN), MAX_COINS)`; persists `TalentShowsHosted` / `BestApplause` (migration-safe DEFAULT_DATA fields)
- TalentShowUI only opens for non-hosts during the voting phase; client debounce mirrors the server limit

### Wave 2: Seasons (SeasonManager / Constants.SEASONS)
- Data-driven: `SEASONS.ORDER` = priority list, `SEASONS.LIST[id]` = date window + decoration fields. Date windows are INCLUSIVE and wrap the new year when StartMonth > EndMonth (see `isInWindow`)
- Runs at server start only (os.date), after Polish/Nature/Nutcracker so it can find lampposts (`Polish` folder: `LamppostPole`/`LamppostHead`), tree canopies (`Nature` folder: parts named `Canopy`), and the plaza snow (`NutcrackerPlaza.SnowEmitter`)
- WINTER boosts the plaza's EXISTING emitter rate - never adds a duplicate. Adding Halloween/Spring = LIST entry + ORDER entry (+ one new apply-step only if a new decoration TYPE is needed)

### Wave 2: Algebra Academy (AlgebraManager / AlgebraUI / GraphUI / EquationParser)
- Linear Lab is LINEAR-ONLY **by construction**: the 4 generators build problems from slope-intercept pieces; there is no quadratic generator to accidentally pick. Keep it that way - the easel may graph quadratics, the practice problems may never include them
- Session flow mirrors the bakery's two-step pattern: `AlgebraStartRequest` → `AlgebraSession` (payload = prompts + options ONLY; correctIndex stays server-side) → `AlgebraAnswer(choiceIndex)` → `AlgebraAnswerResult`. Never send the correct index to the client before it answers
- `GraphBonusRequest(equationText)` pays +2 Coins only after the SERVER re-parses the string with the shared `EquationParser` module - never trust the client's "it was valid"
- `Shared/EquationParser.lua` is required by BOTH server and client (`ReplicatedStorage.Shared.EquationParser`). Trick: `gsub("%-", "+-")` then split on `+` gives signed terms; each term is `coeff .. varPart` where varPart ∈ {"x^2", "x", ""}. Empty-term cases ("y=x+", "++") are explicitly rejected
- GraphUI renders into the easel board's SurfaceGui (`Workspace.AlgebraAcademy.GraphBoard.GraphPaperGui.GraphArea`) LOCALLY - workspace edits from a client don't replicate, which gives every player their own view for free. Lines = one clipped rotated Frame; parabolas = 40 sampled segments; math.atan2 for segment rotation (screen Y points down)

### Pet Corner (PetManager / PetUI / PetFollow)
- Catalog: `Constants.PETS.LIST` (Id/Name/Cost/Description/BodyColor/AccentColor); server builds its price catalog from it - client sends only the petId
- Remotes (created at module load): `OpenPetUI`, `PetPurchaseRequest`/`PetPurchaseResult`, `PetEquipRequest`/`PetEquipResult`. `PetEquipRequest` with NO petId = dismiss
- Data: `Pets` (array of IDs) + `ActivePet` in DEFAULT_DATA; `mergeData` migrates old saves
- Follow trick: the server spawns an ANCHORED model in `Workspace/Pets` with an `OwnerUserId` attribute and positions it once; `PetFollow.client.lua` lerps every pet on Heartbeat toward a point behind its owner's replicated character (+ sine bob). Zero per-frame network traffic, smooth for every viewer. Never make pet parts collidable

### Ella's Bake Shop (BakeryManager / BakeShopUI)
- Recipes: `Constants.BAKERY.ITEMS`; baking is an activity, not a plain purchase
- Two-step flow: `BakeStartRequest` (validate recipe/ownership/funds, stamp `os.clock()`) -> client minigame (progress bar + one timed button per `BAKERY.STEPS` entry) -> `BakeCompleteRequest(itemId, perfectClicks)`. Server rejects completions faster than `BAKERY.MIN_COMPLETION_TIME`, charges on completion only, saves to `BakeryItems`
- Perfect bonus (+5 Coins when every step clicked in time) has a 2-minute per-player cooldown - do not make it farmable

### Music Note Hunt (HuntManager / HuntClient)
- `Constants.HUNT.NOTES` = 10 positions, none underwater (checked against the river meander)
- Touch collection is once per player, persisted (`HuntNotes` array of indexes, `HuntCompleted` flag); the server ignores repeat touches, so notes never respawn for that player
- Per-player visibility: server fires `HuntNoteUpdate(collectedIndexes, completed, total)` on join (after data load) and after each pickup; `HuntClient` hides those notes LOCALLY (Transparency/emitters/lights) and shows a HUD counter. Hiding is local-only so other players still see their own uncollected notes

### Leaderstats
- `ObbyManager` creates `leaderstats["Obby Stage"]`; `SoccerManager` adds `leaderstats["Goals"]`. Both create the `leaderstats` folder if missing and guard with `FindFirstChild`, so init order between them doesn't matter
- `ZoneManager` only teleports to the Hub on the FIRST `CharacterAdded` per player - later respawns belong to the Obby checkpoint system (it teleports the character to its highest checkpoint pad after death)

### Notifications
- Server modules fire the shared `NotifyPlayer` RemoteEvent (created by `NutcrackerBuilder` if missing - newer modules use the same `FindFirstChild`-or-create pattern); `ClientController:ShowNotification(text)` renders a toast. Reuse this for any new one-liner world events (TalentShowManager and AlgebraManager already do)

### Building Sandbox
- Blocks are session-only (`Workspace/PlayerBuilds/<UserId>`), cap 200/player, 2-stud grid snap, owner-only delete. Persistence via `Constants.BUILDING`/DataStore is future work

### Stage Audio
- `Constants.STAGE.CHOIR_SONGS` is intentionally EMPTY. Never invent audio asset IDs - the owner uploads/licenses audio and pastes `rbxassetid://...` IDs; `StageManager` only plays when the list is non-empty

### Server Initialization Order (as implemented in Init.server.lua)
1. PlayerDataService - Must initialize first (data dependency)
2. CurrencyManager - Depends on PlayerDataService
3. WorldBuilder:BuildWorld() - Terrain/structures/spawns BEFORE anything that needs them
4. PolishBuilder, NatureBuilder - Visual pass on top of the base world
5. BuildingSandbox, ObbyManager, SoccerManager, StageManager, TalentShowManager - Attractions (currency/data-aware ones receive the managers; TalentShow needs the stage built)
6. NutcrackerBuilder, FamilyBuilder - Decorative corners
7. PetManager, BakeryManager, HuntManager, AlgebraManager - Persistent-data attractions (receive PlayerDataService + CurrencyManager)
8. SeasonManager - Decorates what steps 3-7 built (lampposts, canopies, plaza snow)
9. ZoneManager - Needs the spawn locations WorldBuilder created
10. WordleManager - Depends on PlayerDataService and CurrencyManager
11. InteractionManager - Waits on the `WorldBuilt` attribute, then creates ProximityPrompts

### Client-Server Communication
- RemoteEvents are created in server-side managers (at module load where clients `WaitForChild` them, e.g. `BuildPlaceRequest`, `NotifyPlayer`, `PetPurchaseRequest`, `HuntNoteUpdate`, `TalentShowEvent`, `AlgebraSession`, `GraphBonusRequest`)
- Client fires, server validates (placement, purchases, adoptions, bakes, votes, answers, graph bonuses); server fires, client renders (currency, notifications, UI opens, note hiding, voting panels)
- New UI modules follow the FashionUI pattern: ModuleScript in StarterPlayerScripts with `CreateUI/Open/Close/Init`, required and initialized by `ClientController` inside a pcall; the module waits on its own remotes in `Init`. Standalone client behaviors (PetFollow, HuntClient) are `.client.lua` LocalScripts that don't need ClientController wiring

## Git Configuration

Commits go directly to `main`. **CRITICAL:** Always push commits to remote immediately - the user only sees what's pushed to GitHub.

## Development Workflow

### Testing Checklist
- [ ] Check Output window for errors on server start
- [ ] Verify player spawns at Hub, lighting looks warm, clouds visible
- [ ] HUD displays (currency, zone name); M opens the zone map
- [ ] Wordle round and boutique purchase still work
- [ ] Pet Corner: adopt, follow/bob, switch, dismiss, respawn persistence
- [ ] Bake Shop: minigame completes, timing sanity holds, recipe saved, bonus cooldown
- [ ] Hunt: note pays + toasts, counter updates, hidden after rejoin, completion confetti
- [ ] Build Tool: place/delete in-plot only, grid snap, cap, Clear My Plot
- [ ] Obby: checkpoints, checkpoint respawn after death, winner cooldown
- [ ] Soccer: kick direction, goal scoring, ball reset watchdog
- [ ] Stage: Perform! cooldown + billboard; Nutcracker tree toast
- [ ] Talent Show: host → all-player toast, voting panel for others in last 30s, rate limit, payout + confetti + results, 10-min cooldown, host-leave ends show
- [ ] Algebra: 5 linear-only questions, server-side scoring, +2/correct (cap 10), 5-min cooldown, stats persist; easel graphs `y=2x+1` / `y=x^2-4` / `x=-2`, friendly error on garbage, +2 first-graph bonus
- [ ] Winter window (or temp test window): map snow, fairy lights, canopy tint, boosted plaza snow
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

### Pet doesn't follow / appears frozen
The server only positions the pet once - movement is `PetFollow.client.lua` pivoting models in `Workspace/Pets` each Heartbeat. If pets freeze, check that the model has the `OwnerUserId` attribute and that PetFollow found the `Pets` folder (it waits 30s).

### Talent Show voting panel never appears
The panel opens only for NON-host players when the server broadcasts `phase = "voting"` - in solo Studio testing you are the host, so the panel correctly stays hidden. Test with 2+ players (Studio: Test → Start 2 Players).

### Graph doesn't draw on the easel
GraphUI looks up `Workspace.AlgebraAcademy.GraphBoard.GraphPaperGui.GraphArea` at render time. Check AlgebraManager initialized (the folder exists) and that the parse succeeded (error label shows the friendly message otherwise).

## Future Improvements
- [ ] Fashion Boutique: apply purchased items visually to the character
- [ ] Pet accessories / tricks
- [ ] Persist Building Area builds via DataStore
- [ ] Owner-provided stage songs (`Constants.STAGE.CHOIR_SONGS`)
- [ ] Add zone icons to Constants.ZONES
- [ ] More seasons: Halloween/Spring entries in `Constants.SEASONS` (data-only)
- [ ] Implement mock DataStore for offline testing
- [ ] Add admin commands for testing currency/zones
- [ ] Add automated tests for core systems (EquationParser is pure and the easiest first target)

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

**Last Updated:** 2025-12-01
**Project Version:** 0.4.0
