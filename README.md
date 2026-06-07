# Swipey

Swipey is an iOS photo-cleanup app that helps users review their photo library with a swipe-based interface. The current implementation uses SwiftUI, PhotoKit, an observable view model, and a basic paywall screen. The next major direction is to migrate the app to The Composable Architecture (TCA) and grow it into a subscription-based cleanup product.

## Current State

- Loads photo assets from the user's photo library with PhotoKit.
- Shows one photo at a time in a swipe card interface.
- Swiping right keeps an item.
- Swiping left queues an item for deletion.
- Users can confirm deletion of queued photos.
- Users can undo the latest swipe with a button.
- A swipe limiter and paywall entry point already exist, but the current limit is not aligned with the planned free tier.

## Product Goals

- Make photo cleanup fast, predictable, and reversible.
- Give free users a useful daily cleanup flow without making the product feel broken.
- Move premium value into clear subscription features:
  - More than 20 photo swipes per day.
  - Video cleanup.
  - Deleted-item history.
  - Album-by-album cleanup.
- Use TCA so feature growth stays testable, modular, and easier to reason about.

## TCA Migration Plan

### 1. Add Core Architecture

- Add TCA as a project dependency.
- Introduce an `AppFeature` as the root reducer.
- Move app-level state into `AppFeature.State`.
- Route startup, permission checks, paywall presentation, and errors through TCA actions.
- Replace the root `@State` view model ownership with a TCA `Store`.

### 2. Extract Photo Library Domain

- Create a `PhotoLibraryClient` dependency for PhotoKit operations.
- Move authorization, asset fetching, thumbnail loading, preheating, and deletion behind dependency APIs.
- Keep PhotoKit types out of feature state where possible.
- Add test clients for authorized, denied, empty-library, and deletion-failure scenarios.

### 3. Build Swipe Feature

- Create a `SwipeFeature` reducer for the main card flow.
- Model state for current asset, current index, queued deletions, swipe history, loading, and errors.
- Convert swipe gestures into actions such as `cardSwiped`, `undoTapped`, `deleteTapped`, and `deleteConfirmed`.
- Keep animation state in SwiftUI when it is purely visual.
- Add reducer tests for keep, delete, undo, limit reached, and deletion success/failure.

### 4. Add Entitlements And Limits

- Use RevenueCat as the subscription and entitlement source of truth.
- Create an `EntitlementsFeature` backed by a `RevenueCatClient` dependency.
- Model subscription state as free, subscribed, expired, or unknown.
- Change the free daily photo limit to 20 swipes.
- Reset free usage by calendar day.
- Gate premium-only flows from a single entitlement layer rather than scattering checks across views.

### 5. Add Paywall And Purchase Flow

- Replace the placeholder paywall action with RevenueCat offerings, purchases, restore purchases, and customer-info updates.
- Configure Apple subscriptions in App Store Connect, then map them to RevenueCat products, entitlements, and offerings.
- Show the paywall from gated actions:
  - Free user reaches 20 daily photo swipes.
  - Free user tries to swipe videos.
  - Free user opens deleted history.
  - Free user opens album cleanup.
- Add tests for offering loading errors, successful purchase, restore, and revoked entitlement.

## Feature Roadmap

### Undo Swipe

- Keep the existing undo button behavior.
- Add shake-to-undo using a UIKit motion bridge or a SwiftUI-compatible responder wrapper.
- Route shake events into the same TCA `undoTapped` action so button and shake behavior remain identical.
- Decide whether undo should return a consumed free swipe. Recommended: undo restores the swipe quota only if the undone swipe happened during the same daily quota session.

### Free Daily Limit

- Free users can swipe up to 20 photos per day.
- Subscribed users have unlimited photo swipes.
- The counter should show remaining free swipes clearly before the paywall appears.
- Persist usage locally first, then consider server-side enforcement only if abuse becomes a real issue.

### Video Cleanup

- Extend asset loading to support `PHAssetMediaType.video`.
- Add media-type filters: photos, videos, and all media.
- Gate video swiping behind subscription.
- Add video thumbnail and playback preview support before deletion.
- Ensure deletion copy clearly distinguishes photos and videos.

### Deleted Items History

- Track deleted asset metadata before deletion: local identifier, media type, creation date, thumbnail if available, deletion date, and source album if known.
- Show deleted history only to subscribed users.
- Treat this as an audit/history feature, not a full restore feature, because PhotoKit deletion cannot reliably restore original assets from the app.
- Add a retention policy so local metadata does not grow forever.

### Album Cleanup

- Fetch user albums and smart albums with PhotoKit.
- Add an album picker screen.
- Allow subscribed users to swipe within a selected album.
- Keep global cleanup as the default flow for free users.
- Track progress per album so users can continue where they left off.

## Suggested Module Structure

```text
Swipey/
  AppFeature/
  PhotoLibrary/
  SwipeFeature/
  PaywallFeature/
  Entitlements/
  DeletedHistoryFeature/
  AlbumsFeature/
  SharedModels/
```

## Milestones

### Milestone 1: TCA Foundation

- Add TCA dependency.
- Create `AppFeature`.
- Move startup, permissions, loading, paywall, and error presentation into TCA.
- Keep existing UI mostly unchanged.

### Milestone 2: Swipe Flow Migration

- Move swipe state and business rules into `SwipeFeature`.
- Add tests for current swipe behavior.
- Preserve existing photo-only cleanup behavior.
- Change the free limit from the current placeholder value to 20 per day.

### Milestone 3: Subscription Infrastructure

- Add RevenueCat SDK integration and entitlement state.
- Configure App Store Connect subscription products and RevenueCat offerings.
- Implement purchase and restore flows through RevenueCat.
- Gate unlimited swipes behind subscription.
- Add local StoreKit configuration for development.

### Milestone 4: Premium Media Features

- Add video asset support.
- Add album selection and album-scoped cleanup.
- Add deleted-item history.
- Gate all premium media features through the entitlement layer.

### Milestone 5: Polish And Release

- Improve paywall copy and premium feature messaging.
- Add analytics for permission conversion, swipe count, paywall opens, purchases, and deletion confirmation.
- Add accessibility labels and dynamic type checks.
- Add App Store screenshots, privacy copy, and subscription metadata.

## Testing Plan

- Unit-test reducers with TCA's test store.
- Test daily limit reset behavior with an injectable date dependency.
- Test PhotoKit flows with mocked `PhotoLibraryClient` responses.
- Test RevenueCat entitlement states with mocked customer info.
- Test App Store purchase flows with sandbox accounts and local StoreKit configuration where useful.
- Manually verify photo-library permissions, limited-library access, deletion confirmation, shake-to-undo, and paywall presentation on device.

## RevenueCat Notes

- RevenueCat can be used for this app's subscriptions, while Apple still processes App Store payments.
- The Apple Developer account region being Kazakhstan should not block RevenueCat by itself.
- App Store Connect still needs the Paid Apps Agreement, banking information, tax setup, and subscription products configured correctly.
- RevenueCat availability follows the in-app purchase availability of the underlying store, so final availability is controlled by Apple's App Store and App Store Connect configuration.
- Keep subscription business logic in TCA behind `RevenueCatClient` so RevenueCat can be mocked in tests.

## Open Decisions

- Whether undo should refund a free daily swipe.
- Whether deleted history stores thumbnails, metadata only, or both.
- Whether albums are subscription-only from the start or visible with a locked state for free users.
- Whether video cleanup should support playback before swiping or start with thumbnails only.
- Whether subscription enforcement remains local-only or later moves to a backend.
