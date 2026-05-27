# Changelog

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
