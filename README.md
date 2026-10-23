# FamNest — Offline Family Chat over Wi‑Fi

**FamNest** is a private family messenger that works over your **home Wi‑Fi without internet**. Family members can chat, share photos and send files to each other. There are no accounts, no cloud servers and no phone numbers, and **all data stays on your family's own devices**.

> Store listing: *FamNest: Offline Family Chat — private Wi‑Fi messenger, no internet needed*

## Features

| | |
|---|---|
| 💬 Real-time messaging | Instant text messages with typing indicators, sending status and delete for everyone |
| 🏠 Family group chat | One shared conversation with everyone, plus custom groups and one-to-one chats |
| 📶 Works without internet | Uses only the local Wi‑Fi network between devices |
| 📷 Photos & files | Share photos (with blurred previews) and documents up to 200 MB |
| 🔎 Automatic discovery | Finds the family hub with mDNS/Bonjour and a UDP broadcast fallback, so nobody types IP addresses (manual entry is still available) |
| 🗂️ Message history | Stored in SQLite on each device. A device that was away syncs automatically when it comes home |
| 👨‍👩‍👧 Profiles & presence | Names, profile photos, online status and last seen |
| 🔐 Privacy & security | Invite-code authentication, mutual device/hub verification, encrypted transport and end-to-end encrypted content |
| 🔔 Local notifications | On-device notifications only, with no push service |
| 🌐 Languages | English and Sinhala (සිංහල) |

## How it works

```
 Family member A ──┐                         ┌── Family member B
                   │   home Wi‑Fi (no internet)  │
                   └──►  Family hub (a device) ◄─┘
                         routes encrypted messages,
                         stores encrypted history for
                         devices that were offline
```

* **The hub runs inside the app.** When someone chooses *Set up a new family*, that device becomes the family hub. A spare Android phone or tablet that stays plugged in at home works well for this. On Android the hub runs as a foreground service, so it keeps working in the background and restarts after a reboot.
* **Optional headless hub.** The same hub code can run on an always-on computer or Raspberry Pi (see below).
* Each device connects to the hub over a WebSocket on the LAN (`ws://<hub>:47820/ws`). Every frame is protected by FamNest's own encryption layer.

## Security model

| Layer | What it does |
|---|---|
| **Invite code** | 16 characters (~79 bits of entropy), shown on the hub. It's required to join and never sent over the network. |
| **Mutual authentication** | The device proves it knows the code (HMAC-SHA256 over fresh nonces) and owns its identity key (Ed25519 signature). The hub proves it knows the code too, so a rogue device can't pose as the hub. Failed attempts are rate-limited. |
| **Device identity** | The device ID is the fingerprint of the device's Ed25519 key, so no one can impersonate another member. |
| **Transport** | Per-session, per-direction AES-256-GCM keys (HKDF). Frames use counter nonces, so replayed, reordered or dropped frames are rejected. |
| **End-to-end content** | Message bodies, photos and files, names, profile photos and group names are encrypted on the sending device. **The hub stores only ciphertext.** |
| **Direct chats** | Encrypted with an X25519 key shared only by the two people, so even other family members who hold the family key can't read them. |
| **Revocation** | The hub owner can remove a member and issue a new invite code. |
| **Storage** | Keys are kept in the Android Keystore / iOS Keychain (*this device only*). Android cloud backup and device transfer are disabled, and the data directory is excluded from iCloud backups. *Leave family & erase data* wipes everything. |

The hub does see routing metadata: who sends to which conversation, when, and message sizes.

## Project structure

```
lib/
  shared/              Pure Dart (no Flutter), shared by the app and headless hub
    protocol.dart        Wire constants & message types
    crypto.dart          Key derivation, AEAD helpers, invite codes
    secure_channel.dart  Encrypted, replay-protected WebSocket channel
    handshake.dart       Mutual-auth handshake (client side)
    content_crypto.dart  End-to-end encryption of messages, profiles, groups
    device_keys.dart     Ed25519 + X25519 device identity
    hub/                 Hub server, SQLite store, UDP discovery responder
  data/                On-device SQLite database & secure keystore
  services/            ChatService (sync, outbox, files), discovery,
                       notifications, hub hosting (foreground service)
  features/            Screens: onboarding, chats, chat, groups, settings, hub
  core/                Providers (Riverpod), router (go_router), theme, formatting
bin/famnest_hub.dart   Headless hub for a PC / Raspberry Pi
test/                  Protocol tests + end-to-end ChatService tests
```

