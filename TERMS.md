# Terms of Use — Mira

**Effective date:** 3 May 2026
**Last updated:** 3 May 2026
**Application:** Mira — Offline AI Journal (iOS)
**Application identifier:** `com.veilbytesoft.Mira`
**Provider (the "Developer", "we", "us"):** Ivan Rovkov, individual developer (natural person)
**Contact:** arbuzikmr@gmail.com

---

## 1. Acceptance of these Terms

By installing or using Mira (the "App") you agree to be legally bound by these Terms of Use ("Terms"). If you do not agree, do not install the App or, if it is already installed, uninstall it.

These Terms form a contract between you ("you", "User") and the Developer. The contract is concluded electronically when you accept these Terms by tapping "Continue" in the onboarding flow or by using the App after an update.

---

## 2. Eligibility

You must be at least **16 years old** to use Mira. If you are between 16 and 18 (or under the age of majority in your jurisdiction), you confirm that your parent or legal guardian has reviewed and consented to these Terms on your behalf.

Mira is **not** intended for children under 13. We comply with the U.S. Children's Online Privacy Protection Act (COPPA) and do not knowingly collect personal information from children under 13. If we discover that a child under 13 has used the App, we will delete their data and terminate the account.

---

## 3. Licence

Subject to your continued compliance with these Terms, the Developer grants you a personal, non-transferable, non-exclusive, revocable licence to install and use one copy of the App on Apple-branded devices that you own or control, in accordance with Apple's [Licensed Application End User Licence Agreement](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) ("Apple Standard EULA"), which is incorporated by reference into these Terms.

Apple is a third-party beneficiary of these Terms and may enforce them against you in respect of the use of the App. In the event of conflict between these Terms and the Apple Standard EULA, the more protective provision in favour of the User prevails.

You may **not**:

- copy, modify, distribute, sell, lease, sublicense, or commercially exploit the App;
- reverse engineer, decompile, or disassemble the App except where this is permitted by mandatory law;
- remove or alter the Developer's copyright notices.

The App is licensed, not sold. All rights not expressly granted to you are reserved by the Developer.

---

## 4. Subscription Terms — Mira Pro

### 4.1. Plans

Mira offers an auto-renewable subscription ("Mira Pro") in two billing cadences:

- **Monthly** — $5.99 USD or local equivalent / month.
- **Yearly** — $49.99 USD or local equivalent / year (~30% off vs monthly).

Both plans include a **7-day free trial** for new subscribers. Pricing in your region is determined by Apple at purchase time and shown on the in-app paywall.

### 4.2. Billing and auto-renewal

- Payment is charged to your Apple ID at confirmation of purchase.
- The subscription **renews automatically** at the end of each billing period at the then-current price unless you cancel at least **24 hours before** the end of the current period.
- The renewal charge is billed within 24 hours of the end of the current period.
- You can manage and cancel your subscription at any time at **iOS Settings → [your name] → Subscriptions** or in **App Store → Account → Subscriptions**.
- Cancellation takes effect at the end of the current billing period; you keep Pro access until then.
- Free trials convert to paid unless cancelled before the trial ends.

### 4.3. Refunds

Refunds are issued by Apple, not by the Developer. Request a refund through Apple at <https://reportaproblem.apple.com>. Refunds are at Apple's discretion in accordance with App Store policy. Local consumer protection law (e.g., the EU 14-day right of withdrawal) applies where mandatory.

### 4.4. Pro features

A current list of features unlocked by Mira Pro is shown on the in-app paywall. As of the effective date these include: hosted AI (Ask Mira and weekly reflections via Anthropic Claude proxied through our infrastructure), advanced statistics, custom themes and app icons, PDF export templates, custom mood scales, additional Lock Screen / Home Screen widgets, custom AI personas, smart filters and collections, goal and habit tracking, and importers from Day One / Apple Notes / Markdown. We may add or modify Pro features without notice; we will not remove a feature you previously paid for in the same billing period without offering a refund.

### 4.5. Usage limits

To prevent abuse and manage infrastructure costs we apply per-user monthly limits to certain Pro AI features:

