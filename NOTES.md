# PepperDash Essentials v2 + Mobile Control — Implementation Notes

## Repository Structure

### PepperDash Essentials
- **Repo**: https://github.com/PepperDash/Essentials
- **Active branch**: `development` (NOT `main` — that is legacy v1.x)
- **Latest release**: v2.28.0 (tag on `development` commits, not from `main`)
- **Future**: `dev/3.x` branch targets .NET 8
- **Target framework**: .NET Framework 4.7.2 (`net472`)

### Mobile Control UI
- **Repo**: https://github.com/PepperDash/mobile-control-react-app-core
- **Stack**: React 18, Redux Toolkit, Vite, TypeScript
- **Protocol**: HTTP room join → WebSocket for bidirectional JSON messages

### Rooms Plugin (separate repo — see Known Issues below)
- **Repo**: https://github.com/PepperDash/epi-essentials-rooms
- **Active branch**: `development`
- **Latest release**: `0.1.0-rc-2` — **incompatible with Essentials v2.28.0**

---

## Project Layout

```
essentials-2-dev/
├── .gitignore
├── package.json                        # npm shortcuts (dev, build, deploy, etc.)
├── NOTES.md                            # this file
├── config/
│   └── configurationFile.json          # Essentials config — deploy to processor
├── mobile-control-ui/                  # React UI (cloned from mobile-control-react-app-core)
│   └── public/_local-config/
│       ├── _config.default.json        # template — committed, edit as example
│       └── _config.local.json          # gitignored — set your processor IP here
├── releases/                           # gitignored — binary artifacts
│   ├── PepperDashEssentials.*.cpz      # download via: npm run get-release
│   └── *.cplz                          # plugin files — upload alongside CPZ
└── scripts/
    ├── get-release.ps1                 # download latest Essentials CPZ from GitHub
    ├── deploy-processor.ps1            # upload CPZ + config + plugins, progload
    └── deploy-all.ps1                  # deploy + start UI dev server
```

---

## Configuration File Format

The `configurationFile.json` **must** use a `system`/`template` wrapper structure.
A flat config will fail with `System.ArgumentNullException` in `MergeConfigs`.

```json
{
  "system_url": "",
  "template_url": "",
  "system": {},
  "template": {
    "info": { ... },
    "devices": [ ... ],
    "rooms": [ ... ],
    "sourceLists": { ... },
    "tieLines": []
  }
}
```

### Config File Location on Processor
Essentials looks for the config at (lowercase, no zero-padding):
```
/user/program1/configurationFile.json    (slot 1)
/user/program2/configurationFile.json    (slot 2)
```
NOT `/User/Program01/` (the padded/mixed-case path does not work).

---

## Device Type Names (registered in v2.28.0 CPZ)

| Type string        | Class                          | Notes                        |
|--------------------|--------------------------------|------------------------------|
| `mobilecontrol`    | MobileControlSystemController  | Also: `appserver`, `webserver` |
| `mockdisplay`      | MockDisplay                    | For testing without hardware |
| `mockdisplay2`     | MockDisplay                    | Alias                        |
| `mockvc`           | MockVC                         | Mock video codec             |
| `mockac`           | MockAC                         | Mock audio codec             |
| `inroompc`         | InRoomPc                       |                              |
| `laptop`           | Laptop                         |                              |
| `genericsource`    | GenericSource                  |                              |
| `genericsink`      | GenericSink                    |                              |
| `basicirdisplay`   | BasicIrDisplay                 |                              |
| `settopbox`        | IRSetTopBox                    |                              |
| `roku`             | Roku2                          |                              |
| `appletv`          | AppleTV                        |                              |
| `bluejeanspc`      | BlueJeansPc                    |                              |
| `genericsoftcodec` | GenericSoftCodec               |                              |
| `genericComm`      | GenericComm                    |                              |
| `eiscapiadv`       | EiscApiAdvanced                | SIMPL bridge                 |

### Room Types (require `epi-essentials-rooms` plugin — see Known Issues)
| Type string          | Room Class                    |
|----------------------|-------------------------------|
| `huddle`             | EssentialsHuddleSpaceRoom     |
| `huddlevtc1`         | EssentialsHuddleVtc1Room      |
| `dualdisplay`        | EssentialsDualDisplayRoom     |
| `combinedhuddlevtc1` | EssentialsCombinedHuddleVtc1Room |
| `techroom`           | EssentialsTechRoom            |

---

## Mobile Control Setup

### Processor-side (Essentials config)
```json
{
  "key": "mobileControl",
  "name": "Mobile Control",
  "type": "mobilecontrol",
  "group": "api",
  "properties": {
    "enableApiServer": true,
    "directServer": {
      "enableDirectServer": true,
      "port": 50002
    }
  }
}
```
- Room bridges are created **automatically** for every `IEssentialsRoom` in the config
- No separate bridge device needed

