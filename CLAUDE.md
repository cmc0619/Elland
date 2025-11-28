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

**What We Did:**
- Removed `init.lua` placeholder files from zone folders (WordGarden, FashionDistrict, MathAcademy, CreativeCommons)
- Removed `$className: "Folder"` directives from zone definitions in `default.project.json`
- Added `.gitkeep` files to preserve empty directories in git

### Correct Rojo Patterns

**Pattern 1: Individual Lua file as ModuleScript/Script**
```json
"MyModule": {
  "$path": "src/MyModule.lua"
}
```
Rojo infers type from `.lua` or `.server.lua` or `.client.lua` extension.

**Pattern 2: Folder with contents**
```json
"MyFolder": {
  "$path": "src/MyFolder"
}
```
Rojo syncs entire folder. Type inferred from filesystem.

**Pattern 3: Explicit children without $path**
```json
"MyFolder": {
  "$className": "Folder",
  "Child1": { "$path": "src/Child1.lua" },
  "Child2": { "$path": "src/Child2.lua" }
}
```
Use when you want to organize Rojo structure differently from filesystem.

**Pattern 4: ModuleScript from init.lua**
```json
"MyModule": {
  "$path": "src/MyModule"
}
```
If `src/MyModule/init.lua` exists, this becomes a ModuleScript automatically.

## Project Structure Notes

### Zone Organization
- Each zone is a Folder in Workspace/Zones/
- Zone-specific content (models, scripts) will be added as children
- Zone logic scripts should be named descriptively (not `init.lua`) or placed in ServerScriptService

### Server Initialization Order
1. PlayerDataService - Must initialize first (data dependency)
2. CurrencyManager - Depends on PlayerDataService
3. ZoneManager - Can run after PlayerDataService
4. Other services - Add in dependency order

### Client-Server Communication
- RemoteEvents are created in server-side managers
- Stored in ReplicatedStorage for client access
- Client listens, server fires (for updates)
- Client fires, server validates (for requests)

## Git Configuration

### Working with Main Branch

**Important:** The main branch is protected. Claude can only push to branches starting with `claude/` by default.

To merge changes to main, Claude must ask the user for a GitHub personal access token:
```bash
git remote set-url origin https://TOKEN@github.com/cmc0619/Elland.git
```

**Process for Claude:**
1. When context restarts or token is forgotten, ask user: "I need the GitHub token to push to main"
2. User will provide the token (never write the actual token value to this file)
3. Configure remote with token using command above
4. Push to main

**Security Note:**
- Token is not persisted between Claude sessions (by design)
- Rotate the token periodically for security
- Token provides write access to the repository

## Development Workflow

### Making Changes
1. Edit files in your preferred editor
2. Save changes (Rojo auto-detects if `rojo serve` is running)
3. Sync in Roblox Studio (or enable auto-sync in Rojo plugin)
4. Test in Studio
5. Commit and push to main

### Testing Checklist
- [ ] Check Output window for errors on server start
- [ ] Verify player spawns at Hub
- [ ] Check HUD displays (currency, zone name)
- [ ] Test teleportation between zones
- [ ] Verify data saves/loads correctly

## Terrain and Positioning Lessons Learned

### Issue #2: Understanding Roblox Terrain FillBlock Positioning

**The Problem:**
When using `Terrain:FillBlock()`, the Y coordinate represents the CENTER of the block, not the bottom. This caused multiple issues:
- Water blocks appearing above the intended river surface
- Players spawning underground because terrain was positioned incorrectly
- Massive underground cross-sections visible when terrain was too tall

**Key Insights:**

1. **FillBlock Y-Coordinate is the CENTER:**
   ```lua
   -- If you want terrain from Y=0 to Y=10:
   terrain:FillBlock(
       CFrame.new(0, 5, 0),  -- Center at Y=5
       Vector3.new(600, 10, 600),  -- Height of 10 studs
       Enum.Material.Grass
   )
   -- This creates terrain from Y=0 to Y=10
   ```

2. **Keep Terrain Thin:**
   - Started with 100 studs tall → players spawned underground, massive underground volumes
   - Reduced to 20 studs → still too thick, visible cross-sections
   - Final: 10 studs (Y=0 to Y=10) → properly thin grass layer
   - **Lesson:** For a flat grassy field, 10-20 studs is plenty

3. **Spawn Positioning Relative to Terrain:**
   - Terrain: Y=0 to Y=10 (center at Y=5)
   - Ground level: Y=10 (top of terrain)
   - Platform base: Y=11 (1 stud above ground)
   - Spawn: Y=13 (2-3 studs above ground)
   - **Critical:** Set `spawn.CanCollide = true` or players fall through!

