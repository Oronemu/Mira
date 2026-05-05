# Privacy Policy — Mira

**Effective date:** 23 April 2026
**Last updated:** 3 May 2026
**Application:** Mira — Offline AI Journal (iOS)
**Application identifier:** `com.veilbytesoft.Mira`
**Developer (Data Controller):** Ivan Rovkov (individual developer, natural person)
**Contact:** arbuzikmr@gmail.com

---

## 1. Introduction

This Privacy Policy ("Policy") describes how Ivan Rovkov ("I", "me", "my", or the "Developer") processes personal data in connection with the **Mira** mobile application for iOS ("App", "Mira").

Mira is an offline-first AI journal. The App is designed so that the **content** of your journal — your entries, photos, mood ratings, tags, embeddings, and AI prompts — stays on your device by default. We do **not** operate a server that stores or processes your journal content. We cannot read your entries.

This Policy is provided in accordance with:

- Regulation (EU) 2016/679 ("**GDPR**");
- the UK Data Protection Act 2018 and UK GDPR;
- the California Consumer Privacy Act (Cal. Civ. Code § 1798.100 et seq., as amended by the CPRA) ("**CCPA/CPRA**");
- Federal Law No. 152-FZ of 27 July 2006 "On Personal Data" of the Russian Federation ("**152-FZ**");
- the U.S. Children's Online Privacy Protection Act ("**COPPA**");
- Apple Inc.'s App Store Review Guidelines and App Privacy Details requirements.

If you do not agree with this Policy, please do not install or use Mira.

---

## 2. Data Controller & Contact

The data controller responsible for personal data processed through Mira is:

> **Ivan Rovkov** (individual developer, natural person; sole developer of Mira)
> Email: **arbuzikmr@gmail.com**

For any privacy-related request, including exercising your rights under GDPR, CCPA, 152-FZ or any other applicable law, please contact me at the email address above. I will respond within the statutory deadlines (typically 30 days under GDPR, 45 days under CCPA).

As I am an individual developer working alone on this project, no separate Data Protection Officer is appointed; I personally act as the privacy contact.

*Note on the identifier `com.veilbytesoft.Mira`:* "veilbytesoft" is the technical namespace I reserved for this App in Apple's App Store Connect and iCloud infrastructure. It is a technical string, not a separate legal entity. The sole controller of your personal data is me, Ivan Rovkov, as a natural person.

---

## 3. Scope of this Policy

This Policy applies to:

- the Mira iOS application and all its extensions (Home Screen widgets, Lock Screen widgets, App Intents, background tasks);
- any diagnostic telemetry that Mira sends to third-party services (listed in **Section 8**);
- any optional remote AI features that the user explicitly enables.

This Policy does **not** apply to:

- third-party services accessed through Mira when you explicitly choose to use them (Anthropic, Apple iCloud/CloudKit, Google Firebase, Hugging Face). Those services process data according to their own privacy policies, to which we link in **Section 8**;
- data you voluntarily export and share with other apps or persons via the iOS share sheet.

---

## 4. Key Privacy Principles of Mira

Before listing categories of data, we summarise our design principles so that this Policy is easier to interpret:

1. **Content stays on-device by default.** Journal text, photos, mood, tags, and embeddings are processed locally on your device. Free users receive AI features (Ask Mira, weekly reflections) through an on-device language model running entirely on your iPhone — your text never leaves the device.
2. **Pro AI is proxied, never stored.** When you subscribe to Mira Pro and use a Pro AI feature, the question text and a small RAG-selected slice of your journal are sent through Mira's own Cloudflare Worker to Anthropic's Claude API. **We do not store this content** on the worker; Anthropic processes it under their commercial API terms and does not train on it. See Section 5.11 and Section 8.
3. **Any outbound transfer is opt-in and transparent.** iCloud sync, Pro AI, analytics, and crash reporting are either disabled by default or require explicit user action (subscription, settings toggle, consent prompt).
4. **Minimisation.** We process only what is strictly necessary for the feature you enabled.
5. **Encryption of synced content.** When iCloud sync is enabled, entries are encrypted on-device with a symmetric key (ChaChaPoly-256) before leaving the device. Apple's CloudKit stores only the ciphertext.
6. **User control.** You can disable telemetry, disable sync, cancel your subscription, and delete entries at any time within Settings or the iOS App Store.

