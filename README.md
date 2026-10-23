# Plant Battles

Roblox game development repository for **Plant Battles**.

## Project Architecture & Structure

This project follows standard [Rojo](https://rojo.space/) conventions to synchronize code between VS Code and Roblox Studio:

```
Plant_Battles/
├── .gitignore
├── README.md
├── default.project.json
└── src/
    ├── server/                            --> ServerScriptService (33 scripts)
    │   ├── AcidPuddleHandler.server.luau
    │   ├── BananaHandler.server.luau
    │   └── ...
    ├── client/
    │   ├── StarterPlayerScripts/          --> StarterPlayer.StarterPlayerScripts (3 scripts)
    │   │   ├── CursorManager.client.luau
    │   │   ├── GardenClient.client.luau
    │   │   └── HUDClient.client.luau
    │   └── StarterCharacterScripts/       --> StarterPlayer.StarterCharacterScripts (28 scripts)
    │       ├── AbilityMenu.client.luau
    │       ├── GrappleClient.client.luau
    │       └── ...
    ├── shared/                            --> ReplicatedStorage
    │   └── PlantProgression.luau
    └── gui/                               --> StarterGui
        └── NatureHUD/
            └── WindowManager.client.luau
```

## Naming Conventions
- `*.server.luau`: Server-side scripts (Script)
- `*.client.luau`: Client-side scripts (LocalScript)
- `*.luau`: Shared / ModuleScripts (ModuleScript)

## Working with Rojo
1. Install the **Rojo** extension in VS Code.
2. In Roblox Studio, install and enable the **Rojo Plugin**.
3. In VS Code, start the Rojo server (`default.project.json`).
4. In Roblox Studio, click **Connect** in the Rojo plugin toolbar.
