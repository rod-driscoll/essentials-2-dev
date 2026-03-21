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

All scripts are in `scripts/` and accept `-ProcessorIp`, `-Slot`, `-Username`, `-Password`.

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

### Key hooks (from `src/lib/`)
- `useGetAllRooms()` — all rooms from Redux store
- `useRoomSourceList(roomKey)` — source list from room config
- `useRoomIsOn(roomKey)`, `useRoomState(roomKey)` — room power/state
- `useIRunRouteAction(roomKey)` — source selection (`runRoute({ sourceListItemKey })`)
- `useIBasicVolumeWithFeedback(path, volumeState)` — volume control

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

---

## Rooms plugin

The upstream `epi-essentials-rooms` release is **incompatible** with Essentials v2.28.0.
Use the rebuilt plugin in `releases/PDT.Plugins.Essentials.Rooms-2.1.0.cplz` (rebuilt from
the fork `rod-driscoll/epi-essentials-rooms`, branch `feature/essentials-v2-compat`).

Do not replace this with the upstream `-compat.cplz` from GitHub — it will silently fail to load.

---

## Important gotchas

| Issue | Fix |
|---|---|
| React Router hooks throw empty-message error | `index.html` must point to `src/index.tsx`, not `src/main.tsx` |
| WebSocket `hasApiPath: false` | `vite.config.ts` must have `base: '/mc/app/'` |
| `MOBILEADDUICLIENT` silently adds 0 clients | `system_url` must match the portal regex |
| MobileControl constructor throws NullReferenceException | Add `"serverUrl"` to mobilecontrol device properties |
| Rooms plugin silently not loaded | Use rebuilt CPLZ, not upstream GitHub release |
| Git checkout fails on Windows | Run `git config --global core.longpaths true` first |

---

## What NOT to do

- Don't use `npm run build` for processor deployment — use `npm run build:app`
- Don't use the upstream `epi-essentials-rooms` CPLZ from GitHub
- Don't edit files in `src/lib/` for UI changes — that is the library layer; customise in `src/app/` and `src/components/`
- Don't commit `node_modules/`, `dist/`, `dist-app/`, or `_config.local.json` (all gitignored)
- Don't add a separate `epi-essentials-mobile-control` CPLZ — Mobile Control is bundled inside the Essentials CPZ

---

## Useful processor API endpoints

```
http://192.168.104.171:50002/mc/api/version
http://192.168.104.171:50002/mc/api/rooms
http://192.168.104.171:50002/mc/api/info
ws://192.168.104.171:50002/mc/api/ui/join/<token>
```

Full Essentials web API: `https://192.168.104.171/cws/app01/api/`
