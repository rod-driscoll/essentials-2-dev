# CLAUDE.md — essentials-2-dev

## What this project is

A Crestron AV control system project combining:
- **PepperDash Essentials v2** — C# plugin framework running on a Crestron 4-series processor (CP4)
- **Mobile Control UI** — React/TypeScript touchpanel web app served directly from the processor

The processor IP is `192.168.104.171`, program slot 1, port 50002.

---

## Repository structure

```
essentials-2-dev/
├── .env                              # gitignored — processor credentials (copy from .env.example)
├── .env.example                      # template for .env
├── config/configurationFile.json     # Essentials config — deployed to processor
├── mobile-control-ui/                # React UI (customised from PepperDash template)
│   ├── src/app/App.tsx               # Entry — renders MobileControlProvider + RoomBusiness
│   ├── src/index.tsx                 # App entry point with RouterProvider (basename /mc/app)
│   ├── src/components/pages/         # RoomList.tsx, RoomControl.tsx
│   ├── src/lib/                      # PepperDash hooks, store, types (treat as library)
│   ├── vite.config.app.ts            # App build → dist-app/ (use this for deploy)
│   └── public/_local-config/         # _config.default.json (committed); _config.local.json (gitignored)
├── releases/                         # gitignored — .cpz and .cplz binaries
└── scripts/                          # PowerShell deploy scripts
```

---

## Key commands (run from repo root)

```powershell
npm run dev           # Start UI dev server at http://localhost:5173/mc/app
npm run build:app     # Build React app → mobile-control-ui/dist-app/
npm run deploy        # Deploy CPZ + config + plugins to processor, then progload
npm run deploy:config # Upload config only (still need manual progload)
npm run deploy:ui     # Build React app and SFTP to /user/program1/mcUserApp/
npm run deploy:all    # Full deploy + start dev server
npm run get-release   # Download latest Essentials CPZ from GitHub to releases/
```

Deploy scripts read processor credentials from `.env` (copy `.env.example` and fill in values).
They also accept `-ProcessorIp`, `-Slot`, `-Username`, `-Password` as overrides.

---

## Mobile Control UI

### Stack
React 18, Redux Toolkit, Vite, TypeScript, React Router v6, WebSocket.

### Entry point
`index.html` → `src/index.tsx` (has `RouterProvider` with `basename: '/mc/app'`).
**Do not use `src/main.tsx`** as the app entry — it has no router and React Router hooks will throw.

### Routing
- `/mc/app/` → `RoomList` (auto-navigates if single room)
- `/mc/app/room/:roomKey` → `RoomControl`

### RoomControl page

`src/components/pages/RoomControl.tsx` implements:

- **Display power** — Power On via `useIRunDefaultPresentRoute` (sends `defaultsource`), Power Off via `routeAction.runRoute({ sourceListItemKey: 'roomOff' })`; feedback from `useGetDevice<DisplayState>('display-1').powerState`
- **Source selection** — buttons from `useRoomSourceList`, routed via `useIRunRouteAction`; active highlight via `room.selectedSourceKey`
- **Volume** — slider (`<input type="range" min=0 max=65535>`) + mute toggle via `useRoomIBasicVolumeWithFeedback(roomKey, 'master')`

All controls must be in the `content` prop of `MainLayout` — the `footer` area has pointer events blocked.

### Key hooks (from `src/lib/`)
- `useGetAllRooms()` — all rooms from Redux store
- `useRoomSourceList(roomKey)` — source list from room config
- `useRoomIsOn(roomKey)`, `useRoomState(roomKey)` — room power/state
- `useIRunRouteAction(roomKey)` — source selection (`runRoute({ sourceListItemKey })`)
- `useIRunDefaultPresentRoute(roomKey)` — sends `defaultsource` route (power on)
- `useRoomIBasicVolumeWithFeedback(roomKey, type)` — volume/mute with feedback; returns `undefined` until room state loads
- `useGetDevice<T>(deviceKey)` — raw device state from Redux (e.g. `DisplayState` for power feedback)

### Source selection feedback

