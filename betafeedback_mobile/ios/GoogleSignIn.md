# Google Sign-In (iOS)

After creating an **iOS OAuth client** in Google Cloud (bundle ID: `com.betafeedback.app`), add these keys to `ios/Runner/Info.plist` **inside the top-level `<dict>`**:

```xml
<key>GIDClientID</key>
<string>YOUR_IOS_CLIENT_ID.apps.googleusercontent.com</string>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.629984102803-1oh04iq2pl15ialne81gos0m8vh4uavj</string>
    </array>
  </dict>
</array>
```

The URL scheme is the iOS client ID with the domain reversed, e.g.  
`123456789-abc.apps.googleusercontent.com` → `com.googleusercontent.apps.123456789-abc`

Set the same iOS client ID on the backend:

```bash
GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
```
