# Project Services — Flutter App Build Report (MVP + in-app chat + FCM)

Date: 13 November 2026 (chat added 13 Nov ~21:35 PKT)
Status: **App code complete, in-app chat built, `flutter analyze` clean (0 errors), 3/3 tests pass. APK NOT BUILT — blocked by a sandbox network permission (see §5). No APK file exists yet.**

---

## 1. Toolchain installed

| Tool | Version / location |
|---|---|
| Flutter SDK | 3.50.0 stable (revision ab2912035e), `~/flutter` |
| Dart | 3.14.0 (bundled with Flutter) |
| JDK | Temurin 17.0.21, `~/jdk17` |
| Android SDK | `~/android-sdk` — cmdline-tools latest, platform-tools 37.0.3, platforms android-35 + android-36, build-tools 35.0.0 + 36.0.0 |
| Gradle | 9.5.0 (distribution pre-downloaded to `~/downloads/gradle-9.5.0-all.zip`) |
| `flutter doctor` | Flutter ✓, Android toolchain ✓ (SDK 36.0.0), Chrome ✗ (not needed), Linux toolchain ✗ (not needed). License status shows "unknown" because sdkmanager cannot reach the network from Java (proxy) — license files were written manually to `~/android-sdk/licenses/` (see §2). |

PATH exports (Flutter, JDK, Android SDK) are in `~/.bashrc` so future sessions pick them up.

## 2. Environment workarounds (all in this VM only)

The VM's egress proxy breaks Java networking, so several manual steps were needed:

- **Java proxy tunneling fails** (`sdkmanager` / Gradle wrapper throw `NoSuchElementException` in `HttpURLConnection.doTunneling`). Fix: Android SDK packages were downloaded directly with `curl` (which handles the proxy) from `dl.google.com` using the package URLs parsed out of `repository2-1.xml`, then extracted into `~/android-sdk` by hand (platform-tools, build-tools 35.0.0/36.0.0, platforms android-35/android-36).
- **Gradle wrapper cannot download Gradle** (same Java proxy failure). Fix: `gradle-9.5.0-all.zip` downloaded with `curl`, and `android/gradle/wrapper/gradle-wrapper.properties` now points at it via `distributionUrl=file:///home/hatch/downloads/gradle-9.5.0-all.zip`. (Original URL saved in `gradle-wrapper.properties.bak`. Revert that line if the project is ever built on a machine with normal network access.)
- **Proxy MITM CA**: the egress proxy terminates TLS, so the proxy CA bundle (`/run/hatch/egress-tls/ca-bundle.pem`, 121 certs) was imported into the JDK truststore (`~/jdk17/lib/security/cacerts`).
- **Gradle proxy + low memory**: `~/.gradle/gradle.properties` and `/root/.gradle/gradle.properties` carry the egress proxy (host/port/user/password) and low-memory settings (`-Xmx1024m`, `MaxMetaspaceSize=256m`, `--no-daemon`, 2 workers). Note: Gradle's user home resolves to `/root/.gradle` here (JVM `user.home` for root), NOT `~/.gradle` — both copies are kept in sync.
- **Project heap**: `android/gradle.properties` `org.gradle.jvmargs` lowered from `-Xmx8G` to `-Xmx1024m` (the VM has ~0.5 GB free RAM at build time).
- **Android licenses**: written manually to `~/android-sdk/licenses/` (well-known `android-sdk-license` / `android-sdk-preview-license` hashes) because `sdkmanager --licenses` cannot reach the network from Java.

## 3. Project

Path: `~/workspace/servicehub-flutter` (package `project_services`, display name "Project Services", org `com.projectservices`).

