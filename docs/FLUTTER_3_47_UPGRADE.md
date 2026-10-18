# Flutter 3.47.7 Upgrade (from 3.35.5)

Upgrade record and regression checklist for `mobile/app`.
Prepared 2026-10-18 by Claude Code on the Windows dev PC, on top of `main` at `0f54b51` (v1.2.2+36, PR #2 merged).

> **Status (2026-10-18): built and tested on Windows. Not merged, not released, iOS not built yet.**
> - Branch `claude/wonderful-hopper-0f2f25`. The app version is still `1.2.2+36`, which the hotfix bundle already uses, so bump it before any store upload.
> - Android: a clean, signed release bundle builds on Flutter 3.47.7 and is signed with the upload key. Analyzer, Flutter tests and backend tests match the 3.35.5 baseline exactly.
> - iOS: the iOS 15 minimum and the CocoaPods setting are in the repo. Nothing has been built on the Mac yet.
> - **Next:** the [regression checklist](#regression-checklist) on both platforms.

---

## Why

- The PC's `flutter` moved to 3.47.x. Flutter 3.47's Gradle plugin refuses to build below **Gradle 8.14, AGP 8.11.1 and Kotlin 2.2.20**. The project had Gradle 8.12, AGP 8.9.1 and Kotlin 2.1.0, so v1.2.2 was built with a side-by-side Flutter 3.35.5 (see `DEPLOYMENT_STATUS.md`, October 2026).
- 3.47.7 is the current stable (released 2026-10-08, Dart 3.13.5).

## What changed

| | v1.2.2+36 (shipped) | This upgrade |
|---|---|---|
| Flutter / Dart SDK | 3.35.5 / 3.9.2 | **3.47.7 / 3.13.5** |
| Dart *language* version (`sdk:` lower bound) | 3.9 | 3.9 (unchanged, see Decision 3) |
| Gradle wrapper | 8.12 | **8.14.6** |
| Android Gradle Plugin | 8.9.1 | **8.13.2** |
| Kotlin Gradle Plugin | 2.1.0 | **2.3.21** |
| JDK for Gradle | 21 | 21 |
| Android compileSdk / targetSdk / minSdk | 36 / 36 / 24 | 36 / 36 / 24 |
| Android NDK (Flutter default) | 27.0.12077973 | 28.2.13676358 (already installed) |
| iOS minimum | 14.0 | **15.0** |
| iOS plugin manager | CocoaPods | CocoaPods (Swift Package Manager explicitly off) |
| Pub packages | | Only the 6 that the Flutter SDK pins: `characters` 1.4.0→1.4.1, `matcher` 0.12.17→0.12.20, `material_color_utilities` 0.11.1→0.13.0, `meta` 1.16.0→1.19.0, `test_api` 0.7.6→0.7.12, `vector_math` 2.2.0→2.4.3 |

No app dependency was upgraded. `purchases_flutter` stays on 10.4.3 (Google Play Billing 8.3.0), and `flutter_webrtc` stays on 0.12.12+hotfix.1.

### Files

- `mobile/app/pubspec.yaml`: `environment.flutter: ">=3.47.0"`, so an older Flutter fails at `pub get` instead of re-pinning the lockfile. Also `flutter.config.enable-swift-package-manager: false`. `sdk: ^3.9.2` stays, with a comment explaining why.
- `mobile/app/pubspec.lock`: the 6 pinned packages above.
- `mobile/app/analysis_options.yaml`: Flutter 3.47's migrator added `analyzer.exclude` (`build/**`, `android/**`, `ios/**`). It was moved below `include:`; Flutter re-adds any entry that's missing.
- `mobile/app/android/gradle/wrapper/gradle-wrapper.properties`: Gradle 8.14.6.
- `mobile/app/android/settings.gradle.kts`: AGP 8.13.2, Kotlin 2.3.21.
- `mobile/app/android/app/build.gradle.kts`: `android { kotlinOptions { … } }` (deprecated in Kotlin 2.x) became `kotlin { compilerOptions { jvmTarget = JVM_11 } }`, the 3.47 template form. Java/Kotlin target 11 is unchanged.
- `mobile/app/android/build.gradle.kts`: plugin modules that ask for compileSdk < 34 are compiled against 36 (Decision 4).
- `mobile/app/android/gradle.properties`: the migrator's `android.builtInKotlin=false` and `android.newDsl=false`, plus a comment. Both do nothing on AGP 8 (Decision 1).
- `mobile/app/ios/Podfile`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Flutter/AppFrameworkInfo.plist`: iOS 15.0 (Decision 5).
- `mobile/app/lib/src/services/background_token_service.dart`: `return Future.value(true)` → `return true` inside a `try`. This fixes the one new analyzer warning (`unawaited_return_in_try_block`) and doesn't change behavior.

## Decisions

Each decision lists what it costs if it turns out wrong.

1. **AGP 8.13.2 + Gradle 8.14.6, not AGP 9.** These are the newest releases inside AGP 8, and they clear every 3.47 error. AGP 9 changes defaults (built-in Kotlin, a new DSL, R8 and resource changes), so it deserves its own change and device test. *Cost:* every build prints Flutter's "support … will soon be dropped" warnings for Gradle (< 9.1) and AGP (< 9.0.1). When a later Flutter turns those warnings into errors, that upgrade must also do the AGP 9 / Gradle 9 move. The two `gradle.properties` flags are already set for it.
2. **Kotlin 2.3.21.** It's inside Kotlin's tested range for this pair (2.3.20–2.3.21: Gradle ≤ 9.3.0, AGP ≤ 9.0.0), and it clears Flutter's Kotlin warning (< 2.3.20). Kotlin 2.2.x is tested only up to AGP 8.11.1. *Cost:* none expected.
3. **Dart language version stays 3.9.** Raising `sdk:` to `^3.13.0` caused **46 compile errors** in the committed freezed 2.x files (`*.freezed.dart`): language 3.13 rejects the `final` constructor parameters that freezed 2.x generates. Raising it needs a freezed 3 migration and regenerated models first. *Cost:* none for the build. Newer language features wait for that migration.
4. **flutter_webrtc and share_plus are compiled against API 36; they weren't upgraded.** AGP 8.13 checks that every plugin module compiles against at least the `minCompileSdk` of its AndroidX dependencies. That's 34 for the libraries Flutter's embedding brings in, which are the same in 3.35.5 and 3.47.7. AGP 8.9.1 didn't enforce this on plugin modules. ([objectbox-dart#755](https://github.com/objectbox/objectbox-dart/issues/755) shows the same failure appearing with AGP 8.13.0.) Two plugins ask for older SDKs: `flutter_webrtc` 0.12.12+hotfix.1 (31) and `share_plus` 7.2.2 (33). Both are the last releases of their lines, so a real fix means major upgrades: flutter_webrtc to 1.6.x, which replaces the native WebRTC library under Voice AI, and share_plus to 13.x, which changes its API. `android/build.gradle.kts` uses AGP's `finalizeDsl` hook to compile such modules against 36 instead, and the build log names them: `Compiling :flutter_webrtc against android-36 (it asks for android-31)`. Their code and native libraries are unchanged: the WebRTC library in the new bundle is byte-identical to v1.2.2's. *Cost:* the override hides the problem if a future plugin is equally stale (the log line is the warning). Both plugin upgrades remain follow-ups.
5. **iOS 15.0 minimum, set in the repo.** Flutter 3.47 raises the iOS floor to 15.0. On the Mac's first build its migrator would rewrite the pbxproj (×3) and the Podfile's `platform :ios`, and remove `MinimumOSVersion` from `AppFrameworkInfo.plist`. Those edits are made here, so the PR shows them. The migrator does **not** touch the Podfile's `post_install` line that forces every pod to `'14.0'`. That line exists to keep all pods on one target (the flutter_secure_storage cold-start crash), so it's now `'15.0'` too. *Cost:* **iPhones still on iOS 14 stop receiving updates** and keep their last installed version. Every device that runs iOS 14 can update to iOS 15. Unverified until the Mac build.
6. **Swift Package Manager off for iOS.** 3.35.5 had SwiftPM off by default, so every shipped build used CocoaPods only. 3.47.7 turns it on by default, and on the Mac's first build it would rewrite the Xcode project and move SwiftPM-capable plugins (RevenueCat, MSAL and others) out of CocoaPods. Keeping CocoaPods limits this upgrade's iOS changes to the Flutter framework itself. *Cost:* one line to delete when SwiftPM gets its own migration. Flutter is moving to SwiftPM, so don't leave it long.
7. **Migrator edits accepted after review.** `analysis_options.yaml` excludes only non-Dart folders. The two AGP 9 flags in `gradle.properties` are inert on AGP 8: Flutter's Gradle plugin ignores them below AGP 9 (`isBuiltInKotlinEnabled()`). If either is removed, Flutter adds it back on the next run.

## Verification (Windows, 2026-10-18)

Baseline: unchanged `main` @ `0f54b51` on Flutter 3.35.5. After: this branch on Flutter 3.47.7.

| Check | 3.35.5 baseline | 3.47.7 |
|---|---|---|
| `flutter analyze` | 422 issues (94 errors, 45 warnings, 283 infos) | **422** (94 / 45 / 283). The same issues; one info is reported at a different column on the same line |
| `flutter test` | +31 −2 | **+31 −2**, the same tests with the same results |
| `test/services/voice_ai_service_test.dart` | 9/9 | **9/9**, including "the app closing its own connection is not an error" and Failed/Disconnected → error |
| Backend `npm test` (Jest) | 31/31 | **31/31** (no backend files changed) |

- Every one of the 94 analyzer errors predates this upgrade. They're in the two test files that don't compile (see below) and in five `lib/` files that nothing imports (`*_old.dart`, `ask_bartender_screen.dart`).
- **Signed bundle:** `flutter clean` + `flutter build appbundle --release` → `mobile/app/build/app/outputs/bundle/release/app-release.aab`, 96,985,371 bytes (92.5 MB), SHA-256 `801168514ce026ec123c94f8980f7c12158ae9f491dd5d6838d5c8a70e11c4c1`.
  - Signer SHA-256 `CD:02:8E:2F:59:1E:3B:A7:B8:D6:BA:72:09:BF:76:19:B8:7E:38:30:53:43:40:72:91:54:4D:AE:99:E5:8B:70`, the upload key (`keytool -printcert -jarfile`). `jarsigner -verify`: "jar verified."
  - Compared with the shipped v1.2.2 bundle (SHA-256 `73aa7e6e…`, 84.2 MB):
    - Merged manifest: the same versionCode 36 / 1.2.2, minSdk 24, targetSdk 36, and the same 18 permissions.
    - Native libraries: the same set for the same 3 ABIs. `libjingle_peerconnection_so.so` (WebRTC) and `libdatastore_shared_counter.so` are byte-identical. `libzstandard_android.so` is recompiled from the same source, so its bytes differ.
    - 16 KB page alignment is identical: every 64-bit library is ≥ 16 KB, and the one 4 KB library is 32-bit WebRTC, as before.
  - Most of the +12.8 MB is **Dart debug symbols** (`BUNDLE-METADATA/…/libapp.so.sym`, new in 3.47). Play keeps those for crash symbolication, and phones never install them. Shipped native code grew about 1 MB per ABI (newer engine). Dex and resources are the same size. The bundle no longer contains `AssetManifest.json`; the app never reads it.
- Expected build output: the two "soon dropped" warnings (Decision 1), the two `Compiling … against android-36` lines (Decision 4), and Java "source value 8 is obsolete" warnings from old plugins.

## Pre-existing problems found (not fixed here)

- **A fresh clone can't build a release.** Line 53 of the root `.gitignore` is `*.png`, apparently by accident, since it sits in the Node / Azure Functions section. So 22 generated Android PNGs never reached git: `android12splash` (×10), `splash` (×5), `ic_launcher_foreground` (×5) and `background` (×2). Tracked resource XML references all 22. On iOS, `LaunchBackground.imageset/background.png` never reached git either, and the launch screen uses it. Without that file Xcode only warns, and the launch screen ships without its background. Six AppIcon PNGs (50/57/72 pt) are also untracked, but the icon set doesn't reference them. The first build here failed at `:app:processReleaseResources` (`drawable/android12splash not found`) until the 22 Android files were copied from the main checkout, where they exist but are untracked. Fix: narrow the ignore rule and commit the referenced files.
- **`ios/Podfile.lock` in git is stale.** It still lists `purchases_flutter` 8.11.0, `msal_auth` 2.0.2 and `flutter_webrtc` 0.12.6. Commit the one `pod install` produces on the Mac.
- `test/services/apim_subscription_service_test.dart` (imports `package:app/…`, has no mockito mocks) and `test/widget_test.dart` (`MyApp` no longer exists) don't compile.

## Follow-ups

- AGP 9 + Gradle 9.x, with Flutter's template versions as the target (Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0), then built-in Kotlin. Gradle 9.1+ also runs on Android Studio's bundled Java 25, which would end the JDK 21 pin.
- Upgrade `flutter_webrtc` (1.6.x) and `share_plus` (13.x), then delete the compileSdk override in `android/build.gradle.kts`. The Voice AI push-to-talk test and the iPhone stop behavior must be re-checked.
- Swift Package Manager for iOS (delete the `config` line in `pubspec.yaml`).
- UIScene lifecycle (iOS). Flutter 3.47 warns on every iOS build, and its tool states that UIScene is **required on iOS 27 and later**, so this one has a deadline. The custom `AppDelegate` (notification taps) can't be auto-migrated, and MSAL's redirect handling has to move to the scene delegate.
- freezed 3, then raise the Dart language version.
- Commit the gitignored generated PNGs.

---

## Regression checklist

Run this before the upgrade ships. The marked items cover areas the upgrade actually touched. Everything else is a smoke test. The framework changes cited below come from Flutter's [breaking-changes list](https://docs.flutter.dev/release/breaking-changes) for 3.38–3.47.

### 0. Before testing

- [ ] Bump `version:` in `mobile/app/pubspec.yaml` (for example `1.2.3+37`). The hotfix bundle already uses `1.2.2+36`.
- [ ] Windows: build with `C:\src\flutter_windows_3.47.7-stable\flutter\bin\flutter.bat` (`flutter clean` first). The `flutter` on `PATH` is 3.47.1. It pins the same packages, but it lacks six patch releases of fixes.
- [ ] Building from a fresh clone or worktree instead of the main checkout? First copy the 22 Android PNGs and the two signing files over from the main checkout (`git ls-files --others --ignored --exclude-standard mobile/app` there lists them).

### 1. Mac: build setup (iOS)

- [ ] Install Flutter **3.47.7** exactly (`flutter --version`), the same version the Android build uses.
- [ ] Xcode: Flutter 3.47 requires ≥ 15 and recommends ≥ 16. Use the version App Store Connect currently requires for uploads. CocoaPods ≥ 1.16.2 is recommended (`pod --version`).
- [ ] `cd mobile/app && flutter clean && flutter pub get`, then `cd ios && pod repo update && pod install`. Expect `Podfile.lock` to change (it's stale), and commit it.
- [ ] Confirm `ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png` exists. It's gitignored, so a fresh Mac clone doesn't have it; copy it from the PC's main checkout. Without it, Xcode only warns and the launch screen loses its background.
- [ ] **`flutter build ios --release`**. Expected output: a warning that "UIScene lifecycle support will soon be required" (follow-up, ignore for now). There should be **no** "Updating minimum iOS deployment target" line, because the repo is already on 15.0.
- [ ] Run `git status` in `mobile/app/ios`. Flutter's other iOS migrators may touch `project.pbxproj`, the Runner scheme or `ios/.gitignore`. Review and commit them, or report anything odd. Nothing SwiftPM-related should appear (`FlutterGeneratedPluginSwiftPackage`); if it does, the `pubspec.yaml` setting didn't take effect.
- [ ] Archive in Xcode (Product → Archive). Watch for "compiling for iOS 14.0, but module … has a minimum deployment target of iOS 15.0". The Podfile change should prevent it.
- [ ] **Cold-start on a physical iPhone with a Release build** (`flutter run --release`). The Podfile's forced deployment target exists because of a flutter_secure_storage cold-start crash.

### 2. Both platforms (physical devices, release builds)

Android: connect a phone, `flutter clean`, `flutter run --release`. The Play upload stays gated on Gene's OK.

- [ ] **Install over the store build first**, since that's what every real user does. Install the current store version, sign in, stock My Bar, save favorites and let a Today's Special reminder get scheduled. Then install this build over it without uninstalling and check that:
  - you're still signed in (Keystore / Keychain)
  - the Recipe Vault database opens without a re-download
  - My Bar and favorites are intact
  - the reminder still fires
  - the subscription is recognized without buying again

  On Android this needs Play's internal testing track or internal app sharing, which means an upload and Gene's OK. Play re-signs store builds with the app signing key, so a build signed locally with the upload key can't install over them. On iOS, a TestFlight build installs over the App Store version.
- [ ] Launch: splash screen (Android 12+ animated icon), app icon, no crash on cold start.
- [ ] Sign in with Email, Google and Apple. The browser hands back to the app (MSAL redirect). Kill the app, relaunch, and confirm you're still signed in.
- [ ] Age verification for a new account.
- [ ] **Paywall gate:** a user without an entitlement lands on `/paywall` and can't back out of it (it uses `PopScope`). Start a trial, subscribe monthly/annual (sandbox or test track) and restore; the gate unlocks.
- [ ] **Voice-minute purchase** ($3.99 / 60 min). On Android this depends on `ProductCategory.nonSubscription`. Minutes are credited.
- [ ] **Voice AI:** microphone permission, push-to-talk, the AI replies and its transcript appears, stop. **iPhone: no "Error occurred" after a normal stop** (the v1.2.2 fix). The session ends and minutes are billed. Leave the voice screen with back while a session is live (`PopScope`).
- [ ] AI Bartender chat (send, receive, scroll); Create Studio AI refine.
- [ ] Smart Scanner: camera and photo-library permissions, scan, results added to My Bar.
- [ ] **Recipe Vault offline data:** fresh install → snapshot download and decompress (zstandard; its native library was rebuilt), then browse and search offline.
- [ ] Today's Special notification: permission prompt, scheduled reminder, and tapping it opens the cocktail (iOS: the custom `AppDelegate` notification code).
- [ ] Share a recipe card (system share sheet, Instagram, Facebook); Friends via Code; a `share.mybartenderai.com` link opens the app.
- [ ] WebViews: Privacy Policy and Terms. Academy and Pro Tools YouTube videos play right side up.
- [ ] Profile: settings, Sign Out, **Delete Account** (double confirm). Back gesture on the profile screen (`PopScope`).
- [ ] Background token refresh (workmanager): leave the app in the background for a few hours, come back, and you should still be signed in.
- [ ] In-app review prompt at a win moment (where the store allows it in test builds).

### 3. Android-specific

- [ ] **Page transitions:** the default Android route transition changed from Zoom (3.35.5) to `PredictiveBackPageTransitionsBuilder` (Flutter 3.38). Predictive back itself isn't enabled (the manifest has no `android:enableOnBackInvokedCallback`), so it falls back to the fade-forwards animation and screens animate differently. That's expected; check that navigation doesn't feel broken.
- [ ] **Material 3 visual pass** (Flutter 3.41 updated the M3 tokens): buttons, cards, chips, dialogs, bottom sheets, navigation bar, text fields. Compare with v1.2.2 screenshots if you have them.
- [ ] An older or low-end phone, or an emulator without Vulkan (Impeller's OpenGL ES path; 3.47 changed how GLES textures are stored): YouTube and WebView content renders right side up, no black screens.
- [ ] Debug run (`flutter run`): watch the console for new framework assertions. One example is 3.44's error for a `ListTile` inside a colored widget; six screens use `ListTile`.
- [ ] Android 13+ notification permission; edge-to-edge system bars look right.

### 4. iOS-specific

- [ ] All of section 2 on a physical iPhone, Release build (debug builds crash when launched from the home screen).
- [ ] VoiceOver spot check on headings (3.47 changed the semantics header / `headingLevel` behavior).
- [ ] TestFlight upload, gated on Gene's OK, and a final pass on the TestFlight build.
