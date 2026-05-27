# MDHelper

Lightweight Misdirection helper for Hunters on **WoW Classic Anniversary Edition**.

Pick a raid member from a list, then cast Misdirection on them with a single keybind or macro click — no targeting, no mouseover, no fuss.

## Features

- **Raid/party roster list** — names colored by class, online status shown, click to select
- **Floating raid button** — automatically appears in raids; shows the current MD target and stays out of the way otherwise. Left-click to open the list, right-click to clear, drag to reposition
- **Auto-created macro** — on first load, MDHelper creates a `MDHelper` macro with the Misdirection icon, ready to drag onto your action bar
- **Bindable** — a "MDHelper" entry appears under Options > Key Bindings, so you can bind the cast to any key
- **Persistent selection** — your last selected target is remembered across sessions
- **Localized** — the spell name is resolved via `GetSpellInfo(34477)`, so it works on French (Détournement), English (Misdirection), and other locales
- **Combat-safe** — selection changes during combat are queued and applied on combat exit

## Installation

1. Download or clone this repo
2. Copy the `MDHelper` folder into `World of Warcraft/_anniversary_/Interface/AddOns/`
3. Restart WoW or `/reload`

## Usage

1. Type `/md` (or click the floating button when in a raid) to open the list
2. Click a name to select them as your MD target
3. Cast Misdirection on them by either:
   - Pressing your bound key (set under Options > Key Bindings > MDHelper)
   - Clicking the auto-created `MDHelper` macro on your action bar

The selected name is shown both in the list header and on the floating button.

## Slash Commands

| Command | Description |
|---------|-------------|
| `/md` | Toggle the list window |
| `/md clear` | Clear the selected target |
| `/md macro` | (Re)create or update the `MDHelper` macro |
| `/md float` | Toggle the floating raid button |
| `/md help` | Show command reference |

## How it works

MDHelper builds a hidden `SecureActionButton` named `MDHelperCastButton` with a dynamic macro of the form:

```
/cast [@<selected>,help,nodead][@<selected>] Misdirection
```

The button updates whenever you change your selection (outside of combat — changes made during combat are queued and applied as soon as combat ends). The auto-created macro is a simple `/click MDHelperCastButton`, so binding the keybind or clicking the macro both route through the same secure cast.

## License

MIT