- **Ask Mira** — 100 messages per calendar month using our default Claude model. Once the limit is reached the feature pauses until the next month.
- **Manual weekly reflection** — 2 invocations per calendar month.
- **Auto-fired weekly reflection** — unlimited (technically capped by frequency: 1× / week).

Limits may be adjusted in future versions; we will document changes here.

### 4.6. Family Sharing

Mira Pro is **not** Family Sharing-enabled. The subscription is personal to the Apple ID that purchased it.

### 4.7. Restore Purchases

If you reinstall the App or use it on another device signed in to the same Apple ID, tap **Settings → Mira Pro → Restore Purchases** to recover your subscription. We do not separately store your subscription on a different account.

### 4.8. Redeem codes

We may issue complimentary or beta-access redeem codes. Redeeming a code is single-use and personal; codes may not be sold, transferred, or shared. We may revoke a code at any time for fraud or abuse.

---

## 5. Pro AI Service — Hosted Claude

When you use a Pro AI feature, your message text and a small RAG-selected slice of your journal are transmitted from your device, through Mira's Cloudflare Worker (`mira-backend.miradiary.workers.dev`), to **Anthropic, PBC**'s Claude API. The response streams back to your device.

**Important facts:**

- We do **not** store the message body or the response body on the worker or in any database.
- Anthropic processes your request under their commercial API terms. Per those terms, **Anthropic does not use API inputs or outputs to train its models**.
- AI output is generated by a third-party probabilistic model. It may be inaccurate, biased, outdated, or otherwise unsuitable. Use AI output at your own discretion.
- Mira is **not** a medical, psychological, legal, or financial service. Do **not** rely on the App for advice in those areas. If you are in distress, please contact a qualified professional or your local emergency services.

For full data-flow detail see our [Privacy Policy](./PRIVACY.md), Sections 5.7, 5.11, 5.12, 8.3, and 8.4.

---

## 6. User Content and Ownership

### 6.1. Your content stays yours

Any content you create with Mira — journal entries, photos, mood ratings, tags, AI conversation history — is **your content**. We claim no ownership of it. We do not run a service that hosts your content for redistribution; storage is on your device, optionally in your personal iCloud, never on our servers (with the limited exception in Section 5).

### 6.2. AI-generated content

Outputs produced by the AI are **also your content** to the maximum extent permitted by the underlying model provider's terms. Anthropic's API terms grant you the rights to outputs you generate. You are responsible for how you use AI outputs (Section 7).

### 6.3. Backup

You alone are responsible for backing up your journal. The Developer is not liable for data loss caused by device failure, iCloud disruption, software bugs, or your own deletions. The export feature (Markdown / PDF) and iCloud sync are provided to help you maintain your own backups.

---

## 7. Acceptable Use

You agree not to use the App, including its AI features, to:

- generate, process, or store unlawful content (child sexual abuse material, content inciting violence or terrorism, content that violates applicable export-control or sanctions law);
- harass, defame, threaten, or invade the privacy of any person;
- generate content intended to deceive, defraud, or impersonate another person without consent;
- attempt to defeat usage limits, scrape the worker, or otherwise abuse our infrastructure;
- reverse engineer the App or our backend, except as expressly permitted by mandatory law;
- redeem codes or transactions through fraudulent means.

We may suspend or terminate your access for serious or repeated violations. Where we host data on your behalf (subscription state, usage counters), we may delete it.

---

## 8. Third-Party Services

Mira interoperates with several third-party services. Your use of those services is subject to their own terms:

- **Apple Inc.** — App Store, StoreKit, iCloud / CloudKit, APNs. <https://www.apple.com/legal/>.
- **Anthropic, PBC** — Claude API for Pro AI. <https://www.anthropic.com/legal/commercial-terms>.
- **Cloudflare, Inc.** — Workers + KV hosting our backend. <https://www.cloudflare.com/terms/>.
- **Google LLC / Google Ireland Ltd.** — Firebase Analytics, Crashlytics, Cloud Messaging, Remote Config (subject to your in-app consent). <https://firebase.google.com/terms>.
- **Hugging Face, Inc.** — model file downloads for on-device AI (no journal content is sent). <https://huggingface.co/terms-of-service>.