---

## 5. Categories of Personal Data We Process

This section enumerates **every category** of personal data the App currently processes or, pursuant to publicly documented roadmap items, may process in future versions. Where a category is not yet implemented in the released App, it is marked *(planned)*.

### 5.1. Journal Content (processed on-device only; not transmitted to us)

- Free-form text of journal entries.
- Titles / first line of entries (where applicable).
- Mood rating (integer scale 1–5).
- User-defined tags (lowercase strings).
- Timestamps (`createdAt`, `updatedAt`).
- Photographs attached to entries (up to 3 per entry, stored in the app's Documents container).
- *(planned)* Voice recordings and their transcripts if the future voice-entry feature is released.
- AI-generated insights, weekly reflections, and "Ask Mira" conversation history produced from your entries.
- Vector embeddings of your entries (512-dimensional floating-point vectors generated on-device) used for semantic search.

**Storage locations:** local SwiftData database on the device; optionally, **encrypted** copies in your personal iCloud (see 5.6).

**Legal basis (GDPR):** Art. 6(1)(b) — performance of the contract to provide the journaling service you requested. For mood data (which may constitute "data concerning health" under Art. 9), processing is carried out solely on your device and is based on Art. 9(2)(a) — your explicit consent given by using the feature, or Art. 9(2)(h) is not relied on as this is not a medical service.

### 5.2. Authentication and Device Security Data

- Biometric lock setting (on/off, soft/always). We do **not** access or store the biometric templates themselves; Face ID / Touch ID verification is performed locally by iOS through the `LocalAuthentication` framework, which returns only a boolean result.
- Device passcode fallback state (managed by iOS).

**Legal basis (GDPR):** Art. 6(1)(b) and Art. 6(1)(f) — our legitimate interest in protecting user data with a standard security mechanism.

### 5.4. Application Preferences

Stored locally in `UserDefaults`:

- AI-provider selection (off / on-device / remote).
- Reflection cadence (weekly / biweekly / off).
- Biometric mode.
- Theme and interface language.
- iCloud sync toggle state.
- Diagnostics & Analytics toggle state.
- Onboarding completion flag.

**Legal basis (GDPR):** Art. 6(1)(b).

### 5.5. Technical Identifiers and Device Data (collected by third-party SDKs — see Section 8)

Only if you have enabled "Diagnostics & Analytics" or you receive push notifications:

- Firebase Installation ID (a pseudo-random identifier scoped to this App; **not** the IDFA, **not** Google Advertising ID, and **not** used for cross-app tracking).
- APNs device token and Firebase Cloud Messaging (FCM) registration token (used solely to deliver push notifications).
- Device model, iOS version, locale, time zone, app version, build number, free memory at launch (collected automatically by Firebase SDKs).
- System boot time, disk space, file timestamps, and UserDefaults access (disclosed in our Privacy Manifest, `PrivacyInfo.xcprivacy`, as APIs required by the system's standard functionality).

**Legal basis (GDPR):**
- for crash diagnostics — Art. 6(1)(f) legitimate interest in ensuring the App remains stable and is properly consented to per Section 6.1;
- for usage analytics — Art. 6(1)(a) consent, obtained through the in-app "Diagnostics & Analytics" toggle;
- for push tokens — Art. 6(1)(b) performance of the service.

### 5.6. iCloud Sync Data (optional, opt-in)

If you enable "iCloud Sync" in Settings, the App uploads, to your **personal** iCloud account (not to us), encrypted copies of the data categories in Section 5.1 (excluding photo binaries in the current version).

- Each record is sealed on-device using ChaChaPoly-256 AEAD encryption before upload.
- The encryption key is stored in **your** iCloud Keychain (`kSecAttrSynchronizable`), which Apple transmits and stores under its own end-to-end encryption. The Developer has no access to this key.
- Apple's CloudKit server sees only: record ID, update timestamp, record kind, schema version, and ciphertext size.
- Deletions are propagated through encrypted tombstone records.

**Legal basis (GDPR):** Art. 6(1)(a) consent (you actively enable the toggle). The data controller of your iCloud account is Apple Inc.; refer to Apple's Privacy Policy (<https://www.apple.com/legal/privacy/>).

### 5.7. Hosted AI Proxy Data *(Mira Pro subscribers only)*

When you have an active Mira Pro subscription **and** use a Pro AI feature ("Ask Mira" chat, manually-triggered reflection, or the auto-fired weekly reflection on the hosted provider), the following data is transmitted:

- The App sends, over TLS, to Mira's own server (`mira-backend.miradiary.workers.dev`, a Cloudflare Worker operated by the Developer):
  - system instructions;
  - your current question or generation request;
  - a RAG-selected subset of your entry text, mood, and tags relevant to the request;
  - the StoreKit JWS for your active subscription (used solely for entitlement verification — see 5.11).
- The Mira worker verifies the subscription, applies a per-user monthly usage cap, and **proxies** the request body to **Anthropic, PBC** (Claude API).
- Anthropic returns the AI response as a streaming SSE; the worker passes it back to your device byte-for-byte.

**The worker does not log, store, or persist the request body or the response body**, on the worker itself or in any KV namespace. Only metadata (timestamps, status codes, monthly counters keyed on `originalTransactionId`) is retained for limit enforcement and operational diagnostics.

**Anthropic** is the AI processor. Per Anthropic's commercial API terms, your inputs and outputs are not used to train Anthropic's models. See Section 8.3.

**Legal basis (GDPR):** Art. 6(1)(b) — performance of the Mira Pro subscription contract you entered into. Mood data within the proxy payload is processed under Art. 9(2)(a) — your explicit consent given by enabling the Pro AI feature.

### 5.8. Export Files

When you use the "Export" feature, the App writes Markdown or PDF files into the iOS temporary directory and presents them through the system share sheet. The destination (mail, Files, Notes, another app) is chosen by you. The Developer does not receive export files.

### 5.9. Widget Data

Home Screen and Lock Screen widgets read data from an App Group container shared with the main app (current streak, latest entry preview). No outbound network requests are made from widgets.

### 5.11. Subscription & Transaction Data *(Mira Pro subscribers only)*

When you purchase Mira Pro through the iOS App Store, the following data flows from Apple to Mira's Cloudflare Worker so we can grant Pro access:

- `originalTransactionId` — Apple's stable identifier for your subscription (does **not** identify you personally; specific to Mira on this Apple ID).
- `transactionId` — per-transaction identifier for renewals and refunds.
- `productId` — which Mira Pro subscription plan you bought.
- `purchaseDate`, `expiresDate`, `revocationDate` — subscription lifecycle timestamps.
- `bundleId` — confirms the transaction is for our app.
- `environment` — `Production` or `Sandbox`.
- `appAccountToken` (optional UUID) — set to a random per-install identifier; lets us correlate a device to a transaction without learning your Apple ID.
- App Store Server Notifications V2 payloads — Apple posts subscription lifecycle events (renewals, refunds, expirations, revocations) to our worker; the JWS-signed payloads are verified, stored as the latest entitlement snapshot, and otherwise dropped.

**Storage:** Cloudflare Workers KV (encrypted at rest by Cloudflare; us-multi-region with EU options). The latest entitlement snapshot per `originalTransactionId` is retained up to 365 days so that we can answer "is this user Pro?" between app launches without re-running the full StoreKit verification each time.

**Apple does not send us your name, email, Apple ID, or payment instrument.** Only the technical fields above.

**Legal basis (GDPR):** Art. 6(1)(b) — performance of the Mira Pro subscription contract.

### 5.12. Hosted AI Usage Counters *(Mira Pro subscribers only)*

To enforce per-user monthly caps on the heaviest AI features (Ask Mira: 100 / month; manual weekly reflection: 2 / month) the Cloudflare Worker stores integer counters keyed on `originalTransactionId` plus the current `YYYY-MM` period. Counters reset monthly. They contain no message content and no personal identifiers beyond the StoreKit transaction id.

**Storage:** Cloudflare Workers KV. Stale counters auto-expire after 90 days.

**Legal basis (GDPR):** Art. 6(1)(f) — legitimate interest in preventing service abuse and managing infrastructure costs.

### 5.13. Redeem Codes *(complimentary access)*

If a developer-issued code (e.g. from beta-testing programs or gifts) is entered in **Settings → Mira Pro → Redeem code**, Mira's worker stores `{ code, redemption timestamp, device-bound identifier }` so each code is single-use. The code itself is not personal data; the identifier is the iOS `identifierForVendor` UUID, which is local to your device + this app and resets on uninstall.

### 5.10. Data We Do **Not** Collect

For the avoidance of doubt, the App does **not** collect or request:

- your name, email address, phone number, or postal address;
- your precise or approximate geolocation;
- your contacts, calendars, or reminders;
- health data from Apple HealthKit;
- the iOS advertising identifier (IDFA);
- financial or payment information beyond the StoreKit transaction identifiers needed to verify your subscription (Section 5.11). All payments are handled by Apple — we never see your card number, billing address, or Apple ID password;
- biometric templates;
- data from other apps;
- any cross-app or cross-site tracking identifiers.

---

## 6. Purposes of Processing

We process the data listed above for the following purposes only:

| # | Purpose | Categories used (cross-ref) | Legal basis (GDPR) |
|---|---|---|---|
| 6.1 | Providing the core journaling service (create, read, update, delete entries; render UI) | 5.1, 5.4, 5.9 | Art. 6(1)(b) |
| 6.2 | On-device AI features (embedding, semantic search, reflections, Ask Mira) running locally on your device | 5.1 | Art. 6(1)(b); Art. 9(2)(a) for mood |
| 6.3 | Protecting the App with biometric lock | 5.2 | Art. 6(1)(f) |
| 6.4 | Optional encrypted iCloud sync between your own devices | 5.6 | Art. 6(1)(a) |
| 6.5 | Hosted Pro AI (Ask Mira, weekly reflections via Anthropic Claude through Mira's proxy) for active subscribers | 5.7, 5.11, 5.12 | Art. 6(1)(b); Art. 9(2)(a) for mood |
| 6.5a | Verifying Mira Pro entitlement, enforcing monthly usage caps | 5.11, 5.12 | Art. 6(1)(b), Art. 6(1)(f) |
| 6.5b | Granting complimentary Pro access through redeem codes | 5.13 | Art. 6(1)(b) |
| 6.6 | Diagnosing crashes and improving app stability | 5.5 (crash data) | Art. 6(1)(f), subject to opt-out |
| 6.7 | Measuring aggregate feature usage to improve the product | 5.5 (analytics) | Art. 6(1)(a), explicit toggle |
| 6.8 | Delivering push notifications you have allowed (e.g., "your weekly reflection is ready") | 5.5 (tokens) | Art. 6(1)(b) |
| 6.9 | Fetching remote configuration flags (feature toggles) | minimal device metadata only | Art. 6(1)(f) |

We do **not** use your personal data for:

- targeted advertising;
- profiling with legal or similarly significant effects;
- automated individual decision-making within the meaning of GDPR Art. 22;
- selling or sharing with data brokers;
- training or fine-tuning the Developer's machine-learning models (there are none).

---

## 7. Automated Processing and AI

Mira uses automated processing in the following ways:

- **On-device embedding generation** to enable semantic search. No legal or similarly significant effect is produced.
- **On-device generative AI** to produce reflections and answer your questions. Output is displayed only to you.
- **Remote generative AI (optional)** to produce higher-quality reflections. Output is displayed only to you.

These features are **decision-support** tools. Mira does not make legal or similarly significant decisions about you. Mira is **not a medical device**, does not provide medical, psychological, or therapeutic advice, and is not intended to diagnose, treat, prevent, or cure any disease or mental-health condition. In cases of distress, please consult a qualified professional.

You may disable AI features at any time in **Settings → Intelligence**.

---

## 8. Third-Party Services ("Recipients")

The following third parties may receive data when the corresponding feature is active. Each acts as an independent data controller or processor according to its own terms. Mira embeds their SDKs or communicates with their HTTP endpoints.

### 8.1. Apple Inc.

- **iCloud / CloudKit** (optional, only if iCloud Sync is enabled): stores encrypted journal records in your personal iCloud container.
- **APNs** (Apple Push Notification service): delivers push notifications.
- **On-device system frameworks** (e.g., for natural-language processing and embeddings): run on your device; no data leaves the device for these.

Privacy policy: <https://www.apple.com/legal/privacy/>.

### 8.2. Google LLC / Google Ireland Ltd. — Firebase

Firebase is a Google product. The following Firebase SDKs are integrated:

- **Firebase Analytics** — aggregate usage events, Installation ID, device/OS metadata. Disabled by default and subject to the in-app Diagnostics & Analytics toggle.
- **Firebase Crashlytics** — crash stack traces and non-fatal error reports. Subject to the same toggle.
- **Firebase Cloud Messaging (FCM)** — routing of push notifications; stores the FCM token.
- **Firebase Remote Config** — downloads feature flags from Google; no journal content is uploaded.

The App is configured with `FIREBASE_ANALYTICS_COLLECTION_ENABLED=false` and `FirebaseAppDelegateProxyEnabled=NO` in its `Info.plist`. Collection is activated only after you grant consent.

Google's privacy policy: <https://policies.google.com/privacy>.
Firebase data disclosures: <https://firebase.google.com/support/privacy>.

### 8.3. Anthropic PBC (Claude) — *Mira Pro AI processor*

When you have an active Mira Pro subscription and use a Pro AI feature, the Mira Cloudflare Worker proxies your prompt and journal context to Anthropic's `api.anthropic.com`. Anthropic acts as a **processor** for the Developer under their Commercial Terms of Service. Per Anthropic's terms, **API inputs and outputs are not used to train Anthropic's models**. Anthropic's [Data Processing Addendum](https://www.anthropic.com/legal/data-processing-addendum) — including Standard Contractual Clauses for EU/UK GDPR transfers — is automatically incorporated into the Commercial Terms of Service that the Developer accepted when activating the Anthropic API account.

Privacy policy: <https://www.anthropic.com/legal/privacy>.
Trust center: <https://trust.anthropic.com/>.

### 8.4. Cloudflare, Inc. — *infrastructure*

Mira's hosted-AI proxy, App Store Server Notifications endpoint, redeem-code system, and per-user usage counters run on a Cloudflare Worker (`mira-backend.miradiary.workers.dev`) with three Cloudflare Workers KV namespaces. Cloudflare hosts our compute and storage; data is encrypted at rest and in transit. Cloudflare acts as a **processor** under their Customer Privacy Policy and standard DPA.

Privacy policy: <https://www.cloudflare.com/privacypolicy/>.
DPA / sub-processors: <https://www.cloudflare.com/cloudflare-customer-dpa/>.

### 8.5. Hugging Face, Inc. — *on-device model downloads*

The on-device language model that powers free AI features is delivered as a model file hosted on the Hugging Face Hub. The first time you enable on-device AI, the App contacts `huggingface.co` over HTTPS solely to download the model file. **No journal content is transmitted** — only the file-download requests themselves and standard HTTP metadata required to fetch a static asset. Once downloaded, the model lives on your device and runs without any network connection.

Privacy policy: <https://huggingface.co/privacy>.

### 8.6. No Other Recipients

We do **not** share personal data with advertising networks, data brokers, or any other third parties. We do **not** sell personal data in the sense of CCPA/CPRA § 1798.140(ad). We do **not** "share" personal data for cross-context behavioural advertising in the sense of CCPA/CPRA § 1798.140(ah).

---

## 9. International Data Transfers

Because Mira has no Developer-operated backend, most processing takes place on your device. When you use optional features, data may be transferred outside your country to the following recipients:

| Recipient | Typical location of servers | Transfer mechanism (GDPR) |
|---|---|---|
| Apple iCloud | United States; Apple's regional data centres | Apple's Standard Contractual Clauses (SCCs) / Apple's Data Processing Addendum |
| Google Firebase | United States; Google's regional data centres | SCCs; EU–US Data Privacy Framework (Google's self-certification) |
| Anthropic (Mira Pro AI proxy backend) | United States | SCCs pursuant to Anthropic's DPA |
| Cloudflare (worker hosting + KV) | United States; EU regions configurable | SCCs pursuant to Cloudflare's DPA |
| Hugging Face (on-device model downloads only) | United States / France | SCCs / EU-based for EU region |

For data subjects in the Russian Federation, we note that we **do not** maintain a Russian database of journal content because all content remains on the user's device or in the user's personal iCloud. The Developer does not act as a Russian database operator within the meaning of 152-FZ Art. 18(5), as no database of personal data of Russian citizens is created or stored by the Developer. If you are a Russian citizen and consider that this arrangement is nevertheless relevant to you, contact us via the email in Section 2.

---

## 10. Data Retention

| Data | Retention | How it is deleted |
|---|---|---|
| Journal entries, photos, mood, tags, insights, embeddings (local) | For as long as you keep them on the device | You delete them in-app; you uninstall the App |
| Journal entries in iCloud (encrypted) | For as long as iCloud Sync is enabled, up to Apple's iCloud retention rules | Disable iCloud Sync → encryption key is destroyed → ciphertext becomes permanently unreadable; delete the iCloud container via iOS Settings |
| Mira Pro entitlement snapshot in Cloudflare KV | Up to 365 days; refreshed on each App Store Server Notification | Cancel subscription → next renewal lapses → entry expires; or contact us to delete |
| Hosted AI usage counters in Cloudflare KV | Auto-expire 90 days after last write; reset monthly | — |
| Redeem code redemption record | Until manually purged from KV; counters tied to a single device-bound id | — |
| Firebase Installation ID, analytics events | Default Google retention of up to 14 months (configurable by the Developer) | Disable Diagnostics & Analytics; uninstall the App (regenerates Installation ID) |
| Crash reports | Default Crashlytics retention of up to 90 days | Disable Diagnostics & Analytics |
| Push tokens | Until you revoke notification permission or uninstall | iOS Settings → Notifications → Mira → Off |
| User preferences in UserDefaults | Until uninstall or reset | Uninstall the App or reset in-app settings |

Uninstalling the App removes all local data, including the local SwiftData database, Keychain items tagged for this App, and the App Group container. It does **not** remove data already synced to your personal iCloud; to remove that, use iOS Settings → Apple ID → iCloud → Manage Storage.

---

## 11. Security

We implement the following technical and organisational measures:

- **End-to-end encryption** of CloudKit records using ChaChaPoly-256 with keys stored in your own iCloud Keychain.
- **Keychain storage** of sensitive material (encryption keys) with device-only or synchronisable attributes as appropriate.
- **Biometric app lock** (Face ID / Touch ID) with passcode fallback.
- **TLS 1.2 or higher** for all outbound network connections (enforced by iOS App Transport Security).
- **Privacy manifests** (`PrivacyInfo.xcprivacy`) declaring all collected data categories and required-reason APIs.
- **Logging hygiene** via Apple's unified logging `os.Logger` with `privacy: .private` redaction by default for any value derived from journal content.
- **Strict type contracts** in the code preventing free-form strings from being passed to analytics/crash APIs, audited in `docs/PRIVACY_AUDIT.md`.
- **Swift 6 strict concurrency** enforced at compile time to reduce race conditions that could leak state across contexts.
- **Open source architecture documentation** allowing third-party verification.

No method of electronic transmission or storage is 100% secure. We cannot guarantee absolute security, but we strive to use industry-standard practices appropriate to a privacy-first consumer app.

---

## 12. Your Rights

### 12.1. Rights under the GDPR / UK GDPR

If you are in the European Economic Area, the United Kingdom or Switzerland, you have the following rights in respect of personal data we process:

- **Right of access** (Art. 15).
- **Right to rectification** (Art. 16). You can edit entries directly in the App.
- **Right to erasure / "right to be forgotten"** (Art. 17). You can delete entries directly in the App. For deletion of Firebase records tied to your Installation ID, contact us.
- **Right to restriction of processing** (Art. 18).
- **Right to data portability** (Art. 20). Use the in-app "Export" feature to export all entries as Markdown or PDF.
- **Right to object** (Art. 21).
- **Right to withdraw consent at any time** (Art. 7(3)). Toggle off Diagnostics & Analytics, iCloud Sync, and Remote AI at any time in Settings.
- **Right not to be subject to automated decision-making producing legal or similarly significant effects** (Art. 22). Not applicable — Mira does not take such decisions.
- **Right to lodge a complaint with a supervisory authority** (Art. 77), e.g., your local Data Protection Authority. A list is available at <https://edpb.europa.eu/about-edpb/about-edpb/members_en>.

To exercise any of these rights, email us at **arbuzikmr@gmail.com**. We will respond within one month (extendable by a further two months for complex requests, with notice).

### 12.2. Rights under the CCPA / CPRA (California residents)

Subject to the limits described in § 1798.145, California residents have the right to:

- **Know / access** the categories and specific pieces of personal information collected.
- **Delete** personal information we hold, subject to statutory exceptions.
- **Correct** inaccurate personal information.
- **Opt-out of sale or sharing.** We do not sell or share personal information. No opt-out link is required, but we still offer the global Diagnostics & Analytics toggle.
- **Limit use of sensitive personal information.** Sensitive categories (such as mood data) remain on your device.
- **Non-discrimination.**

To exercise these rights, email **arbuzikmr@gmail.com** with the subject "CCPA Request". We may need to verify your identity by matching your Firebase Installation ID or by asking you to confirm specific device/app metadata. Authorised agents are accepted with written permission.

### 12.3. Rights under 152-FZ (Russian Federation)

Subjects of personal data within the meaning of 152-FZ have the right to:

- request confirmation of processing and access to information about how their data is processed (Art. 14);
- request correction, blocking, or deletion of inaccurate or unlawfully processed data;
- withdraw consent at any time (Art. 9(2)) by disabling the relevant feature in the App and, if necessary, emailing us;
- appeal to Roskomnadzor or to a court.

Contact for these requests: **arbuzikmr@gmail.com**.

### 12.4. Rights under Other Jurisdictions

Residents of jurisdictions with analogous laws (e.g., Brazil's LGPD, Canada's PIPEDA, South Korea's PIPA, Australia's Privacy Act) may exercise the corresponding rights by emailing us.

---

## 13. Children's Privacy

Mira is **not directed to children under 13** (or, in the EU/UK, under 16 where applicable under GDPR Art. 8). The App does not knowingly collect personal information from such children. The age rating in the App Store reflects the suitability of journaling and reflective content for older minors with parental guidance.

If you are a parent or guardian and believe that a child has used Mira without your authorisation, please contact us at **arbuzikmr@gmail.com** and we will assist in deleting the local data from the device and advise on revoking any optional features.

---

## 14. Cookies and Similar Technologies

Mira does not use cookies, local storage beacons, pixel tags, or Web SDKs. It is a native iOS application and does not embed a web browser component that serves ads or trackers.

---

## 15. Do-Not-Track and Global Privacy Control

Because Mira does not engage in cross-context behavioural advertising and does not track users across apps or websites, we treat any Do-Not-Track or Global Privacy Control signal as already honoured by our default configuration.

Apple's App Tracking Transparency status is explicitly set to **not tracking** (`NSPrivacyTracking=false` in our Privacy Manifest).

---

## 16. Changes to this Policy

We may amend this Policy from time to time. The "Last updated" date at the top reflects the most recent change.

- **Material changes** (new categories of data, new recipients, new purposes) will be notified in-app at next launch and, where technically feasible, will require your renewed consent before the new processing begins.
- **Non-material changes** (clarifications, formatting, contact updates) take effect upon publication.

We will retain previous versions of this Policy in the App's GitHub repository (where available) so that you can compare them.

---

## 17. Contact

For any question, request, complaint, or exercise of rights under this Policy:

> **Ivan Rovkov** (individual developer)
> **arbuzikmr@gmail.com**

I aim to acknowledge privacy correspondence within 7 calendar days and to provide a substantive response within the statutory deadlines set by the applicable law.

---

## 18. Appendix — At-a-Glance Data Summary

For App Store compliance and reader convenience:

| Category | Collected? | Linked to identity? | Used for tracking? | Can be disabled? |
|---|---|---|---|---|
| Journal content | Only stored on device (and optionally in your iCloud, encrypted) | No | No | You can delete entries / uninstall |
| Contact info | No | — | — | — |
| Location | No | — | — | — |
| Sensitive info (biometric templates, precise health) | No | — | — | — |
| Contacts, photos library, calendars | Accessed only with your explicit permission when you choose to attach | No | No | iOS Settings |
| Product interaction (events) | Only if you enable Diagnostics & Analytics | No | No | Settings → Privacy |
| Crash data | Only if you enable Diagnostics & Analytics | No | No | Settings → Privacy |
| Performance data | Only if you enable Diagnostics & Analytics | No | No | Settings → Privacy |
| Other diagnostic data | Only if you enable Diagnostics & Analytics | No | No | Settings → Privacy |
| Device ID (Firebase Installation ID) | Collected by Firebase SDK | No | No | Uninstall / disable Firebase |
| Advertising ID (IDFA) | Not collected | — | — | — |
| Push token | Collected when notifications are allowed | No | No | iOS Settings → Notifications |

---

*End of Policy.*
