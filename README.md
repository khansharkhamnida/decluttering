# Decluttering

Snap. Sort. Bin. An iOS app that shows the photos you took **on this day** in past years, so you can keep the good ones and bin the rest, with a little help from Binny the bin.

**Website:** https://khansharkhamnida.github.io/decluttering/

## Features

- On This Day folders per year, with filters for photos, Live Photos, videos and screenshots
- Swipe sort with undo and a last look before anything is deleted
- Drag to select, look-alike finder, streaks, stickers and gentle break reminders
- Home screen widget with a Keep button
- 14 themes that restyle the whole app, the widget and the app icon

Photos stay on your device. There are no accounts, servers or analytics.

## Build

Requires Xcode 26 and iOS 26.

```sh
git clone https://github.com/khansharkhamnida/decluttering.git
open decluttering/decluttering.xcodeproj
```

Pick the `decluttering` scheme, set your own team under Signing & Capabilities, and change the App Group (`group.com.khansharkhamnida.decluttering`) to one you own.

## Layout

- `decluttering/` the app (VIPER modules, `Theme/` for the picker)
- `DeclutteringWidget/` the widget extension
- `Shared/` code used by both (themes, decision store, Binny's voice)
- `docs/` the GitHub Pages website
