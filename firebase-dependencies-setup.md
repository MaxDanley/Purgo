# Fix Firebase Dependencies - Step by Step

## 🚨 Error Fix: Missing required module 'FirebaseFirestoreInternalWrapper'

This error means Firebase SDK isn't properly added to your Xcode project. Follow these exact steps:

## 📱 **Step 1: Add Firebase SDK via Swift Package Manager**

1. **Open Xcode** with your Purgo project
2. **File** → **Add Package Dependencies...**
3. **Enter URL**: `https://github.com/firebase/firebase-ios-sdk`
4. **Click "Add Package"**
5. **Wait for it to resolve** (may take 1-2 minutes)

## 📦 **Step 2: Select Required Products**

When the product selection screen appears, check ONLY these boxes:
- ✅ **FirebaseAuth**
- ✅ **FirebaseCore** 
- ✅ **FirebaseFirestore**

**DON'T** select:
- ❌ Firebase (the umbrella package - this causes the internal wrapper error)
- ❌ Any other Firebase products you don't need

## 🔍 **Step 3: Add Google Sign-In SDK**

1. **File** → **Add Package Dependencies...**
2. **Enter URL**: `https://github.com/google/GoogleSignIn-iOS`
3. **Click "Add Package"**
4. **Select**: ✅ **GoogleSignIn**
5. **Important**: Make sure you get version 7.0.0 or later

## ⚙️ **Step 4: Verify Target Settings**

1. **Select your app target** (Purgo)
2. **Go to "Frameworks, Libraries, and Embedded Content"**
3. **Verify these are listed**:
   - FirebaseAuth
   - FirebaseCore
   - FirebaseFirestore
   - GoogleSignIn

## 🔧 **Step 5: Clean Build**

1. **Product** → **Clean Build Folder** (Cmd+Shift+K)
2. **Product** → **Build** (Cmd+B)

## 🎯 **Step 6: Add URL Scheme (for Google Sign-In)**

1. **Select your target** → **Info** tab
2. **Expand "URL Types"**
3. **Add new URL Type**:
   - **Identifier**: `com.googleusercontent.apps.YOUR_CLIENT_ID`
   - **URL Schemes**: Your REVERSED_CLIENT_ID from GoogleService-Info.plist

**Find REVERSED_CLIENT_ID**:
- Open `GoogleService-Info.plist`
- Copy the `REVERSED_CLIENT_ID` value
- Paste it as the URL Scheme

## 📋 **Alternative: Manual Package Addition**

If Swift Package Manager doesn't work:

1. **Remove existing Firebase packages** (if any)
2. **File** → **Add Package Dependencies**
3. **Try this exact URL**: `https://github.com/firebase/firebase-ios-sdk.git`
4. **Set version**: "Up to Next Major Version" starting from 10.0.0

## 🐛 **Common Issues & Fixes:**

### Issue: "Type 'GIDSignIn' has no member 'shared'"
**Fix**: You have an older GoogleSignIn version. Use `GIDSignIn.sharedInstance` instead

### Issue: "Module not found"
**Fix**: Clean build folder and rebuild

### Issue: "Duplicate symbols"  
**Fix**: Remove duplicate Firebase imports/packages

### Issue: "GoogleService-Info.plist not found"
**Fix**: Drag GoogleService-Info.plist into Xcode, ensure "Add to target" is checked

### Issue: "Client ID not found"
**Fix**: Verify GoogleService-Info.plist is in your app bundle (not just project)

## ✅ **Verification:**

After setup, your project should build without errors. You can test by:

1. **Run the app**
2. **Tap "Friends"** 
3. **Tap "Sign in with Google"**
4. **Should open Google sign-in flow**

## 🔄 **If Still Having Issues:**

Try this minimal test in your `FirebaseManager.swift`:

```swift
// Add this test function
func testFirebaseConnection() {
    print("Firebase app: \(FirebaseApp.app()?.name ?? "none")")
    print("Auth instance: \(Auth.auth())")
    print("Firestore instance: \(Firestore.firestore())")
}
```

Call it in your app to verify Firebase is properly initialized.

---

**The key issue**: You were importing `Firebase` (umbrella) instead of specific modules like `FirebaseCore`, `FirebaseAuth`, etc. The umbrella import can cause internal wrapper conflicts. 