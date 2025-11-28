# Elland - Multi-Activity Game World for Roblox

**Elland** is an open-ended Roblox game world featuring multiple activity zones designed for mature 11-year-olds. Players can freely explore word puzzles, fashion design, building, and algebra games with a shared economy and progression system.

## 🎮 Game Features

- **Open-Ended Gameplay**: All zones accessible from start - no forced progression
- **Multiple Activity Zones**:
  - 🌱 **Word Garden**: Word puzzles and vocabulary challenges
  - 👗 **Fashion District**: Avatar customization and style showcases
  - 🧮 **Math Academy**: Algebra games and number puzzles
  - 🏗️ **Creative Commons**: Building and design tools
- **Shared Economy**: Earn currency from any activity, spend anywhere
- **Persistent Data**: Progress, creations, and preferences saved across sessions
- **Modular Design**: Each zone is self-contained and easily expandable

## 🛠️ Tech Stack

- **[Rojo](https://rojo.space/)**: File sync between filesystem and Roblox Studio
- **Lua**: All game logic
- **ModuleScripts**: Reusable, maintainable systems

## 📁 Project Structure

```
elland/
├── default.project.json          # Rojo configuration
├── src/
│   ├── ServerScriptService/
│   │   ├── Init.server.lua       # Main server initialization
│   │   ├── PlayerDataService.lua # DataStore wrapper for player data
│   │   ├── CurrencyManager.lua   # Economy system
│   │   └── ZoneManager.lua       # Teleportation & zone management
│   ├── ReplicatedStorage/
│   │   ├── Shared/
│   │   │   └── Constants.lua     # Shared game constants
│   │   └── Modules/              # Shared modules (future use)
│   ├── StarterPlayer/
│   │   └── StarterPlayerScripts/
│   │       └── ClientController.lua  # Main client script
│   ├── StarterGui/
│   │   └── UI/                   # UI components (future)
│   └── Workspace/
│       └── Zones/
│           ├── WordGarden/       # Word puzzle zone
│           ├── FashionDistrict/  # Fashion zone
│           ├── MathAcademy/      # Math games zone
│           └── CreativeCommons/  # Building zone
└── README.md
```

## 🚀 Getting Started

### Prerequisites

1. **Install Rojo**
   ```bash
   # Windows (using Foreman - recommended)
   foreman install

   # Or download from https://github.com/rojo-rbx/rojo/releases
   ```

2. **Install Roblox Studio**
   - Download from [roblox.com/create](https://www.roblox.com/create)

3. **Install Rojo Plugin**
   - Install the [Rojo plugin](https://rojo.space/docs/v7/getting-started/installation/#installing-the-plugin) in Roblox Studio

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/[username]/Elland.git
   cd Elland
   ```

2. **Start Rojo server**
   ```bash
   rojo serve
   ```
   This will start a local server (default: `localhost:34872`)

3. **Open Roblox Studio**
   - Create a new Baseplate or open existing place
   - Click the **Rojo** plugin button in the toolbar
   - Click **Connect** and enter `localhost:34872`
   - Click **Sync In** to sync the project files

4. **Test the game**
   - Press F5 or click Play in Roblox Studio
   - You should spawn at the Central Hub
   - Check the Output window for initialization messages

## 🎯 Core Systems

### PlayerDataService
Manages player data persistence using Roblox DataStores:
- Auto-save every 5 minutes
- Saves on player leave
- Handles data loading/saving with retry logic
- Stores currency, progress, zone data, and settings

### CurrencyManager
Unified economy system across all zones:
- Award currency for completing activities
- Handle purchases and transactions
- Track earnings by zone and activity
- Client-server sync via RemoteEvents

### ZoneManager
Handles zone teleportation and management:
- All zones accessible from start (no gates)
- Automatic spawn location creation
- Hub serves as central meeting point
- Client can request teleportation to any zone

### ClientController
Main client-side initialization:
- Creates basic HUD (currency, zone display)
- Listens for server events
- Manages local UI state
- Handles zone changes and notifications

## 🔧 Development Workflow

### Making Changes

1. **Edit files** in your text editor
2. **Save** - Rojo will automatically detect changes
3. **Sync** in Roblox Studio (or enable auto-sync in plugin)
4. **Test** in Studio

### Adding a New Zone

1. Create folder in `src/Workspace/Zones/YourZone/`
2. Add zone configuration to `Constants.lua`
3. Create zone-specific logic in a ModuleScript
4. Update `default.project.json` to include the new zone

### Adding a New System

1. Create ModuleScript in appropriate folder
2. Add initialization in `Init.server.lua`
3. Update `Constants.lua` if needed
4. Create RemoteEvents in system if client communication needed

## 📊 Game Design Principles

1. **No Forced Progression**: Players choose their own path
2. **Modular Zones**: Each activity is self-contained
3. **Shared Economy**: Currency works across all zones
4. **Age-Appropriate**: Designed for mature 11-year-olds
5. **Safe & Positive**: Encouraging learning through play

## 🎨 Future Enhancements

- [ ] Implement Word Garden puzzle mechanics
- [ ] Add Fashion District avatar customization
- [ ] Create Math Academy problem generator
- [ ] Build Creative Commons building tools
- [ ] Add friends/social features
- [ ] Implement achievements system
- [ ] Create leaderboards
- [ ] Add music and sound effects
- [ ] Design custom UI themes
- [ ] Implement daily challenges

## 🧪 Testing

Currently uses manual testing in Roblox Studio. Future plans:
- Unit tests for core systems
- Integration tests for data persistence
- Playtesting with target age group

## 📝 Code Style

- Use PascalCase for module names and services
- Use camelCase for local variables and functions
- Add comments for complex logic
- Keep functions focused and modular
- Follow Roblox Lua best practices

## 🤝 Contributing

This is a learning project, but suggestions are welcome!

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

[Add your license here]

## 👤 Author

[Your name/username]

## 🙏 Acknowledgments

- Built with [Rojo](https://rojo.space/)
- Inspired by educational game design principles
- Created for young learners who love games

---

**Happy building! Welcome to Elland!** 🌟
