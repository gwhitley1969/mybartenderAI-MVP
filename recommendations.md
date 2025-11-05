Version:1.0StartHTML:0000000181EndHTML:0000068382StartFragment:0000056449EndFragment:0000068342SourceURL:file:///C:/backup%20dev02/mybartenderAI-MVP/recommendations.docx<style></style>

Thanks for the write‑up—this **does** clarify what’shappening.

**🧭 Executive diagnosis**

You’ve combined two mutually incompatible configurations:

* In code you’re using an **MSAL‑style redirect URI**  
  msalf9f7…3045://auth as the app’s redirectUrl.
* At the same time you force **response_mode=query** in the authorization request.

When Azure Entra External ID (CIAM) sees an **msal{clientId}://auth** redirect, it completes native app flows via the special **/oauth2/nativeclient** bridge, which **expects a POST** (form_post). Because your request **forcesquery**, CIAM attempts a **GET** to the nativeclient endpoint—exactly whattriggers:

**AADSTS900561: The endpoint only accepts POST requests.Received a GET request.** (the error page you see at …ciamlogin.com).

There’s a second source of confusion: your app registrationmixes **CIAM** and **B2C** domains. Your runtime uses **mybartenderai.ciamlogin.com** for authorize/token, but one of the registered redirects is **https://mybartenderai.b2clogin.com/oauth2/nativeclient** (unchecked). Mixing these increases the chance of hitting the wrong endpointduring testing.

* * *

**✅ Two clean, workingconfigurations (pick one)**

**Option A — _Recommended for flutter_appauth_: StandardAppAuth redirect (no MSAL)**

Use a **custom scheme redirect** that AppAuth expects andkeep response_mode=query.

**Azure portal**

* **Remove/disable** MSAL‑only redirects:

* msal{clientId}://auth (unchecked/removed).

* Any …/oauth2/nativeclient entries (these are for MSAL).

* **Add/keep** a single custom redirect you control, e.g.  
  com.mybartenderai.app://oauth/redirect (you already list it; make sure it’s **checked**).

**Flutter code**

* In auth_config.dart set:

* redirectUrl: 'com.mybartenderai.app://oauth/redirect'

* **Remove** additionalParameters: {'response_mode':'query'} entirely (AppAuth will use the correct default for code+PKCE).

* Prefer **discovery** over hard‑coding endpoints (to avoid typos):  
  discoveryUrl: 'https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/v2.0/.well-known/openid-configuration?p=mba-signin-signup'.  
  Your current manual endpoints are CIAM‑correct, but discovery is safer.

* Keep the **authorization code + PKCE** you already use with flutter_appauth.

**Android/iOS**

* Android IntentFilter must match the new redirect exactly:  
  <data android:scheme="com.mybartenderai.app" android:host="oauth" android:pathPrefix="/redirect"/>.  
  (Right now it’s msal…://auth.)
* iOS: add the same scheme in CFBundleURLSchemes.

**Result**: After tapping **Continue**, the browserissues a **GET** to com.mybartenderai.app://oauth/redirect?..., which yourapp intercepts; AppAuth then exchanges the code for tokens via a **POST** tothe token endpoint—no /nativeclient, no 900561.

* * *

**Option B — If you want MSAL semantics: Use MSAL redirect+ nativeclient (form_post)**

If you prefer MSAL conventions, align everything to thatflow.

**Azure portal**

* **Keep** msal{clientId}://auth checked.
* **Add and check** the **CIAM** (not B2C) native client redirect:  
  https://mybartenderai.ciamlogin.com/oauth2/nativeclient (you currently list the **B2C** variant and it’s unchecked).

**Flutter code**

* Keep redirectUrl: 'msal{clientId}://auth'.
* **Change** the request to **response_mode=form_post** (or drop the parameter and let the server choose). Your current response_mode=query is the collision.
* Consider switching to an MSAL‑based plugin if you hit edge cases; flutter_appauth will still work if the app receives the final msal…://auth?code=… deep link.

**Result**: CIAM returns via **form_post** to /oauth2/nativeclient(server‑to‑server), which then forwards into your app on the msal…://auth URI.No GET hits /nativeclient, so no 900561.

* * *

**Why I’m confident this is the issue (from your notes)**

* Your redirectUrl is **msal…://auth** and you set **response_mode=query**. That’s the exact collision that yields a **GET** to a POST‑only endpoint.
* You observed the browser “hangs at **mybartenderai.ciamlogin.com** and, after refresh, shows AADSTS900561” — consistent with the browser landing on **/oauth2/nativeclient** via **GET**.
* Your app registration mixes **CIAM** runtime endpoints with a **B2C** nativeclient URL registered (and unchecked), which is easy to step on during experiments.

* * *

**“Do this now” checklist (no code changes beyond config)**

**If you choose Option A (AppAuth/custom scheme):**

1. Azure → App registration → _Authentication_:
* Uncheck/remove msal{clientId}://auth and any …/oauth2/nativeclient entries.
* Check com.mybartenderai.app://oauth/redirect.
3. Android/iOS: update deep link handlers to com.mybartenderai.app://oauth/redirect.
4. Code: set redirectUrl to that value; **remove** response_mode override; optionally supply discoveryUrl.

**If you choose Option B (MSAL/nativeclient):**

1. Azure: add & **check** https://mybartenderai.ciamlogin.com/oauth2/nativeclient.
2. Code: change additionalParameters to {'response_mode':'form_post'} (or omit entirely).

* * *

**Quick validation steps**

* Watch the **last URL** in the browser after consent:

* With **Option A**, it should be com.mybartenderai.app://oauth/redirect?code=…&state=….

* With **Option B**, you won’t see a user‑visible redirect; the app should resume via the msal…://auth deep link.

* Turn on verbose logging in flutter_appauth and confirm the code exchange is a **POST** to your token endpoint (the one you configured on ciamlogin.com).

* * *

**Bottom line**

Nothing is wrong with Flutter, Riverpod, or the user flowitself—the **redirect URI + response mode** combination is the culprit.Align the redirect **and** the response mode to a **single** pattern(AppAuth _or_ MSAL), and the **AADSTS900561** error will disappear.