The Essentials MobileControl bridge serializes room state from a fixed schema — adding properties
to the C# room class does NOT cause them to appear in the `/room/room1` WebSocket message.
`room.selectedSourceKey` is never populated for `IEssentialsHuddleSpaceRoom`.

Instead, use the display device's `inputs` state, which IS sent reliably via `/device/display-1`
as `IHasInputsStateMessage`. Each item has `{ key, name, isSelected }`:

```typescript
const displayInputs = (displayState as any)?.inputs?.items as
  | Record<string, { key: string; name: string; isSelected: boolean }>
  | undefined;
const selectedInputName = displayInputs
  ? Object.values(displayInputs).find(i => i.isSelected)?.name
  : undefined;
const selectedSourceKey = selectedInputName && sourceList
  ? Object.entries(sourceList).find(([, s]) => s.name === selectedInputName)?.[0]
  : undefined;
```

**Requirement:** the display `activeInputs[].name` values must match the source list item `name`
values exactly (e.g. both `"HDMI 1"`). This is the only join between the two.

### Build for processor deploy
```powershell
npm run deploy:ui   # builds dist-app/ then SFTPs to /user/program1/mcUserApp/
```
`npm run build` (no `:app`) builds the **library package for npm** — wrong for deployment.

### Token flow
```
MOBILEADDUICLIENT room1 1234    # Crestron console → outputs token URL
http://localhost:5173/mc/app?token=<token>
```
Or use room-list mode (no token): set `"loginMode": "room-list"` in `_config.local.json`.

---

## Essentials config (`configurationFile.json`)

Must use `system`/`template` wrapper — flat config throws `ArgumentNullException`.

Critical fields:
- `system_url` must match regex `https?:\/\/.*\/systems\/(.*)\/#.*`
  Use: `"system_url": "https://localhost/systems/local/#room1"`
- `mobilecontrol` device must have `"serverUrl": "http://localhost"` in properties

Config deploys to `/user/program1/configurationFile.json` (lowercase, no zero-padding).

### Samsung MDC display (`samsungMdcPlugin`)

The `activeInputs` array is required — without it the plugin has no inputs registered and
input switching silently does nothing:

```json
"activeInputs": [
  { "key": "hdmi1", "name": "HDMI 1" },
  { "key": "hdmi2", "name": "HDMI 2" }
]
```

The device `id` must match the MDC set ID configured on the display (typically `"00"`).
Confirm with a terminal: commands sent with ID 0 (`\xAA\x14\x00...`) should be acknowledged.

Volume and mute are controlled via the room's `volumes.master` block pointing to the display key —
not via a DSP. Set `hasDsp: false` in room properties when using display volume.

---

## Plugins

### Rooms plugin

The upstream `epi-essentials-rooms` release is **incompatible** with Essentials v2.28.0.
Use the rebuilt plugin in `releases/PDT.Plugins.Essentials.Rooms-2.1.4.cplz` (built from
the fork `rod-driscoll/epi-essentials-rooms`, branch `feature/selected-source-key-feedback`,
which is based on `feature/essentials-v2-compat`).

Do not replace this with the upstream `-compat.cplz` from GitHub — it will silently fail to load.

The `2.1.4` build fixes bugs in `EssentialsDualDisplayRoom` and the factory registration (see below),
and adds `SelectedSourceKey` and `CurrentSourceInfoKey` properties to both `EssentialsHuddleSpaceRoom`
and `EssentialsDualDisplayRoom`. These do NOT currently appear in the MobileControl WebSocket
room state (the bridge ignores arbitrary properties), but the properties are there for future use.

#### Building the rooms plugin locally

The plugin lives at `D:\repos\PepperDash\epi-essentials-rooms` (fork: `rod-driscoll/epi-essentials-rooms`).
Use the **4.72 project** (`PDT.Plugins.Essentials.Rooms.4.72.csproj`) — this is the Essentials v2 build
targeting .NET 4.7.2 with `ESSENTIALS_V2` defined. The older `.csproj` targets .NET CE 3.5 (v1 only).

