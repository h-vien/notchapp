# NotchChat

NotchChat is a native macOS notch interface inspired by the interaction model of [nchat](https://github.com/d99kris/nchat). It turns the top-center camera area into a quiet unread indicator that expands into a focused messaging surface.

## Run

Requires macOS 14 or newer and Xcode 16.

```sh
swift run NotchChat
```

To create an ad-hoc signed app bundle:

```sh
cp .env.example .env
# Add the API ID/hash from https://my.telegram.org/apps to .env
sh scripts/build-app.sh
open build/NotchChat.app
```

The app uses the official TDLib JSON interface for a real Telegram user session. `ChatRequest` values flow to TDLib and ordered Telegram updates flow back to `ChatStore` as `ChatEvent` values.

## Architecture

- `NotchPanelController`: positions and animates a top-center `NSPanel` across Spaces.
- The panel reads the active display's safe-area and auxiliary top regions, leaving the physical camera notch completely empty. External displays automatically use the compact zero-inset layout.
- Hovering the notch opens the panel without a click; moving away collapses it after a short anti-flicker delay.
- `NotchPanelView`: compact unread glance, conversation list, message history, and composer.
- `ChatService`: transport-neutral request/event contract derived from nchat's `Protocol` interface.
- `DemoChatService`: deterministic local backend used for UI work and tests.
- `TelegramChatService`: real TDLib authorization, chats, history, incoming updates, read state, and text sending.
- `TelegramAuthView`: progressive API credential, phone, code, email, and 2FA authentication.
- `vendor/nchat`: unmodified upstream reference source; it remains under its own licenses.

## Telegram authorization

NotchChat opens directly with phone-number authorization when `TG_APIID` and `TG_APIHASH` are configured in `.env` before building. The build copies these values into the local app bundle so launching from Finder works; process environment variables override the bundled values. If neither source is configured, the app asks for credentials once and stores them in the macOS Keychain. Telegram's session database is stored under `~/Library/Application Support/NotchChat/Telegram`. Login codes and two-step-verification passwords are sent directly to TDLib and are not persisted by NotchChat.

`.env` is ignored by git. Like all TDLib desktop clients, the configured application API hash is present in the locally built app bundle; do not treat it as a user password or bot token.

