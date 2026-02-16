# MindfulPhone

**[mindfulphone.app](https://mindfulphone.app)**

An iOS app that helps you be intentional about your phone usage. MindfulPhone blocks distracting apps and requires you to have a conversation with Claude AI before unlocking — encouraging a moment of reflection every time you reach for a distraction.

## How It Works

1. **Choose your distracting apps** — Pick the apps you want to be more mindful about (up to 50)
2. **Apps get shielded** — When you try to open a blocked app, a shield appears
3. **Explain your reason** — Tap "Request Access" and tell Claude why you need the app right now
4. **AI decides** — Claude evaluates your reason contextually (time of day, usage history, previous conversations) and grants temporary access if justified
5. **Auto-relock** — When the timer expires, the shield comes back

## Features

- **Per-app blocking** using Apple's Screen Time / Family Controls framework
- **AI-powered unlock** — Claude evaluates your reason considering time of day, usage patterns, and conversation history
- **Accountability partner** — optionally add a partner who gets notified if you bypass or disable protection
- **Tamper detection** — revoking Screen Time access resets the app and notifies your partner
- **Addictive app protection** — known addictive apps (Instagram, TikTok, etc.) hide the "Always Allow" button
- **Permanent exemption** — Claude can permanently unblock essential apps when asked
- **Temporary unlock timers** — approved apps unlock for a limited time, then re-lock automatically
- **Dark mode** — full adaptive color support

## Architecture

The project has two components:

### iOS App (4 Xcode targets)

| Target | Purpose |
|--------|---------|
| **MindfulPhone** | Main app — onboarding, chat with Claude, dashboard, history, settings |
| **ShieldConfigurationExtension** | Renders the shield UI when a blocked app is opened |
| **ShieldActionExtension** | Handles button taps on the shield (Request Access / Always Allow) |
| **DeviceActivityMonitorExtension** | Re-applies shields when unlock timers expire |

Shared code lives in `Shared/` and is compiled into all 4 targets.

### Claude Proxy (Cloudflare Worker)

A lightweight proxy at `claude-proxy/` that sits between the iOS app and the Anthropic API. It:
- Injects the Anthropic API key server-side (the iOS app never touches it)
- Rate limits requests (30 per 60 seconds per IP)
- Sends accountability partner notification emails via Resend

## Prerequisites

- macOS with Xcode 26.0+
- A physical iPhone (Screen Time APIs don't work in Simulator)
- An [Anthropic API key](https://console.anthropic.com/)
- A [Cloudflare account](https://dash.cloudflare.com/) (free tier works)
- A [Resend account](https://resend.com/) (free tier works — only needed for accountability partner emails)
- Node.js / npm

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/lgandecki/MindfulPhone.git
cd MindfulPhone
```

The repo contains two directories:
- `MindfulPhone/` — the iOS Xcode project
- `claude-proxy/` — the Cloudflare Worker proxy

### 2. Deploy the Claude Proxy

```bash
cd claude-proxy
npm install
```

Set the three required secrets:

```bash
# Your Anthropic API key
npx wrangler secret put ANTHROPIC_API_KEY

# A shared secret for authenticating the iOS app (generate one: openssl rand -base64 32)
npx wrangler secret put APP_SHARED_SECRET

# Your Resend API key (for accountability partner emails)
npx wrangler secret put RESEND_API_KEY
```

Deploy:

```bash
npm run deploy
```

Note the deployed URL (e.g., `https://mindfulphone-claude-proxy.<your-subdomain>.workers.dev`). You'll need it if you change the proxy URL in the iOS app.

### 3. Configure the iOS App

```bash
cd ../MindfulPhone   # from repo root: the iOS Xcode project directory
```

Create your secrets file:

```bash
cp Secrets.xcconfig.example Secrets.xcconfig
```

Edit `Secrets.xcconfig` and set `APP_SHARED_SECRET` to the same value you used for the Cloudflare Worker.

### 4. Build and Run

1. Open `MindfulPhone.xcodeproj` in Xcode
2. Update the **Team** in Signing & Capabilities for all 4 targets to your Apple Developer team
3. Update the **Bundle Identifiers** for all 4 targets to use your own prefix
4. Update the **App Group** identifier in all 4 targets to match your bundle ID
5. Select your physical iPhone as the build destination
6. Build and run (Cmd+R)
7. Follow the onboarding flow: authorize Screen Time → select apps to block → set up accountability partner → activate

> **Note:** If you change the proxy URL, update it in `ClaudeAPIService.swift` and `NotifyService.swift`.

## Known Limitations

- **50 app limit** — Apple's `store.shield.applications` silently fails beyond ~50 apps
- **Shield extensions are sandboxed** — the configuration extension can't write data or make network requests
- **New apps aren't auto-blocked** — newly installed apps are caught by category-level shielding but must be explicitly added for per-app control
- **Family Controls distribution entitlement** — TestFlight and App Store distribution require Apple's approval of the Family Controls entitlement, which is separate from the development entitlement used for Xcode builds

## License

[MIT](LICENSE)
