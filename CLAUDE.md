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
This project uses a GitHub personal access token to push directly to main:
```bash
git remote set-url origin https://TOKEN@github.com/cmc0619/Elland.git
```

**Security Note:** Rotate the token periodically for security.

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

## Common Issues

### DataStore Errors in Studio
DataStores don't work in local Studio testing by default. To enable:
1. Game Settings → Security → Enable Studio Access to API Services
2. Or use mock data service for local testing

### Player Doesn't Spawn
- Check ZoneManager initialized correctly
- Verify spawn locations exist in Workspace
- Check Output for CharacterAdded errors

### Currency Not Updating
- Verify CurrencyChanged RemoteEvent exists in ReplicatedStorage
- Check server console for CurrencyManager errors
- Ensure client script is listening to OnClientEvent

## Future Improvements
- [ ] Add error handling for missing spawn locations
- [ ] Implement mock DataStore for offline testing
- [ ] Add admin commands for testing currency/zones
- [ ] Create zone templates for faster development
- [ ] Add automated tests for core systems

## Resources
- [Rojo Documentation](https://rojo.space/docs)
- [Roblox DataStore Guide](https://create.roblox.com/docs/cloud-services/data-stores)
- [Roblox Remote Events](https://create.roblox.com/docs/scripting/events/remote)

---

**Last Updated:** 2025-11-28
**Project Version:** 0.1.0
