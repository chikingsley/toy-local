# RevenueCat launch checklist (TimberVox Mac App Store listing, TimberVox binary)

Mirrors the official checklist at https://www.revenuecat.com/docs/test-and-launch/launch-checklist, adapted to this project. Work top to bottom; check items as they are verified, not merely attempted.

CRITICAL PREREQUISITE from RevenueCat: the Test Store API key MUST be replaced with the real Apple platform API key (`appl_...`) before the app is submitted for review. Our Test Store key lives locally in `Config/RevenueCat.local.xcconfig` (gitignored) for SDK development only.

## Account and plan

- [x] RevenueCat account exists (Chi, 2026-07-05) with a Test Store API key generated.
- [ ] Understand plan limits: free until $2,500 monthly tracked revenue, then 1% of MTR; add a payment card to the RC account early so features are not interrupted at the threshold.

## Project and app setup

- [ ] Create the RevenueCat Project for TimberVox.
- [ ] Add the Apple App Store app to the project with bundle id `com.chiejimofor.timbervox`.
- [ ] Upload the In-App Purchase Key (.p8, Key ID, Issuer ID from App Store Connect → Users and Access → Integrations → In-App Purchase).
- [ ] Connect the App Store Connect API key (.p8, Key ID, Issuer ID from the App Store Connect API tab, App Manager role) so RC can sync products and metadata.
- [ ] Define the `pro` entitlement (the SAME entitlement id the worker reads for cloud gating).
- [ ] Create products in App Store Connect (pricing decision: Chi), attach them to the entitlement, and build the default Offering.
- [ ] Copy the production `appl_...` public API key into the MAS build configuration, replacing the Test Store key.

## User identity

- [ ] App User ID strategy verified: the app generates its ID once and stores it in the Keychain; the same ID is used for worker registration and RC purchases.
- [ ] Confirm purchasing test users appear in the RC customer view with that ID.
- [ ] Confirm no unexpected aliases accumulate on customer pages across reinstalls.

## Testing purchases

- [ ] Apple agreements signed: Paid Apps agreement, tax forms, banking details entered (App Store Connect → Agreements). Products cannot be tested without this.
- [ ] Test with the REAL Apple sandbox (sandbox Apple ID on this Mac), not only the Test Store.
- [ ] All products fetch correctly through the SDK (offerings load, prices display).
- [ ] A sandbox purchase unlocks the `pro` entitlement immediately and appears in RC transactions.
- [ ] Subscription stays active while valid and access revokes after sandbox expiration.
- [ ] Restore purchases works after delete + reinstall.

## Webhooks and integrations

- [ ] RC webhook pointed at the worker endpoint (with the authorization header secret), events verified end to end into D1.
- [ ] Webhook error monitoring checked in the RC dashboard after test purchases.

## Prepare release

- [ ] Test Store key replaced with the production `appl_` key in the shipped build (repeat of the critical prerequisite — verify in the built product, not the source).
- [ ] Auto-renewing subscription disclosure present in the App Store description (required when selling subscriptions).
- [ ] App Privacy disclosures completed in App Store Connect (see the App Store checklist).
- [ ] Release strategy: manual release selected; after "Cleared for Sale," wait up to ~24 hours for new products to propagate before announcing.
- [ ] Remember: in-app purchases only function in production AFTER the app itself is live; wait up to 24 hours post-launch before marketing pushes.
