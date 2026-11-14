# Decluttering

Snap. Sort. Bin. An iOS app that shows the photos you took **on this day** in past years, so you can keep the good ones and bin the rest, with a little help from Binny the bin.

**Website:** https://khansharkhamnida.github.io/decluttering/  
**Privacy:** https://khansharkhamnida.github.io/decluttering/privacy.html  
**Support:** https://khansharkhamnida.github.io/decluttering/support.html

## Features

- On This Day folders per year, with filters for photos, Live Photos, videos and screenshots
- Swipe sort with undo and a last look before anything is deleted, and videos that play right on the card
- A seek bar in the photo viewer to skip through videos
- Drag to select, look-alike finder, stickers and gentle break reminders (after 40 and 100 photos)
- Streaks that days with nothing to sort never break
- An optional "Decluttering Keepers" album in Photos for the photos you keep
- Home screen widget with a Keep button, and a Binny "all sorted" card with your streak
- 14 themes that restyle the whole app, the widget and the app icon

Photos stay on your device. There are no accounts, servers or analytics.

## Build

Requires Xcode 26 and iOS 17 or later.

```sh
git clone https://github.com/khansharkhamnida/decluttering.git
open decluttering/decluttering.xcodeproj
```

Pick the `decluttering` scheme, set your own team under Signing & Capabilities, and change the App Group (`group.com.khansharkhamnida.decluttering`) to one you own.

## Layout

- `decluttering/` the app (VIPER modules, `Theme/` for the picker)
- `DeclutteringWidget/` the widget extension
- `Shared/` code used by both (themes, decision store, widget logic, Binny's voice)
- `declutteringTests/` 195 unit tests (presenters, streaks, widget logic, Keepers album)
- `docs/` the GitHub Pages website
