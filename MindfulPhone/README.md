# MindfulPhone

An iOS app that helps you be intentional about your phone usage. MindfulPhone blocks distracting apps and requires you to explain your reason for opening them to an AI before unlocking — encouraging a moment of reflection every time you reach for a distraction.

## How It Works

1. **Choose your distracting apps** — Pick the apps you want to be more mindful about (up to 50)
2. **Apps get shielded** — When you try to open a blocked app, a shield appears
3. **Explain your reason** — Tap "Request Access" and tell Claude AI why you need the app right now
4. **AI decides** — Claude evaluates your reason and grants temporary access if it's justified
5. **Always Allow** — For essential apps you blocked by mistake, tap "Always Allow" to permanently exempt them

## Features

- **Per-app blocking** using Apple's Screen Time / Family Controls framework
- **AI-powered unlock** — Claude evaluates your reason contextually, considering time of day and usage history
- **Addictive app protection** — Known addictive apps (Instagram, TikTok, etc.) hide the "Always Allow" button
- **Permanent exemption** — Claude can permanently unblock essential apps when asked
- **Self-reporting app names** — iOS doesn't expose app names to extensions, so the app learns names as you use it
- **Temporary unlock timers** — Approved apps unlock for a limited time, then re-lock automatically

## Architecture

The app uses 4 Xcode targets required by Apple's Family Controls framework:

| Target | Purpose |
|--------|---------|
| **MindfulPhone** | Main app — onboarding, chat with Claude, settings |
| **ShieldConfigurationExtension** | Renders the shield UI when a blocked app is opened |
| **ShieldActionExtension** | Handles button taps on the shield (Request Access / Always Allow) |
| **DeviceActivityMonitorExtension** | Re-applies shields when unlock timers expire |

Shared code lives in `Shared/` and is linked to all 4 targets.

## Requirements

- iOS 26.0+
- Xcode 26.0+
- A [Claude API key](https://console.anthropic.com/) (entered during onboarding)
- A physical iPhone (Screen Time APIs don't work in Simulator)

## Setup

1. Clone the repo
2. Open `MindfulPhone.xcodeproj` in Xcode
3. Update the bundle identifier and App Group to match your team
4. Build and run on a physical device
5. Follow the onboarding flow to authorize Screen Time, select apps, and enter your API key

## Known Limitations

- **50 app limit** — Apple's `store.shield.applications` silently fails beyond ~50 apps. Select your most distracting apps rather than everything.
- **Shield extensions are sandboxed** — The configuration extension can't write data or make network requests. App names are learned through user self-reporting.
- **New apps aren't auto-blocked** — Newly installed apps must be manually added via Settings.

## License

[MIT](LICENSE)