### UI-side (`_config.local.json`)
```json
{
  "apiPath": "http://<PROCESSOR_IP>:50002/mc/api",
  "enableDev": true,
  "loginMode": "room-list",
  "iconSet": "GOOGLE"
}
```

### Console Commands
```
MOBILEADDUICLIENT <roomKey> <grantCode>   — add a client and get a token
MOBILEGETCLIENTINFO                        — show current clients
MOBILEREMOVEUICLIENT <token>               — remove a client
MOBILEREMOVEALLCLIENTS                     — remove all clients
```

### Connection Flow
1. Run `npm run dev` → UI at `http://localhost:5173`
2. Get a token: `MOBILEADDUICLIENT room1 1234`
3. Open: `http://localhost:5173/mc/app?token=<value>`

---

## Deploy Scripts

### Quick reference
```powershell
npm run get-release         # Download latest Essentials CPZ to releases/
npm run deploy              # Deploy CPZ + config + plugins to 192.168.104.171
npm run deploy:config       # Config file only (no CPZ, no progload)
npm run deploy:all          # Deploy + start UI dev server
npm run dev                 # Start UI dev server only
```

### deploy-processor.ps1 parameters
| Parameter     | Default              | Description                             |
|---------------|----------------------|-----------------------------------------|
| ProcessorIp   | (mandatory)          | Processor IP address                    |
| Slot          | 1                    | Program slot (1–10)                     |
| Username      | admin                | SFTP/SSH username                       |
| Password      | (blank)              | SFTP/SSH password                       |
| CpzPath       | auto (newest in releases/) | Path to .cpz                      |
| ConfigPath    | config\configurationFile.json | Path to config              |
| SkipConfig    | false                | Skip config upload                      |
| ConfigOnly    | false                | Config upload only, skip CPZ + progload |

### What gets deployed where
| File            | Remote path                                 |
|-----------------|---------------------------------------------|
| `*.cpz`         | `/program01/`                               |
| `configurationFile.json` | `/user/program1/`                  |
| `*.cplz` plugins | `/user/program1/plugins/`                  |

---

## Known Issues

### 1. Rooms Plugin Incompatibility (BLOCKER)
**`epi-essentials-rooms` v0.1.0-rc-2 is NOT compatible with Essentials v2.28.0.**

- The RC was compiled against `PepperDash_Essentials_Core v1.15.3`
- Essentials v2.28.0 ships `PepperDash_Core v2.28.0`
- Type resolution fails for `TwoWayDisplayBase`, `DisplayBase`, etc.
- Additionally, the plugin uses the old `EssentialsRoomConfig.GetRoomObject()` switch
  pattern rather than the v2 `IDeviceFactory`/`TypeNames` registration pattern,
  so even types that load are not registered in the DeviceFactory

**Result**: `Device type 'huddle' not found in DeviceFactory`

**Fix**: Build `epi-essentials-rooms` from source (`development` branch) against v2.28.0 NuGet packages using Visual Studio:
```
git clone --branch development https://github.com/PepperDash/epi-essentials-rooms.git
nuget install .\packages.config -OutputDirectory .\packages -excludeVersion
# Open in Visual Studio and build — produces .cplz
```
Drop the built `.cplz` into `releases/` and run `npm run deploy`.

### 2. MobileControl NullReferenceException on Boot
```
Error building Mobile Control System Controller
System.NullReferenceException at MobileControlSystemController..ctor [0x00111]
```
**Impact**: Low — despite the error, the WebSocket direct server starts successfully on port 50002 and the Web API is available. The null reference appears to be a timing issue with `ConfigReader.ConfigObject` not being populated at construction time.

**Workaround**: No action needed if using direct server mode. The `system_url` field in the config can be left empty for local/direct use.

### 3. Git Long Paths (Windows)
Cloning Essentials on Windows requires long path support:
```
git config --global core.longpaths true
```
Without this, checkout fails on filenames like
`configurationFile-mockVideoCodec_din-ap3_-_dm4x1.json`.

---

## Essentials Web API (available when running)

| Endpoint | Description |
|----------|-------------|
| `https://<IP>/cws/app01/api/types` | All registered device types |
| `https://<IP>/cws/app01/api/types/room` | Room-related types |
| `https://<IP>/cws/app01/api/devices` | All instantiated devices |
| `https://<IP>/cws/app01/api/config` | Running config |
| `https://<IP>/cws/app01/api/versions` | Assembly versions |
| `https://<IP>/cws/app01/api/restartProgram` | Restart via HTTP |
