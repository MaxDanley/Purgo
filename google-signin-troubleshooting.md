# Fix Google Sign-In "Connection invalidated" Error

## 🚨 Error: [S:1] Error received: Connection invalidated

This error occurs when GoogleSignIn can't properly communicate back to your app. Here's how to fix it:

## 🔧 **Critical Fix: Add URL Scheme**

The most common cause is missing URL scheme configuration.

### **Step 1: Find Your REVERSED_CLIENT_ID**
1. Open `GoogleService-Info.plist` in Xcode
2. Find the key `REVERSED_CLIENT_ID` 
3. Copy its value (should look like: `com.googleusercontent.apps.123456789-abcdef...`)

### **Step 2: Add URL Scheme to Your App**
1. **Select your Purgo target** in Xcode
2. **Go to Info tab**
3. **Expand "URL Types"**
4. **Click "+" to add new URL Type**
5. **Set these values**:
   - **Identifier**: `GoogleSignIn`
   - **URL Schemes**: Paste your `REVERSED_CLIENT_ID` value here

**Example:**
```
Identifier: GoogleSignIn
URL Schemes: com.googleusercontent.apps.123456789-abcdefghijklmnop.apps.googleusercontent.com
```

## 📱 **Step 3: Verify GoogleService-Info.plist**

Make sure your `GoogleService-Info.plist`:
1. **Is in your Xcode project** (visible in project navigator)
2. **Has "Add to target" checked** for Purgo target
3. **Contains these required keys**:
   - `CLIENT_ID`
   - `REVERSED_CLIENT_ID`
   - `API_KEY`
   - `GCM_SENDER_ID`
   - `PROJECT_ID`

## 🔍 **Step 4: Check Bundle Identifier**

1. **In Firebase Console** → Project Settings → General
2. **Verify your iOS app** has the correct Bundle ID
3. **Should match** your Xcode target's Bundle Identifier exactly

## 🧪 **Step 5: Test Configuration**

Add this test function to verify setup:

```swift
// Add to FirebaseManager
func testGoogleSignInConfig() {
    print("🔍 Testing Google Sign-In Configuration:")
    print("Firebase App: \(FirebaseApp.app()?.name ?? "nil")")
    print("Client ID exists: \(FirebaseApp.app()?.options.clientID != nil)")
    print("GIDSignIn configured: \(GIDSignIn.sharedInstance.configuration != nil)")
    
    // Check if URL scheme is configured
    if let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] {
        print("URL Types configured: \(urlTypes.count)")
        for urlType in urlTypes {
            if let schemes = urlType["CFBundleURLSchemes"] as? [String] {
                print("URL Schemes: \(schemes)")
            }
        }
    } else {
        print("❌ No URL types configured!")
    }
}
```

## 🐛 **Common Specific Fixes:**

### **Fix 1: Wrong Bundle ID**
- Firebase Console bundle ID ≠ Xcode bundle ID
- **Solution**: Update one to match the other

### **Fix 2: Missing URL Scheme**
- No REVERSED_CLIENT_ID in URL schemes
- **Solution**: Follow Step 2 above

### **Fix 3: GoogleService-Info.plist Not in Bundle**
- File in project but not added to target
- **Solution**: Select file → File Inspector → check "Purgo" target

### **Fix 4: Simulator vs Device Issues**
- Sometimes works on simulator but not device (or vice versa)
- **Solution**: Test on both, ensure URL scheme is correct

### **Fix 5: Old GoogleService-Info.plist**
- Using outdated plist file
- **Solution**: Download fresh one from Firebase Console

## 🔄 **Step 6: Clean Build**

After making changes:
1. **Product** → **Clean Build Folder** (Cmd+Shift+K)
2. **Delete app from simulator/device**
3. **Build and run again** (Cmd+R)

## 📋 **Step 7: Test the Fix**

1. **Run app**
2. **Tap "Friends"**
3. **Tap "Sign in with Google"**
4. **Should see Google account selection**
5. **Check Xcode console for debug logs**

## 🆘 **If Still Not Working:**

Try this minimal test in your ContentView:

```swift
// Add temporary button to test
Button("Test Google Config") {
    if let firebaseManager = self.firebaseManager {
        firebaseManager.testGoogleSignInConfig()
    }
}
```

The debug output will tell you exactly what's missing.

---

**Most likely fix**: You're missing the URL scheme configuration (Step 2). This is required for Google to redirect back to your app after authentication. 