---

## 9. Disclaimers and Limitation of Liability

### 9.1. As-is provision

The App is provided **"as is" and "as available"**, without warranty of any kind, whether express, implied, statutory, or otherwise. To the maximum extent permitted by applicable law the Developer disclaims all implied warranties, including merchantability, fitness for a particular purpose, accuracy, and non-infringement.

### 9.2. AI output disclaimer

AI-generated content can be wrong, misleading, or harmful. The Developer is not responsible for actions you take based on AI output. The App is **not** a medical device or a substitute for professional advice.

### 9.3. Limitation of liability

To the maximum extent permitted by applicable law, the Developer's total cumulative liability arising out of or relating to these Terms or your use of the App shall not exceed the **greater of** (a) the amount you paid for the subscription in the 12 months preceding the claim, or (b) USD 50.

The Developer is **not** liable for indirect, incidental, special, consequential, or punitive damages, including lost profits, lost data, or business interruption, even if advised of the possibility of such damages.

### 9.4. Mandatory consumer rights

Nothing in these Terms excludes or limits liability that cannot lawfully be excluded or limited under applicable consumer protection law. Where the law of your country grants you stronger rights, those rights apply.

### 9.5. Apple's role

Apple is **not** a party to these Terms and is **not** responsible for the App or any claims relating to it. To the extent allowed by applicable law, Apple has no warranty obligation whatsoever with respect to the App. Any claims relating to the App's content, performance, or non-conformity should be addressed to the Developer in accordance with these Terms.

---

## 10. Termination

You may stop using the App and delete it at any time. To stop a subscription, cancel through the App Store (Section 4.2).

The Developer may suspend or terminate your access to the App or to specific features (including Pro features) for material breach of these Terms, suspected fraud, abuse of our infrastructure, or as required by law. Where reasonable we will give you notice and a chance to cure.

Upon termination of access to Pro features for material breach, no refunds are due unless required by mandatory law.

---

## 11. Changes to these Terms

We may update these Terms from time to time. Material changes will be communicated via the App or this document, and the "Last updated" date at the top will be revised. Continuing to use the App after the changes take effect constitutes your acceptance. If you do not accept the changes, your remedy is to stop using the App and to cancel any active subscription.

For substantive changes affecting active subscribers (e.g., a price increase), Apple's normal notification rules apply.

---

## 12. Governing Law and Jurisdiction

These Terms are governed by the laws of the **Russian Federation**, without regard to its conflict-of-laws provisions, **except** that:

- Mandatory consumer-protection rules of your country of residence continue to apply if they offer you stronger protection.
- The U.N. Convention on Contracts for the International Sale of Goods (CISG) does not apply.

Disputes that cannot be resolved informally will be submitted to the courts having jurisdiction over the Developer's place of residence in the Russian Federation, **without prejudice** to consumer rights to bring proceedings in their country of residence under applicable consumer-protection rules.

For App Store-related disputes Apple's [Media Services Terms](https://www.apple.com/legal/internet-services/itunes/) also apply.

---

## 13. Contact

Questions, complaints, or notices under these Terms:

> **Ivan Rovkov**, individual developer
> Email: **arbuzikmr@gmail.com**

We will respond within a reasonable time.

---

## 14. Miscellaneous

- **Entire agreement.** These Terms, together with the Privacy Policy and Apple's Standard EULA, are the entire agreement between you and the Developer concerning the App.
- **Severability.** If any provision of these Terms is held invalid or unenforceable, the remainder remains in effect.
- **No waiver.** Our failure to enforce any right or provision is not a waiver of that right or provision.
- **Assignment.** You may not assign these Terms. The Developer may assign them in connection with a merger, acquisition, or sale of substantially all assets.
- **Force majeure.** The Developer is not liable for any delay or failure caused by events beyond reasonable control (acts of God, war, infrastructure outage at Apple, Anthropic, or Cloudflare).
- **Headings.** Section headings are for convenience only and do not affect interpretation.