Supabase: same project as the website (`project-services`, `https://xnulisgpagdzrmktsmpj.supabase.co`). Config in `lib/config.dart` (URL + anon key, generated from the website's `.env.local`; the anon key is a public client key, already embedded in the website). No service-role key anywhere.

Dependencies: `supabase_flutter ^2.18.3`, `flutter_map ^8.3.2`, `latlong2 ^0.10.1`, `image_picker ^1.2.4` (plus `cupertino_icons`). `flutter pub get` works through the proxy.

### Screens / flows built

- **Auth** (`lib/screens/auth_screen.dart`): login + signup (email/password, name, phone, role customer/provider), same flow as the website (profiles row via `ensureProfile`; email confirmation ON).
- **Customer shell** (`customer_shell.dart`) — bottom nav Home | Categories | Bookings | Messages | Profile:
  - Home: greeting, search (live service search), popular categories (LIVE from Supabase), OpenStreetMap view (Lahore, `flutter_map` + OSM tiles), recommended technicians (approved providers, live).
  - Categories: live list of the 7 categories → services with live prices.
  - Providers: approved providers for a service with verification badge, experience, rating, city, availability and their own charge (from `provider_skills`, falls back to the service base price).
  - Booking (`booking_screen.dart`): problem description, photo picker (up to 5, `image_picker` → Storage bucket `booking-media`, same `{customer_id}/{booking_id}/{timestamp}-{filename}` convention as the website), date/time, address + city, price breakdown (job price, 15% platform fee, technician receives 85%), confirm → saves a real `bookings` row (status pending, payment pending, COD) and shows the booking ID + tracking link.
  - Tracking (`tracking_screen.dart`): status timeline (pending → accepted → on_the_way → in_progress → completed) from `booking_status_history`, uploaded photos, history list, and a **Chat button** (opens the booking's chat thread; shown once a technician is assigned).
  - Profile: personal info, booking history, my ratings, log out.
  - Messages: live conversations list (see §3b — in-app chat).
- **Provider shell** (`provider_shell.dart`) — bottom nav Dashboard | Jobs | Messages | Earnings | Profile:
  - Dashboard: verification status chip, availability toggle (writes `provider_profiles.is_available` AND the 7 per-day `availability` rows), latest jobs.
  - Jobs: assigned bookings with Accept / Reject / On the way / Work started / Mark completed (writes `bookings.status` + a `booking_status_history` row). "View details" opens the tracking screen, which has the Chat button.
  - Messages: live conversations list (see §3b — in-app chat).
  - Earnings: totals from `commission_ledger` (earned, 15% fee, completed jobs) with an Rs. 0 empty state; customer reviews.
  - Profile: info + log out. (Editing services/charges/CNIC stays on the website for now.)
- **Design**: same brand as the website (deep teal #0C4A4A, warm sand #FAF7F0, amber #D9A03F), original layout, no copied design. Admin is web-only (website `/admin`), not in the app.

### 3b. In-app chat (added 13 Nov ~21:35 PKT)

Customer ↔ provider chat, one thread per booking, using the `conversations` + `messages` tables from migration 001.

- **Models** (`models.dart`): `Conversation` (id, bookingId, customerId, providerId, createdAt + display fields serviceName / otherPartyName / lastMessageText / lastMessageAt / unreadCount, with `copyWith`) and `ChatMessage` (id, conversationId, senderId, messageText, isRead, createdAt).
- **Repository** (`repository.dart`): `fetchMyConversations()` (customer: their bookings; provider: their assigned jobs; enriched with service name, other party name, last message, unread count), `getOrCreateConversation(bookingId)` (returns the existing thread or creates it), `fetchMessages()`, `sendMessage()`, `markMessagesRead()`, and `subscribeToConversationMessages()` (Supabase Realtime INSERT subscription on `messages`, filtered by conversation).
- **Screens** (`screens/chat_screen.dart`): `ConversationsScreen` (list with other-party avatar/name, service, last-message preview, time, unread badge; pull-to-refresh; empty state) and `ChatDetailScreen` (message bubbles — own right/teal, other left/sand — text input + send, Realtime live updates, marks messages read, auto-scrolls to the latest).
- **Entry points**: Messages tab in both shells (customer: replaces the old "coming soon" placeholder; provider: new 5th tab), and a Chat button on the tracking screen (both roles; shown once a technician is assigned).
- **RLS note**: migration 001 only lets the *customer* insert into `conversations`, so a provider could only reply after the customer messaged first. Migration 003 (`supabase/migrations/003_chat_provider_insert_realtime.sql`) adds `conversations_insert_provider` (assigned provider may start a thread for their own booking) and adds `messages` to the `supabase_realtime` publication for live delivery. Migration 003 APPLIED LIVE 13 Nov ~21:42 PKT via the browser SQL Editor ("Success. No rows returned", no error).

### 3c. FCM push notifications (added 13 Nov ~22:28 PKT)

- **Firebase project**: "Project Services" (`project-services-70468`, Spark free plan, Analytics OFF), Android app `com.projectservices` registered (app ID `1:188396187964:android:2bde014d0c84c9f6972e39`). `google-services.json` is in `android/app/google-services.json`.
- **Flutter** (`lib/services/notification_service.dart` + `lib/main.dart`): `firebase_core` + `firebase_messaging`; requests permission, saves the device token to Supabase (`device_tokens`, upsert on token), listens for token refresh, shows foreground messages as a SnackBar (via the app's `scaffoldMessengerKey`), and registers a background handler. `NotificationService.init()` is safe to call even without Firebase configured (logs and continues).
- **Database** (migration 004, `supabase/migrations/004_device_tokens.sql`, applied live): `device_tokens` table (user_id, token UNIQUE, platform) + index + 5 RLS policies (own tokens only, admin all).
- **Server-side** (`supabase/functions/send-booking-notification/index.ts`, deployed live): Edge Function triggered by a database webhook on `public.bookings` (INSERT + UPDATE). On a new booking it notifies the provider; on a status change it notifies the other party (provider actions → customer; cancelled/disputed → provider). Sends via FCM HTTP v1 using a service-account JWT (RS256, Web Crypto) and records a row in `notifications`. Secrets `FIREBASE_PROJECT_ID` + `FIREBASE_SERVICE_ACCOUNT` are saved in the dashboard (service-account value verified byte-identical via SHA-256; function redeployed after). Webhook `booking-notification-webhook` (POST, Authorization: Bearer anon key) is created and verified. Smoke test passed: a fake INSERT payload returned HTTP 200 `{"skipped": "no recipient"}`.
- **Note**: the Firebase service account has two keys — the console-downloaded one (unused) and the Cloud-Shell-generated one stored in Supabase (in use). The unused key was not deleted.
- **Not yet tested live**: a real push to a device needs the APK on a phone with a saved FCM token.

## 4. Verification so far

- `flutter analyze`: **no errors** (0 errors; remaining issues are `warning`/`info` — unnecessary casts in pre-existing code + the Flutter 3.50 `package:flutter/material.dart` deprecation notice across all files). The new chat + FCM code is warning-free.
- `flutter test`: **3/3 passed** (auth screen smoke test + 2 chat-model unit tests in `test/chat_models_test.dart`).
- `flutter pub get`: works.
- **APK build: NOT DONE (blocked, §5).** No APK file exists under `build/app/outputs/`.

## 5. BLOCKED — Gradle daemon cannot talk to itself (sandbox blocks Java TCP)

**Symptom:** every Gradle invocation fails in ~4 s with `Could not dispatch a message to the daemon` / `Broken pipe`, whether run via `flutter build apk`, `./gradlew`, the extracted Gradle binary directly, with `--no-daemon`, with or without proxy settings, and with a fresh daemon registry. The daemon itself starts fine (log shows it listening on `127.0.0.1:41383` and "Daemon server started"), then its health check finds its own registry entry gone and it shuts down.

**Root cause (proven):** the sandbox denies inter-process TCP for Java processes (`other_tcp` was Deny). Evidence:
- Java server + Java client on `127.0.0.1`: the client connects but reads back the sandbox message — *"muse: Other TCP connections is turned off for this assistant. To allow it, ask the user to open Muse settings -> Permissions -> Direct network protocols and switch other_tcp from Deny to Ask."*
- Java server + Python client: the Java server accepts and reads "ping", but its reply never arrives (Python client times out).
- Python server + Python client on `127.0.0.1`: works fine ("ping" → "pong"). So localhost TCP itself works — only Java processes are blocked.

Gradle's daemon architecture *requires* the client JVM to talk to the daemon JVM over localhost TCP, so no Gradle build can run while this permission is Deny. This is not a code, memory, or proxy problem — those were all fixed (§2) and the failure is identical with the proxy removed.

**Update 13 Nov ~21:19–21:22 PKT:** the user changed `other_tcp` to Ask, then to **Allow** — but Java localhost TCP **still fails** (TcpTest2: 0 bytes read / read timed out) and every Gradle build still fails with "daemon could not be connected to" / "The first result from the daemon was empty", even with `org.gradle.daemon=false` added to `android/gradle.properties` and stale daemons killed + the daemon registry cleared. Each Gradle daemon binds a RANDOM localhost port and each port needs its own grant, so per-port approvals do not stick. The `other_tcp=Allow` setting has NOT taken effect in the running VM — the sandbox policy is most likely loaded at VM start. **Likely fix: a VM restart** (deployments replace the VM, often hourly) should load `other_tcp=Allow`, after which `flutter build apk --debug` should work.

**Retry scheduled:** cron `apk-build-retry-after-vm-restart` (every 30 min, first run ~22:01 PKT 13 Nov) tests Java TCP and, once it works, builds the debug APK and delivers it to the user, then removes itself. The user approved this schedule.

After the VM restarts, re-run:
```bash
cd ~/workspace/servicehub-flutter
flutter build apk --debug
flutter build apk --release
```
Everything else is ready: the toolchain, SDK, licenses, proxy config, Gradle distribution and the app code are all in place, and `flutter analyze` is clean. First build will download the Android Gradle Plugin / Kotlin dependencies through the proxy (already configured in `gradle.properties`).

## 6. Left for a next step (after the APK builds)

- Release signing: the release APK will be signed with the debug keystore by default. A real release keystore is NOT created — ask before creating one.
- Play Store listing — distribution is APK sideload first, per the user's decision.
- Provider profile editing (services/charges/CNIC) inside the app — currently website-only.
- Live two-user chat test: the chat code is verified by `flutter analyze` + unit tests and migration 003, but a real customer↔provider message exchange has not been tested live yet — test it on the APK with two accounts once it builds.
- Live push test: FCM is wired end to end (app token + Edge Function + webhook) and the smoke test passed, but a real push to a device has not been tested yet — test it on the APK on a phone once it builds.