```powershell
# 1. Restore NuGet packages (only needed once, or after clean)
cd D:\repos\PepperDash\epi-essentials-rooms
& "C:\Program Files (x86)\NuGet\nuget.exe" restore src\PDT.Plugins.Essentials.Rooms.4.72.csproj -PackagesDirectory packages

# 2. Build
& "C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe" `
    src\PDT.Plugins.Essentials.Rooms.4.72.csproj /p:Configuration=Release /p:Platform=AnyCPU /v:minimal
# Output: src\bin\Release\PDT.Plugins.Essentials.Rooms.dll

# 3. Package as CPLZ (a CPLZ is just a ZIP containing the DLL)
$version = "2.1.x"   # bump as needed in src\Properties\AssemblyInfo.cs first
$cplz = "D:\repos\PepperDash\essentials-2-dev\releases\PDT.Plugins.Essentials.Rooms-$version.cplz"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($cplz, 'Create')
[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
  $zip,
  "D:\repos\PepperDash\epi-essentials-rooms\src\bin\Release\PDT.Plugins.Essentials.Rooms.dll",
  "PDT.Plugins.Essentials.Rooms.dll", "Optimal") | Out-Null
$zip.Dispose()

# 4. Remove old version from releases/, then deploy
npm run deploy   # from essentials-2-dev root
```

**Dependencies already in place:**

- `lib/` — Essentials v2.28.0 DLLs (extracted from CPZ; do not change)
- `C:\ProgramData\Crestron\SDK\SimplSharpPro.exe` — Crestron runtime (installed by Crestron Toolbox)
- `packages/Crestron.SimplSharp.SDK.Library.2.21.226` — restored by nuget above

**Note:** GitHub Actions CI is not enabled on the fork. Build locally as above.

#### Adding a new room type to this plugin

1. Create the room class (e.g. `EssentialsMyNewRoom.cs`) extending `EssentialsRoomBase`.
2. Add a `case "mynewtype":` entry in `EssentialsRoomsDeviceFactory.BuildDevice()`.
3. Add `"mynewtype"` to the `TypeNames` list in the same factory class.
4. Bump the version in `src/Properties/AssemblyInfo.cs`.
5. Build, package, deploy (see steps above).

**Critical:** the factory must implement `IPluginDeviceFactory` (not just `IDeviceFactory`).
`IPluginDeviceFactory` adds the `MinimumEssentialsFrameworkVersion` property that Essentials uses
to discover and load plugin factories at startup. Without it the plugin DLL loads but the factory
is silently skipped — room types won't be registered and you'll see
`Device type 'xyz' not found in DeviceFactory` even though the assembly loaded successfully.

```csharp
public class EssentialsRoomsDeviceFactory : IPluginDeviceFactory
{
    public string MinimumEssentialsFrameworkVersion { get; } = "2.0.0";
    // ...
}
```

Diagnosis: if `devlist` is missing `room1` and the boot log shows the assembly loaded but no
"Loading plugin factory: PDT.Plugins.Essentials.Rooms" line, the factory interface is wrong.

#### Known bugs fixed in this fork (vs upstream `feature/essentials-v2-compat`)

`EssentialsRoomsDeviceFactory` used `IDeviceFactory` instead of `IPluginDeviceFactory`:

- Essentials v2 discovers factories by scanning for `IPluginDeviceFactory` (not `IDeviceFactory`)
- Without this, room types were never registered despite the DLL loading fine
- Fix: implement `IPluginDeviceFactory` and add `MinimumEssentialsFrameworkVersion = "2.0.0"`

`EssentialsDualDisplayRoom` had two bugs that caused `volumes: {}` in the room WebSocket state:

1. **RightDisplay copy-paste bug** — constructor assigned `LeftDisplay` instead of `RightDisplay`
   when registering the right display, leaving `RightDisplay` null.

2. **VideoCodec null throw** — constructor threw `ArgumentNullException` when no `videoCodecKey`
   is in config, so `InitializeRoom()` never ran and `CurrentVolumeControls` was never set.
   Fixed by downgrading to a log warning; all `VideoCodec.` call sites are now null-guarded.

**Diagnosis pattern for `volumes: {}`:**

1. Check `devlist` on processor — if volume device (e.g. `dsp-1-program`) is missing, it's a
   connectivity issue (check `ping` and TCP port). If present, it's a C# wiring issue.
2. Look at processor error log for exceptions during room construction — a caught exception in the
   constructor silently leaves the room partially initialised.

### Samsung MDC display plugin

Using a locally patched build (`epi-display-samsung-mdc.4Series.1.6.2-buffix.cplz`) that fixes
a buffer overflow crash in feedback parsing. The bug is in `Communication_BytesReceived` in
`SamsungMdc.cs` — `newBytes.CopyTo(message, 0)` throws `ArgumentException: Destination array
was not long enough` when multiple MDC responses arrive in the same TCP packet (reliably triggered
by volume commands).

Fix: `Array.Copy(newBytes, 0, message, 0, dataLength)` — PR submitted upstream:
[PepperDash/epi-samsung-mdc-display#43](https://github.com/PepperDash/epi-samsung-mdc-display/pull/43)

Do not replace this with `v1.6.1` or `v1.6.2` from GitHub until the PR is merged.

---

## Important gotchas

| Issue | Fix |
|---|---|
| React Router hooks throw empty-message error | `index.html` must point to `src/index.tsx`, not `src/main.tsx` |
| WebSocket `hasApiPath: false` | `vite.config.ts` must have `base: '/mc/app/'` |
| `MOBILEADDUICLIENT` silently adds 0 clients | `system_url` must match the portal regex |
| MobileControl constructor throws NullReferenceException | Add `"serverUrl"` to mobilecontrol device properties |
| Rooms plugin silently not loaded | Use rebuilt CPLZ, not upstream GitHub release |
| `room1` missing from `devlist` after progload | `dualdisplay` room needs `displays` block in config (see Essentials config section) |
| Samsung MDC input switching does nothing | `activeInputs` array must be present in display properties |
| Samsung MDC crashes on volume feedback | Use patched CPLZ — see Samsung MDC plugin note above |
| Volume hook returns `undefined` on load | Transient — resolves once room state arrives via WebSocket |
| Footer buttons non-interactive in MainLayout | Put all controls in the `content` prop, not `footer` |
| Source button highlight never updates | `room.selectedSourceKey` is never sent — use display `inputs.items[].isSelected` instead |
| Multiple config files cause load error | Processor globs `*configurationFile*.json` — only one must exist in `/user/program1/` |
| Git checkout fails on Windows | Run `git config --global core.longpaths true` first |

---

## What NOT to do

- Don't use `npm run build` for processor deployment — use `npm run build:app`
- Don't use the upstream `epi-essentials-rooms` CPLZ from GitHub
- Don't replace the patched Samsung MDC CPLZ until upstream PR #43 is merged
- Don't edit files in `src/lib/` for UI changes — that is the library layer; customise in `src/app/` and `src/components/`
- Don't commit `node_modules/`, `dist/`, `dist-app/`, or `_config.local.json` (all gitignored)
- Don't add a separate `epi-essentials-mobile-control` CPLZ — Mobile Control is bundled inside the Essentials CPZ
- Don't set `hasDsp: true` when using display volume — it will route volume to a DSP that may not exist

---

## Debugging

### Processor console commands

```
devlist                              # list all registered devices
devprops display-1                   # show display device properties (IsOnline, PowerIsOnFeedback etc.)
devprops display-1-tcp               # show TCP connection state (IsConnected, ClientStatus)
devjson {"deviceKey":"display-1","methodName":"InputHdmi1","params":[]}   # call method directly
ping 192.168.41.242                  # test network reachability from processor
```

### Processor web API (PS 5.1 — requires TLS workaround)

```powershell
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
Invoke-RestMethod "https://192.168.104.171/cws/app01/api/deviceCommands/display-1"
```

### Useful processor API endpoints

```
http://192.168.104.171:50002/mc/api/version
http://192.168.104.171:50002/mc/api/rooms
http://192.168.104.171:50002/mc/api/info
ws://192.168.104.171:50002/mc/api/ui/join/<token>
```

Full Essentials web API: `https://192.168.104.171/cws/app01/api/`
