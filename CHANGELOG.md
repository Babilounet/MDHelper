# Changelog

## v1.3.0

- **Fix**: macro auto-creation never ran because `GetMacroIndexByName` returns `0` (truthy in Lua), not `nil`. The guard now compares against `0` correctly and retries on every login until the macro exists
- **Fix**: spell name fallback no longer assumes English. If `GetSpellInfo(34477)` returns nil/empty (rare locale loading issue), MDHelper now falls back to the localized name for the current `GetLocale()` (FR, DE, ES, IT, PT, RU, KO, zhCN, zhTW)
- **UX**: explicit confirmation message when the macro is auto-created at login

## v1.2.0

- **Party support**: the floating button now appears in any group, not just in raids
- **More reliable cast**: the macro now uses the unit ID (`raid1`, `party1`, `player`) as the primary target with name as fallback, which fixes casts that failed on cross-realm names or with special characters
- **Roster refresh**: macro is rebuilt on `GROUP_ROSTER_UPDATE` so unit ID shifts (joins/leaves) don't break the cast
- **`/md debug`**: prints spell name, selected target, resolved unit ID, group state, and current macro text for diagnostics

## v1.1.0

- **Auto-create macro**: the `MDHelper` macro is created automatically on first load with the Misdirection icon, ready to drag onto your action bar
- **Floating button**: when in a raid, a draggable button shows the currently selected target — left-click to open the list, right-click to clear the selection, drag to move
- **`/md macro`**: (re)create or update the macro on demand
- **`/md float`**: toggle the floating button on/off
- **`/md help`**: command reference

## v1.0.0

- Initial release
- Raid/party roster list with class colors, online status, and click-to-select
- Secure cast button (`MDHelperCastButton`) bindable from Options > Key Bindings > MDHelper
- Persistent selection across sessions (`SavedVariablesPerCharacter`)
- Localized Misdirection spell name via `GetSpellInfo(34477)` (works on FR/EN/DE clients)
- Combat-safe: macro updates queued and replayed on combat exit
- Slash commands: `/md`, `/md clear`, `/md show`, `/md hide`
