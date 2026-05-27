# Changelog

## v1.5.0

- **Robustness**: the action-bar macro now contains the actual `/cast` line, not `/click MDHelperCastButton`. The macro body is kept in sync with the selected target on every roster/selection change (out of combat). This eliminates the entire `/click`-on-secure-button indirection that was fragile in TBC 2.5.5 and makes the macro tooltip show the spell directly. The secure button is still created so the keybind (Options > Key Bindings > MDHelper) keeps working unchanged
- **Favorites / pinned**: right-click a name in the list to pin them at the top. Tanks (Main Tank assignment or role = TANK) are auto-pinned. A yellow star icon marks pinned rows. Tanks are flagged with a blue **T** next to their name
- **Floating button**: removed the "MD" label (the icon already conveys the spell) and gave the selected name the class color, vertically centered. Bigger icon, cleaner layout
- **ESC closes the window**: the list frame is registered in `UISpecialFrames`

## v1.4.0

- **Fix**: the secure cast button is no longer `Hide()`-ed. In TBC 2.5.5 the `/click` slash command silently fails on hidden secure buttons, which made the macro and the keybind do nothing. The button is now sized 1×1, alpha 0, mouse disabled — invisible to the user but properly visible to the secure-action handler

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