4. **Use Constants, Not Hardcoded Values:**
   ```lua
   -- BAD: Hardcoded values that can get out of sync
   local y = 3  -- This was causing river to appear at wrong height

   -- GOOD: Use centralized constants
   local y = Constants.WORLD.RIVER_START.Y  -- Always in sync
   ```

**What Went Wrong:**
- River creation used `local y = 3` instead of `Constants.WORLD.RIVER_START.Y`
- Water blocks were 6 studs tall, extending beyond terrain bounds
- When Constants were updated to Y=8, the hardcoded value wasn't updated

**The Fix:**
1. Changed river to use `riverStart.Y` from Constants
2. Reduced water block height from 6 to 3 studs
3. Result: Water stays within terrain bounds (Y=6.5 to Y=9.5), well below spawn at Y=12-13

### Issue #3: Iterative Testing and Debugging Process

**Testing Pattern That Works:**
1. Make a change
2. Sync with Rojo (verify in Studio Output)
3. Test in Studio (hit Play)
4. Check specific issues:
   - Can player spawn?
   - Is spawn solid (CanCollide)?
   - Is terrain at correct height?
   - Are water/other terrain materials positioned correctly?
5. If issues found, identify root cause before making next change
6. Commit working versions frequently

**Debugging Terrain Issues:**
- If player spawns underground → terrain center Y is too high
- If player falls through spawn → check `spawn.CanCollide = true`
- If massive underground blocks visible → terrain height is too large
- If water appears where it shouldn't → check FillBlock Y coordinate and height

## Common Issues

### DataStore Errors in Studio
DataStores don't work in local Studio testing by default. To enable:
1. Game Settings → Security → Enable Studio Access to API Services
2. Or use mock data service for local testing

### Player Doesn't Spawn
- Check ZoneManager initialized correctly
- Verify spawn locations exist in Workspace
- Check Output for CharacterAdded errors
- **Verify spawn.CanCollide = true** (players fall through if false!)

### Currency Not Updating
- Verify CurrencyChanged RemoteEvent exists in ReplicatedStorage
- Check server console for CurrencyManager errors
- Ensure client script is listening to OnClientEvent

### Terrain Positioning Issues
- Remember: FillBlock Y coordinate is the CENTER, not the bottom
- Keep terrain reasonably thin (10-20 studs for flat ground)
- Use Constants.lua for all positioning, never hardcode values
- Spawns should be 2-3 studs above the terrain top surface

## Future Improvements
- [ ] Add error handling for missing spawn locations
- [ ] Implement mock DataStore for offline testing
- [ ] Add admin commands for testing currency/zones
- [ ] Create zone templates for faster development
- [ ] Add automated tests for core systems

## Roblox Development Best Practices

Based on [Roblox Education Curriculum](https://create.roblox.com/docs/education/lesson-plans/roblox-developer-lesson):

### Code Organization
- **Proper indentation matters** - Makes code readable and maintainable
- **Accurate capitalization** - Roblox APIs are case-sensitive (`FindFirstChildWhichIsA`, not `findfirstchildwhichisa`)
- **Use functions for reusable code** - Don't repeat yourself
- **Organize with the Explorer hierarchy** - Parent-child relationships are crucial

### Testing and Iteration
- **Playtest with specific goals** - Don't just "play around", test specific features
- **Test early and often** - Catch issues before they compound
- **Iterate on design** - First version won't be perfect, improve based on testing
- **Balance is key** - Make games "challenging but fair" for target age group

### Variables and Data
- **Variables are placeholders** - Use descriptive names that explain their purpose
- **Strings store text** - Use for UI labels, player names, etc.
- **Understand data types** - Numbers, strings, booleans each have their place

### Problem Solving
- **Read error messages carefully** - They usually point to the exact problem
- **Check the Output window** - Lua errors and print statements appear here
- **Ask peers first** - Sometimes explaining the problem helps you solve it
- **Use print() for debugging** - Add print statements to track code execution

### Game Design Considerations
- **Think about your audience** - Elland is for an 11-year-old, keep complexity appropriate
- **Start simple, add complexity** - Get basic features working before adding advanced ones
- **Consider player motivation** - Why will players want to explore different zones?
- **Balance progression** - Currency and unlocks should feel rewarding but achievable

## Resources
- [Rojo Documentation](https://rojo.space/docs)
- [Roblox DataStore Guide](https://create.roblox.com/docs/cloud-services/data-stores)
- [Roblox Remote Events](https://create.roblox.com/docs/scripting/events/remote)
- [Roblox Education Curriculum](https://create.roblox.com/docs/education/lesson-plans/roblox-developer-lesson)

---

**Last Updated:** 2025-11-28
**Project Version:** 0.1.0
