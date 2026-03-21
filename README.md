# PepperDash Essentials v2 + Mobile Control — Implementation Notes

## Current Working State

Full end-to-end connection is working:

- Essentials v2.28.0 running on CP4 (slot 1)
- `epi-essentials-rooms` plugin loaded (rebuilt from source — see Known Issues)
- `huddle` room `room1` instantiated with `mockdisplay` device
- Mobile Control direct server on port 50002
- React UI (dev server) connected via WebSocket
- Room status messages flowing: `/system/roomKey`, `/room/room1`, `/system/deviceInterfaces`

---

## Quick Start — Dev Environment

### Prerequisites

- Essentials v2.28.0 CPZ in `releases/` (run `npm run get-release`)
- Rebuilt rooms plugin CPLZ in `releases/` (see Known Issues #1)
- Node.js for the React dev server

> **Mobile Control is bundled in the CPZ.** `epi-essentials-mobile-control.dll` and
> `mobile-control-messengers.dll` are included inside `PepperDashEssentials.2.28.0.net472.cpz`
> — no separate mobile control CPLZ is needed or should be added to `releases/`.

### 1. Deploy to processor (first time or after CPZ/plugin change)

```powershell
npm run deploy    # uploads CPZ + config + plugins, then progloads slot 1
```

### 2. Deploy config only (after editing configurationFile.json)

```powershell
npm run deploy:config    # SFTP upload only — then manually: progload -p:01
```

> Note: `deploy:config` does NOT restart the program. You must `progload -p:01` in the
> Crestron console after, or use `npm run deploy` which does both.

### 3. Start the UI dev server

```powershell
npm run dev    # starts Vite at http://localhost:5173
```

### 4. Get a token and connect

On the Crestron console (SSH to processor):

```text
MOBILEADDUICLIENT room1 1234
```

This outputs a URL like:

```text
http://localhost/systems/local/#room1/mc/app?token=eyJ...
```

Copy only the token value. Open in browser:

```text
http://localhost:5173/mc/app?token=<token>
```

The UI connects via WebSocket to `ws://192.168.104.171:50002/mc/api/...`.

### 5. Room-list mode (no token — simpler for dev/touchpanel)

In `mobile-control-ui/public/_local-config/_config.local.json`, set `"loginMode": "room-list"`.
Then just open `http://localhost:5173/mc/app` — the UI lists rooms and connects without a token.

---

## Repository Structure

### PepperDash Essentials

- **Repo**: <https://github.com/PepperDash/Essentials>
- **Active branch**: `development` (NOT `main` — that is legacy v1.x)
- **Latest release**: v2.28.0 (tag on `development` commits, not from `main`)
- **Future**: `dev/3.x` branch targets .NET 8
- **Target framework**: .NET Framework 4.7.2 (`net472`)

### Mobile Control UI

- **Repo**: <https://github.com/PepperDash/mobile-control-react-app-core>
- **Stack**: React 18, Redux Toolkit, Vite, TypeScript
- **Protocol**: HTTP room join → WebSocket for bidirectional JSON messages

### Rooms Plugin (separate repo — see Known Issues below)

- **Upstream repo**: <https://github.com/PepperDash/epi-essentials-rooms>
- **Fork (with v2 fixes)**: <https://github.com/rod-driscoll/epi-essentials-rooms> — branch `feature/essentials-v2-compat`
- **Upstream latest release**: `0.1.0-rc-2` — **incompatible with Essentials v2.28.0** (use the fork)
- **Built plugin**: `releases/PDT.Plugins.Essentials.Rooms-2.1.0.cplz`

---

## Project Layout

```text
essentials-2-dev/
├── .gitignore
├── package.json                        # npm shortcuts (dev, build, deploy, etc.)
├── README.md                           # this file
├── config/
│   └── configurationFile.json          # Essentials config — deploy to processor
├── mobile-control-ui/                  # React UI (cloned from mobile-control-react-app-core)
│   ├── vite.config.ts                  # library build (npm publish) — NOT for processor deploy
│   ├── vite.config.app.ts              # app build — use this for touchpanel/processor deploy
│   ├── dist-app/                       # gitignored — output of npm run build:app
│   └── public/_local-config/
│       ├── _config.default.json        # template — committed, edit as example
│       └── _config.local.json          # gitignored — set your processor IP here
├── releases/                           # gitignored — binary artifacts
│   ├── PepperDashEssentials.*.cpz      # download via: npm run get-release
│   └── *.cplz                          # plugin files — upload alongside CPZ
└── scripts/
    ├── get-release.ps1                 # download latest Essentials CPZ from GitHub
    ├── deploy-processor.ps1            # upload CPZ + config + plugins, progload
    ├── deploy-ui.ps1                   # build React app and SFTP to /user/program1/mcUserApp/
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

### system_url — critical field

`system_url` must match the portal URL regex pattern used by `MobileControlSystemController.Initialize()`:

```text
https?:\/\/.*\/systems\/(.*)\/#.*
```

Example value that works (placeholder, no real portal needed):

```json
"system_url": "https://localhost/systems/local/#room1"
```

If `system_url` is empty, null, or doesn't match the pattern, `Initialize()` throws
`ArgumentNullException: input` and `MOBILEADDUICLIENT` silently fails (0 clients added).
The portal connection itself fails gracefully — only the direct WebSocket server is needed.

### Config File Location on Processor

Essentials looks for the config at (lowercase, no zero-padding):

```text
/user/program1/configurationFile.json    (slot 1)
/user/program2/configurationFile.json    (slot 2)
```

NOT `/User/Program01/` (the padded/mixed-case path does not work).

---

## Device Type Names (registered in v2.28.0 CPZ)

| Type string        | Class                          | Notes                          |
| ------------------ | ------------------------------ | ------------------------------ |
| `mobilecontrol`    | MobileControlSystemController  | Also: `appserver`, `webserver` |
| `mockdisplay`      | MockDisplay                    | For testing without hardware   |
| `mockdisplay2`     | MockDisplay                    | Alias                          |
| `mockvc`           | MockVC                         | Mock video codec               |
| `mockac`           | MockAC                         | Mock audio codec               |
| `inroompc`         | InRoomPc                       |                                |
| `laptop`           | Laptop                         |                                |
| `genericsource`    | GenericSource                  |                                |
| `genericsink`      | GenericSink                    |                                |
| `basicirdisplay`   | BasicIrDisplay                 |                                |
| `settopbox`        | IRSetTopBox                    |                                |
| `roku`             | Roku2                          |                                |
| `appletv`          | AppleTV                        |                                |
| `bluejeanspc`      | BlueJeansPc                    |                                |
| `genericsoftcodec` | GenericSoftCodec               |                                |
| `genericComm`      | GenericComm                    |                                |
| `eiscapiadv`       | EiscApiAdvanced                | SIMPL bridge                   |

### Room Types (require `epi-essentials-rooms` plugin — see Known Issues)

| Type string          | Room Class                       |
| -------------------- | -------------------------------- |
| `huddle`             | EssentialsHuddleSpaceRoom        |
| `huddlevtc1`         | EssentialsHuddleVtc1Room         |
| `dualdisplay`        | EssentialsDualDisplayRoom        |
| `combinedhuddlevtc1` | EssentialsCombinedHuddleVtc1Room |
| `techroom`           | EssentialsTechRoom               |

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
    "serverUrl": "http://localhost",
    "enableApiServer": true,
    "directServer": {
      "enableDirectServer": true,
      "port": 50002
    }
  }
}
```

- `serverUrl` is required — without it the constructor throws `NullReferenceException` on `Host.StartsWith("http")`
- `"http://localhost"` is a safe placeholder; the portal connection is never made in direct-server mode
- Room bridges are created **automatically** for every `IEssentialsRoom` in the config
- No separate bridge device needed

### UI-side (`_config.local.json`)

```json
{
  "apiPath": "http://192.168.104.171:50002/mc/api",
  "enableDev": true,
  "loginMode": "room-list",
  "iconSet": "GOOGLE"
}
```

### Console Commands

```text
MOBILEADDUICLIENT <roomKey> <grantCode>   — add a client and get a token
MOBILEGETCLIENTINFO                        — show current clients
MOBILEREMOVEUICLIENT <token>               — remove a client
MOBILEREMOVEALLCLIENTS                     — remove all clients
```

### Connection Flow (token mode)

1. Deploy config and restart: `npm run deploy`
2. Verify boot log shows `****All Devices Initialized****` and no `[EROR]` for mobileControl
3. Run `npm run dev` → UI dev server at `http://localhost:5173`
4. On the Crestron console: `MOBILEADDUICLIENT room1 1234`
   - Requires `system_url` to match the portal URL regex (see above)
   - Outputs a URL — copy only the `token=` value
5. Open in browser: `http://localhost:5173/mc/app?token=<token>`
6. WebSocket connects to `ws://192.168.104.171:50002/mc/api/ui/join/<token>?clientId=...`

### Touchpanel URL

- **Dev (panel reaches PC)**: `http://<your-pc-ip>:5173/mc/app` (room-list mode, no token needed)
- **Production**: build the React app (`npm run build` in `mobile-control-ui/`), deploy `dist/`
  to the processor's static files path, then use `http://192.168.104.171:50002/mc/app`

---

## Deploy Scripts

### Quick reference

```powershell
npm run get-release         # Download latest Essentials CPZ to releases/
npm run deploy              # Deploy CPZ + config + plugins to 192.168.104.171
npm run deploy:config       # Config file only (no CPZ, no progload)
npm run deploy:ui           # Build React app and deploy to /user/program1/mcUserApp/
npm run deploy:all          # Deploy + start UI dev server
npm run build:app           # Build React app only (output: mobile-control-ui/dist-app/)
npm run dev                 # Start UI dev server only
```

### deploy-processor.ps1 parameters

| Parameter   | Default                       | Description                             |
| ----------- | ----------------------------- | --------------------------------------- |
| ProcessorIp | (mandatory)                   | Processor IP address                    |
| Slot        | 1                             | Program slot (1–10)                     |
| Username    | admin                         | SFTP/SSH username                       |
| Password    | (blank)                       | SFTP/SSH password                       |
| CpzPath     | auto (newest in releases/)    | Path to .cpz                            |
| ConfigPath  | config\configurationFile.json | Path to config                          |
| SkipConfig  | false                         | Skip config upload                      |
| ConfigOnly  | false                         | Config upload only, skip CPZ + progload |

### What gets deployed where

| File                     | Remote path                |
| ------------------------ | -------------------------- |
| `*.cpz`                  | `/program01/`              |
| `configurationFile.json` | `/user/program1/`          |
| `*.cplz` plugins         | `/user/program1/plugins/`  |

---

## Next Steps

### 1. Add Sources to the Room

The current `sourceLists` has only a `roomOff` entry — no selectable sources.
Add real or mock sources so the UI source picker has something to show:

```json
"sourceLists": {
  "default": {
    "roomOff": { "order": 1, "sourceKey": "$off", "type": "off", ... },
    "source-1": {
      "order": 2,
      "sourceKey": "laptop-1",
      "name": "Laptop",
      "type": "laptop",
      "routeList": [
        { "sourceKey": "laptop-1", "type": "audioVideo", "destinationKey": "$defaultAll" }
      ]
    }
  }
}
```

Add a matching device entry (e.g. `"type": "laptop"` or `"type": "genericsource"`).

### 2. Wire Up the Room Control UI

`mobile-control-ui/src/app/App.tsx` is currently a placeholder that renders icons but
no real room controls. The Redux store already receives room state from the processor
(`/room/room1` messages). The next step is to connect that state to actual UI components:

- Power on/off
- Source selection
- Volume control (mapped to `display-1`)
- Tech menu (password `1234`)

The library components are in `src/lib/` — explore `MobileControlProvider` and existing
room-state selectors.

### 3. Test with Real Hardware

Replace `mockdisplay` with a real display driver. Add the appropriate CPLZ plugin to
`releases/` and update `configurationFile.json`:

- RS-232 display: use a display CPLZ (e.g. `epi-display-*`)
- HDMI switcher: add tieline entries in `tieLines`

### 4. Production Deployment (Touchpanel)

The Mobile Control direct server serves static files from `/user/program{slot}/mcUserApp/`
on the processor filesystem, mapped to the `/mc/app` HTTP route. This is hardcoded in
`MobileControlWebsocketServer.cs` (`_appPath = FilePathPrefix + "mcUserApp"`).

Build and deploy in one step:

```powershell
npm run deploy:ui    # builds dist-app/ then SFTPs to /user/program1/mcUserApp/
```

Or separately:

```powershell
npm run build:app                                     # builds mobile-control-ui/dist-app/
pwsh scripts/deploy-ui.ps1 -ProcessorIp 192.168.104.171 -SkipBuild   # upload only
```

After deploy, touchpanel URL (no token needed with room-list mode):

```text
http://192.168.104.171:50002/mc/app
```

Note: `npm run build` (no `:app`) builds the **library** package for npm — not what you
want for deployment. Use `build:app` which uses `vite.config.app.ts` and outputs a
self-contained `index.html` + `assets/` in `dist-app/`.

### 5. Persistent Client Registration

Each `MOBILEADDUICLIENT` call generates a new token stored in CDS. If the processor
restarts, clients persist (CDS survives reboot). However:

- Tokens issued per-client accumulate — use `MOBILEREMOVEALLCLIENTS` before re-registering
- For room-list mode (`loginMode: "room-list"`), no per-panel tokens are needed — simpler for fixed installs

---

## Known Issues

### 1. Rooms Plugin Incompatibility (RESOLVED)

**`epi-essentials-rooms` v0.1.0-rc-2 (the GitHub release) is NOT compatible with Essentials v2.28.0.**

Two issues were found and fixed:

**Issue A** — Wrong interface: The GitHub release used the v1 `LoadTypeFactories()` pattern.
Essentials v2 plugin scanner checks `typeof(IPluginDeviceFactory).IsAssignableFrom(type)`,
not `IDeviceFactory`. Any plugin that only implements `IDeviceFactory` is silently skipped.

**Issue B** — Wrong build: The `-compat.cplz` from GitHub was compiled without `ESSENTIALS_V2`,
so it used the v1 code path regardless.

**Resolution**: Rebuilt from local `epi-essentials-rooms` source using
`PDT.Plugins.Essentials.Rooms.4.72.csproj` (defines `ESSENTIALS_V2`) with
`EssentialsRoomsDeviceFactory` changed to implement `IPluginDeviceFactory` (adds required
`MinimumEssentialsFrameworkVersion` property). Packaged as `releases/PDT.Plugins.Essentials.Rooms-2.1.0.cplz`.

Boot now shows:

```text
Passed plugin passed dependency check (required version 2.0.0)
Loading plugin factory: PDT.Plugins.Essentials.Rooms
Loading 'huddle' from PepperDash_Essentials_Core, Version=2.28.0.0
```

If the releases folder is regenerated via `npm run get-release`, do **not** use the
`-compat.cplz` from GitHub. Rebuild from local source:

```powershell
# In epi-essentials-rooms/src/
msbuild PDT.Plugins.Essentials.Rooms.4.72.csproj /p:Configuration=Release /t:Rebuild
# Repackage:
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open('..\..\essentials-2-dev\releases\PDT.Plugins.Essentials.Rooms-2.1.0.cplz', 'Create')
[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, 'bin\Release\PDT.Plugins.Essentials.Rooms.dll', 'PDT.Plugins.Essentials.Rooms.dll')
$zip.Dispose()
```

### 2. MobileControl Initialization (RESOLVED)

#### Issue A — NullReferenceException in constructor

`MobileControlConfig.ServerUrl` maps to `"serverUrl"` in device properties. Without it the
field deserializes to `null`, and the constructor immediately throws:

```csharp
Host = config.ServerUrl;        // null
if (!Host.StartsWith("http"))   // NullReferenceException
```

**Fix**: Add `"serverUrl": "http://localhost"` to the mobilecontrol device properties.

#### Issue B — system_url Regex error in Initialize

```text
[WARN][mobileControl] No system_url value defined in config.  Checking for value from SIMPL Bridge.
[EROR][mobileControl] Exception initializing device: Value cannot be null. Parameter name: input
```

`Initialize()` reads `system_url` and passes it to `Regex.IsMatch()`. If the value is null
or doesn't match the expected portal URL pattern, it throws and `MOBILEADDUICLIENT` silently fails.

The portal URL regex (extracted from `epi-essentials-mobile-control.dll`) is:

```text
https?:\/\/.*\/systems\/(.*)\/#.*
```

**Fix**: Set `system_url` to a value that matches this pattern:

```json
"system_url": "https://localhost/systems/local/#room1"
```

The portal connection attempt itself fails gracefully (no real portal server). The direct
WebSocket server starts regardless. Room bridges are registered. `MOBILEADDUICLIENT` works.

Signs of correct initialization in boot log:

```text
[INFO][mobileControl] Starting DirectServer on port 50002
[INFO][mobileControl] Room bridge added for room: room1
****All Devices Initialized****
```

No `[EROR]` lines for mobileControl.

### 3. Vite Base Path — config fetch fails without it (RESOLVED)

The React UI's `websocketMiddleware.ts` computes a `baseURL` from `location.pathname`
and uses it in an axios call to fetch `/_local-config/_config.local.json`.

`axios.combineURLs('/mc/app', '/_local-config/_config.local.json')` produces
`/mc/app/_local-config/_config.local.json` — stripping the leading `/` from the path.

Without `base: '/mc/app/'` in `vite.config.ts`, Vite serves the public folder at `/`,
so the file exists at `/_local-config/...` but axios requests `/mc/app/_local-config/...` → 404.
Result: `apiPath` never loads → `hasApiPath: false` → WebSocket connection never attempted.

**Fix**: Add `base: '/mc/app/'` to `vite.config.ts`:

```typescript
export default defineConfig((configEnv) => ({
  base: '/mc/app/',
  plugins: [ ... ]
}))
```

This also aligns the dev server with production (where the UI is served from `/mc/app/`).

### 4. Git Long Paths (Windows)

Cloning Essentials on Windows requires long path support:

```text
git config --global core.longpaths true
```

Without this, checkout fails on filenames like
`configurationFile-mockVideoCodec_din-ap3_-_dm4x1.json`.

---

## Essentials Web API (available when running)

| Endpoint | Description |
| -------- | ----------- |
| `https://<IP>/cws/app01/api/types` | All registered device types |
| `https://<IP>/cws/app01/api/types/room` | Room-related types |
| `https://<IP>/cws/app01/api/devices` | All instantiated devices |
| `https://<IP>/cws/app01/api/config` | Running config |
| `https://<IP>/cws/app01/api/versions` | Assembly versions |
| `https://<IP>/cws/app01/api/restartProgram` | Restart via HTTP |

## Mobile Control Direct Server API

| Endpoint | Method | Description |
| -------- | ------ | ----------- |
| `http://<IP>:50002/mc/api/version` | GET | Server version |
| `http://<IP>:50002/mc/api/info` | GET | System info, tokensDefined count |
| `http://<IP>:50002/mc/api/rooms` | GET | Room list |
| `http://<IP>:50002/mc/api/client/joinroom` | POST | Issue token (requires grantCode) |
| `ws://<IP>:50002/mc/api/ui/join/<token>` | WS | Room WebSocket connection |
