# iOS App Setup Instructions

## Overview
This guide walks you through creating the Kitchen Assistant iOS app in Xcode.

## Prerequisites
- Mac with macOS 13.0 or later
- Xcode 14.0 or later
- Apple Developer account (for device testing)
- iPad running iOS 16.0 or later

## Step 1: Create New Xcode Project

1. Open Xcode
2. Select **File > New > Project**
3. Choose **iOS** tab
4. Select **App** template
5. Click **Next**

## Step 2: Configure Project Settings

Enter the following details:

- **Product Name**: `KitchenAssistant`
- **Team**: Select your development team
- **Organization Identifier**: `com.yourcompany` (or your preference)
- **Bundle Identifier**: Will auto-generate as `com.yourcompany.KitchenAssistant`
- **Interface**: **SwiftUI**
- **Language**: **Swift**
- **Storage**: **None**
- **Hosting Graph**: Unchecked
- **Include Tests**: Optional (can check if you want)

Click **Next** and save the project in the `ios-app/` folder of this repository.

## Step 3: Set Deployment Target

1. Click on the project in the Navigator
2. Under **Targets**, select **KitchenAssistant**
3. Go to **General** tab
4. Set **Minimum Deployments** to **iOS 16.0**
5. Under **Supported Destinations**, ensure **iPad** is checked

## Step 4: Create Folder Structure

In the Project Navigator, create the following folder structure:

```
KitchenAssistant/
├── App/
│   ├── KitchenAssistantApp.swift (already exists, move here)
│   └── ContentView.swift (already exists, move here)
├── Models/
│   └── RecipeModel.swift
├── Managers/
│   ├── RecipeManager.swift
│   ├── VoiceManager.swift
│   └── QueryProcessor.swift
├── Views/
│   ├── HomeView.swift
│   ├── RecipeListView.swift
│   ├── RecipeDetailView.swift
│   └── SettingsView.swift
└── Resources/
    ├── Assets.xcassets (already exists, move here)
    └── recipes.json (copy from python-processor/output/)
```

To create folders in Xcode:
1. Right-click on **KitchenAssistant** group
2. Select **New Group**
3. Name the group (e.g., "Models")
4. Repeat for each folder

## Step 5: Add recipes.json as Bundle Resource

1. First, generate the recipes.json file:
   ```bash
   cd ../python-processor
   python3 process_recipes.py
   ```

2. In Xcode, right-click on the **Resources** group
3. Select **Add Files to "KitchenAssistant"...**
4. Navigate to `python-processor/output/recipes.json`
5. Make sure **Copy items if needed** is checked
6. Make sure **Add to targets: KitchenAssistant** is checked
7. Click **Add**

## Step 6: Configure Capabilities and Permissions

### Speech Recognition Permission

1. Click on the project in Navigator
2. Select the **KitchenAssistant** target
3. Go to **Info** tab
4. Add these privacy keys (click **+** button):

| Key | Value |
|-----|-------|
| Privacy - Speech Recognition Usage Description | "Kitchen Assistant needs speech recognition to understand your recipe questions." |
| Privacy - Microphone Usage Description | "Kitchen Assistant needs microphone access to hear your questions." |

### Background Modes (Optional, for continued speech)

1. Go to **Signing & Capabilities** tab
2. Click **+ Capability**
3. Add **Background Modes**
4. Check **Audio, AirPlay, and Picture in Picture**

## Step 7: Create Swift Files

Now create the Swift files as described in `CODE_STRUCTURE.md`. You can either:

**Option A: Create files manually in Xcode**
1. Right-click on the appropriate group (Models, Managers, or Views)
2. Select **New File...**
3. Choose **Swift File**
4. Name it appropriately
5. Copy code from the structure guide

**Option B: Use provided Swift code templates**
- See `CODE_STRUCTURE.md` for detailed implementation of each file

## Step 8: Build and Run

1. Select an iPad simulator or connected iPad device
2. Click the **Play** button or press **⌘R**
3. Grant microphone and speech recognition permissions when prompted
4. Test voice queries like:
   - "How many slices of bacon go in McAlister's Club?"
   - "What do I need to make the club sandwich?"

## Step 9: Testing on Physical iPad

### For Development Testing:
1. Connect iPad via USB
2. Select it as the run destination
3. If not registered, Xcode will guide you through device registration
4. Build and run

### For Distribution (Optional):
1. Archive the app: **Product > Archive**
2. Use **Distribute App** to create an IPA
3. Install via TestFlight or Ad Hoc distribution

## Troubleshooting

### "recipes.json not found"
- Ensure the file is in the bundle: Click on recipes.json in Navigator, check **Target Membership** on right panel includes KitchenAssistant

### Speech recognition not working
- Check Info.plist has the required privacy keys
- Ensure you granted permissions in Settings > Privacy & Security > Speech Recognition
- Test on a physical device (simulator has limitations)

### Build errors
- Clean build folder: **Product > Clean Build Folder** (⇧⌘K)
- Restart Xcode
- Check Swift version compatibility

## Updating Recipes

When you add new recipe PDFs:

1. Run the Python processor:
   ```bash
   cd python-processor
   python3 process_recipes.py
   ```

2. Copy new recipes.json to the app:
   ```bash
   cp output/recipes.json ../ios-app/KitchenAssistant/Resources/recipes.json
   ```

3. Rebuild the app in Xcode (⌘B)

Or use the automation script:
```bash
cd ..
./update_recipes.sh
```

## Next Steps

1. Implement the Swift files following `CODE_STRUCTURE.md`
2. Customize the UI for your restaurant's branding
3. Add more query patterns in QueryProcessor
4. Test thoroughly with real recipe questions
5. Deploy to restaurant iPads

## Additional Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Speech Framework](https://developer.apple.com/documentation/speech)
- [AVFoundation for TTS](https://developer.apple.com/documentation/avfoundation/speech_synthesis)
