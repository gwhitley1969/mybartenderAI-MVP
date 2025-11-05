**Yes — I agree with that plan.**  
It aligns exactly with the “Option A (AppAuth/custom scheme)” fix I recommended earlier: use a **custom‑scheme redirect**, remove the **MSAL/nativeclient** pieces, and let `flutter_appauth` do a standard **Authorization Code + PKCE** flow.

### Why your checklist is correct

* **Redirect changed to** `com.mybartenderai.app://oauth/redirect` → This is the right style for AppAuth and results in a **GET to your app**, not to a POST‑only bridge endpoint.

* **Removed `response_mode=query`** → Good. For code+PKCE, AppAuth and Entra will default correctly; explicitly forcing a mode isn’t needed and sometimes creates odd behavior when MSAL endpoints are present.

* **Android intent filter & Gradle scheme updated** → Necessary so Android can capture the custom scheme.

* **Azure updates**
  
  * ✅ **Check** `com.mybartenderai.app://oauth/redirect` under _Mobile and desktop applications_.
  
  * ❌ **Uncheck/Remove** `msal{clientId}://auth` (MSAL only).
  
  * ❌ **Uncheck/Remove** any `…/oauth2/nativeclient` entry (that bridge expects **form_post** and is what caused AADSTS900561 when hit via GET).

That removes the GET‑to‑POST‑only mismatch and should stop **AADSTS900561**.

* * *

A few extra guardrails (do these too)
-------------------------------------

1. **Use only CIAM domains everywhere.**  
   Your `authorize` and `token` endpoints should both be on `…ciamlogin.com` and reference the same **policy/user flow**. Don’t mix any `b2clogin.com` entries anywhere in the app or registration.

2. **(Optional but safer) Use discovery.**  
   Instead of hard‑coding endpoints, point AppAuth at CIAM discovery:  
   `https://<tenant>.ciamlogin.com/<tenant>.onmicrosoft.com/v2.0/.well-known/openid-configuration?p=<policyName>`

3. **iOS parity.**  
   Add `com.mybartenderai.app` to `CFBundleURLSchemes` (and remove any `msal…` scheme there).

4. **Keep “Allow public client flows” = Yes** and leave **Implicit grant** toggles Off.  
   (You’re using code+PKCE; you don’t need implicit.)

5. **Remove unused web redirects** from mobile testing paths.  
   If `https://jwt.ms` or similar is listed, keep it unchecked so the mobile flow never lands there by mistake.

* * *

Quick smoke test (5 steps)
--------------------------

1. Uninstall the app (clears old intent handlers).

2. In Azure Portal, verify only **one** mobile redirect is **checked**: `com.mybartenderai.app://oauth/redirect`.

3. Reinstall your `FINAL-FIX.apk`.

4. Start sign‑in. After consent, the browser’s **last URL** should be:  
   `com.mybartenderai.app://oauth/redirect?code=...&state=...`  
   (No `/oauth2/nativeclient` hop should appear.)

5. AppAuth should immediately POST the code to the token endpoint and complete.

* * *

### When to _not_ use this configuration

If you ever switch to **MSAL** libraries, then you would revert to `msal{clientId}://auth` **and** add the **CIAM** `…/oauth2/nativeclient` redirect, with `response_mode=form_post`. Don’t mix MSAL pieces with AppAuth.

* * *

**Bottom line:** your checklist is the right correction. Apply the Azure changes, install the new APK, and the sign‑in flow should complete without the AADSTS900561 error. If anything still misbehaves, share the **exact last URL** you see in the browser and the **redirect intent filter** block you shipped—I’ll zero in on the remaining mismatch.
