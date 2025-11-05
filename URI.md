You’re hitting a **classic redirect‑URI mismatch**. The authorize request that leaves your app is still sending:
    redirect_uri = mybartenderai://auth

…but your Azure app registration no longer has that URI enabled (you switched to `com.mybartenderai.app://oauth/redirect`). When Entra CIAM compares the incoming `redirect_uri` with the set registered for **clientId f9f7f159‑b847‑4211‑98c9‑18e5b8193045**, it doesn’t find an exact match and throws:

> **AADSTS50011** – “The redirect URI specified in the request does not match the redirect URIs configured for the application.” (your screenshot).

From your prior notes and repo structure, the project has carried **multiple** redirect formats over time—`msal{clientId}://auth`, `mybartenderai://auth`, and `com.mybartenderai.app://oauth/redirect`—and the Flutter side reads its redirect from `lib/src/config/auth_config.dart` while Android captures it via an `intent-filter` in `AndroidManifest.xml`. That mix makes it easy for the runtime to keep using the old value even after portal changes.

* * *

Root cause in one line
----------------------

Your **current APK** is initiating the auth request with `redirect_uri=mybartenderai://auth`, but **Azure is expecting** `com.mybartenderai.app://oauth/redirect` (because that’s what you kept/checked in the portal). Hence **AADSTS50011**.

* * *

Fix it now (choose one and stick to it)
---------------------------------------

### Option A — Standardize on **`com.mybartenderai.app://oauth/redirect`** (recommended)

1. **Code (single source of truth)**
   
   * In `lib/src/config/auth_config.dart`, set **exactly**:
        redirectUrl: 'com.mybartenderai.app://oauth/redirect'

    and remove any other place that sets/overrides `redirectUrl` (including any flavor‑specific configs). Your earlier write‑ups point to this file as where it’s defined.

* In `AndroidManifest.xml`, keep only one `<intent-filter>` that matches the new URI:
  
      <data android:scheme="com.mybartenderai.app"
            android:host="oauth"
            android:pathPrefix="/redirect" />

    Remove stale filters like `<data android:scheme="mybartenderai" android:host="auth" />`.

* If you added a Gradle/string resource for AppAuth (e.g., `appAuthRedirectScheme`), make sure it’s **`com.mybartenderai.app`** and there’s no leftover `mybartenderai`.
2. **Azure (App registration → Authentication → Mobile and desktop applications)**
   
   * Ensure **`com.mybartenderai.app://oauth/redirect`** is present.
   
   * You may **remove** `mybartenderai://auth` and **all** MSAL/nativeclient entries to avoid future collisions. (You previously had MSAL and nativeclient entries listed; they aren’t needed for AppAuth.)

3. **Reinstall clean**
   
   * Uninstall the app from the device (this clears old intent handlers).
   
   * Install the new APK you built after the changes.
   
   * Sign in again. The last URL the browser hits should look like  
     `com.mybartenderai.app://oauth/redirect?code=…&state=…` — if you see `mybartenderai://auth`, you’re not running the fixed build.

### Option B — If you decide to keep **`mybartenderai://auth`** instead

1. **Azure**: add **`mybartenderai://auth`** back to _Mobile and desktop applications_ for this app registration.

2. **Code/Android**: keep the `mybartenderai` scheme consistently in `redirectUrl` **and** the manifest intent filter; remove the `com.mybartenderai.app` variant to avoid drift.

> Pick **one** redirect URI and make it authoritative across both **code** and **Azure**. Don’t keep multiple custom‑scheme URIs enabled during normal operation.

* * *

Why I’m confident this is the cause
-----------------------------------

* Your new screenshot shows the server rejecting **`mybartenderai://auth`** specifically. That’s a client‑side value—Azure is simply echoing what the app sent.

* Your earlier diagnostics show the project previously used both **`msal…://auth`** and **`mybartenderai://auth`**, with the redirect set in `auth_config.dart` and captured by Android via an intent filter. It’s very common to update the portal + manifest and miss a second place in code (or a build flavor) still pointing at the old URI.

* * *

Tight verification checklist (5 minutes)
----------------------------------------

1. **Log the outbound request** before calling `authorize()`:
      debugPrint('Auth redirectUrl: $redirectUrl');

  Confirm it prints `com.mybartenderai.app://oauth/redirect`.

2. **Grep your repo** for stragglers:
      grep -R "://auth" -n .
      grep -R "mybartenderai://" -n .
      grep -R "msal" -n .

  There should be **zero** hits for `mybartenderai://auth` and `msal…://auth` once you standardize.

3. **Device sanity**: Uninstall app → reboot device (optional) → install fresh APK.

4. **Browser last hop**: After consenting, the browser should hit **your** custom scheme (no `/oauth2/nativeclient`, no `mybartenderai://auth` if you chose `com.mybartenderai.app://…`).

5. **Keep CIAM consistent**: All endpoints on `…ciamlogin.com` and the **same** user flow/policy in `authorize` and `token` URLs (you already have this lined up).

* * *

### If it still fails after the steps above

The only remaining causes I’ve seen in the field:

* You’re installing an **old APK** (different build output path than expected).

* A **secondary code path** initializes `flutter_appauth` with its own hard‑coded `redirectUrl`. (Search for any direct `AuthorizationRequest`/`authorizeAndExchangeCode` calls with an inline redirect.)

* A **productFlavor** or **compile‑time config** injects an older redirect into release but not debug.

Make the `redirectUrl` a single constant, delete all others, and match Azure to that constant. That will eliminate **AADSTS50011**.

* * *

If you want, I can also produce a tiny “auth sanity” widget (Dart snippet) you can drop into the app that prints the effective `redirectUrl` and the exact authorize URL before launching the browser—handy for catching these mismatches early.
