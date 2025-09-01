
# PaycheckPlanner (XcodeGen)

This folder contains source files + an **XcodeGen** config to generate a clean `.xcodeproj` without parse errors.

## Quick start

```bash
brew install xcodegen     # if you don't have it
cd PaycheckPlanner_SourcesOnly_XcodeGen
xcodegen                  # generates PaycheckPlanner.xcodeproj
open PaycheckPlanner.xcodeproj
```

### After opening
1. Set Signing for each target (App, Widget, Watch App, Watch Extension).
2. Add **App Groups** capability to App, Widget, and Watch Extension (same group across all targets).
3. In `PaycheckPlanner/SharedAppGroup.swift`, set:
   ```swift
   static let suite = "group.yourteam.PaycheckPlanner"
   ```
4. Build & run the **iOS app** once, then add the widget from your Home/Lock screen.
5. Optional: add your App Icon to `PaycheckPlanner/Assets.xcassets`.

If you change the bundle IDs or App Group, update `project.yml` accordingly:
- `targets.PaycheckPlanner.bundleId`
- `entitlements` groups
- widget & watch target `PRODUCT_BUNDLE_IDENTIFIER` entries