## Getting started

Requirements: Flutter 3.44+ (Dart 3.12+).

```bash
flutter pub get
flutter run --flavor dev            # development build ("FamNest Dev")
flutter run --flavor prod           # production flavour
flutter test                        # protocol + end-to-end tests
```

### Release builds

**Android:** create `android/key.properties` (it's ignored by git):

```properties
storeFile=/path/to/famnest-release.jks
storePassword=...
keyAlias=famnest
keyPassword=...
```

Then build with `flutter build appbundle --flavor prod`.

**iOS:** set your team in Xcode, then build with `flutter build ipa --flavor prod`.

### Headless hub (optional, for an always-on home computer or Raspberry Pi)

```bash
dart run bin/famnest_hub.dart --data ./famnest-hub --family "The Perera Family"
```

The hub prints its invite code and LAN address. Family members tap *Join my family*, pick the hub, and enter the code. The hub advertises itself over mDNS through `dns-sd` (macOS) or `avahi-publish-service` (Linux) when they're available, and it always answers UDP discovery. Options: `--port`, `--rotate-code`.

## Platform notes

* **Android:** the hub and the optional *Stay connected in background* setting use a foreground service of type `remoteMessaging`. For the most reliable hub, allow FamNest to ignore battery optimisation (Settings → Family hub).
* **iOS / iPadOS:** iOS doesn't allow background servers, so a hub on an iPhone runs only while FamNest is open. Use an Android device or the headless hub as the always-on hub. iOS members receive messages while the app is open or recently backgrounded, and anything they missed syncs when they reopen the app.
* All devices must be on the same Wi‑Fi network. Some routers isolate clients ("AP/client isolation"). If discovery fails, turn that off or enter the hub's IP address manually.

## Wire protocol (v1)

1. Hub → device: `hello {familyId, familyName, nonce}`, sent in the clear
2. Device → hub: `auth {deviceId, signKey, dhKey, nonce, mac, sig}`
3. Hub → device: `auth_ok {mac}` or `auth_fail {reason}`
4. Both sides switch to encrypted binary frames (JSON or file chunks)
5. Hub → device: `welcome`, then the device sends `sync {since}`, its outbox, and any profile update

Message types: `send/ack/msg/batch/delete`, `profile/member/presence`, `conv_upsert/conv`, `typing`, `file_put/file_ack/file_ok`, `file_get/file_info`, `error`.

## App Store screenshots

Ready-to-upload screenshots live in `store/app-store-screenshots/`:

| Folder | Size | App Store Connect slot |
|---|---|---|
| `iphone-6.3/` | 1206 × 2622 | iPhone with Dynamic Island (6.3"/6.1"; scales to smaller iPhones) |
| `ipad-13/` | 2064 × 2752 | iPad 13" |

They're real captures of the app in **demo mode** (a sample family, no networking), framed with a headline. To regenerate after UI changes:

```bash
tool/store/capture_store_screenshots.sh     # builds the demo app, captures raw/ on dedicated simulators
python3 tool/store/make_store_screenshots.py # frames raw captures; edit COPY there to change headlines
```

Product page **Header** and **Search Results** assets (built from the same captures):

| File | Size | App Store Connect slot |
|---|---|---|
| `store/app-store-header/header-3840x1646.png` | 3840 × 1646 | Header (wide) |
| `store/app-store-header/header-5244x2950.png` | 5244 × 2950 | Header (16:9) |
| `store/app-store-search-results/search-results-3840x2560.png` | 3840 × 2560 | Search Results |
| `store/app-store-search-results/search-results-1920x1280.png` | 1920 × 1280 | Search Results |

```bash
python3 tool/store/make_store_banners.py
```

Demo mode is only compiled in with `--dart-define=FAMNEST_DEMO=true`; regular builds never contain it.
