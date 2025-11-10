# iOS Build Instructions for Port-A-Thoughty

This guide will help you build the Port-A-Thoughty app for iOS using Xcode.

## Prerequisites

1. **macOS** with Xcode installed (latest version recommended)
2. **Flutter SDK** installed and in your PATH
3. **CocoaPods** installed (`sudo gem install cocoapods`)
4. **Apple Developer Account** (for device deployment)

## Step 1: Install Flutter Dependencies

From the project root directory, run:

```bash
flutter pub get
```

This will download all the necessary Flutter packages defined in `pubspec.yaml`.

## Step 2: Install iOS Native Dependencies

Navigate to the iOS directory and install CocoaPods dependencies:

```bash
cd ios
pod install
```

This will:
- Generate the `Podfile.lock`
- Create the `Pods/` directory with all native iOS dependencies
- Update the workspace configuration

## Step 3: Open in Xcode

Open the workspace (NOT the project file):

```bash
open Runner.xcworkspace
```

**Important:** Always open `Runner.xcworkspace`, not `Runner.xcodeproj`, when working with CocoaPods.

## Step 4: Configure Signing & Capabilities

In Xcode:

1. Select the **Runner** project in the navigator
2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. Choose your **Team** from the dropdown
5. Xcode will automatically manage provisioning profiles

### Update Bundle Identifier (Optional)

The current bundle identifier is `com.example.portaThoughty`. For App Store distribution, you'll need to change this to your own identifier:

1. In **Signing & Capabilities**, update the **Bundle Identifier** to your own (e.g., `com.yourcompany.portathoughty`)
2. The identifier must be unique in the App Store

## Step 5: Select Build Device

In the Xcode toolbar:
- For **simulator**: Select any iOS simulator (e.g., "iPhone 15 Pro")
- For **physical device**: Connect your iPhone/iPad via USB and select it

## Step 6: Build and Run

Click the **Play** button (▶️) in Xcode or press `Cmd+R`.

Xcode will:
1. Compile the Flutter Dart code
2. Build the iOS native code
3. Install the app on your selected device
4. Launch the app

## Permissions Configured

The app has been configured with the following iOS permissions (in `Info.plist`):

- **Camera**: For capturing images for notes
- **Photo Library**: For saving shared images as notes
- **Microphone**: For recording voice notes
- **Speech Recognition**: For converting voice to text

Users will be prompted for these permissions when the app first needs them.

## Build Configurations

Three build configurations are available:

- **Debug**: For development with debugging enabled
- **Profile**: For performance profiling
- **Release**: For App Store distribution (optimized, no debugging)

Select these in Xcode under **Product > Scheme > Edit Scheme > Run > Build Configuration**.

## Troubleshooting

### "Command not found: flutter"
Ensure Flutter is installed and added to your PATH. Run `flutter doctor` to verify.

### "No Podfile found"
Make sure you're in the `ios/` directory when running `pod install`.

### Signing errors
Ensure you've selected a valid Team in Signing & Capabilities and that your Apple Developer account is active.

### Build errors after updating dependencies
Try cleaning the build:
```bash
flutter clean
cd ios
pod deintegrate
pod install
```

Then rebuild in Xcode.

## Building from Command Line (Alternative)

You can also build from the command line without opening Xcode:

```bash
# From project root
flutter build ios

# For specific configuration
flutter build ios --release
flutter build ios --debug
```

## Creating an IPA for Distribution

To create an IPA file for TestFlight or App Store:

1. In Xcode, select **Product > Archive**
2. Once archived, the Organizer window will open
3. Click **Distribute App**
4. Follow the wizard to upload to App Store Connect or export an IPA

Alternatively, use the command line:
```bash
flutter build ipa --release
```

The IPA will be created at `build/ios/ipa/`.

## Next Steps

- Test all features on a physical device
- Update app icon and splash screen if needed (already configured in `pubspec.yaml`)
- Review and update Info.plist descriptions to match your app's branding
- Configure push notifications if needed (requires additional setup)
- Submit to App Store when ready

## Support

For Flutter-specific issues, run:
```bash
flutter doctor -v
```

This will check your Flutter installation and highlight any issues.
