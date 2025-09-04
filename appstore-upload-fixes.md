# App Store Upload Error Fixes

## ✅ Fixed Issues

### 1. Info.plist UIBackgroundModes Fixed
- **Error**: `Invalid Info.plist value. The Info.plist key UIBackgroundModes contains an invalid value: 'background-app-refresh'`
- **Fix**: Changed `background-app-refresh` to `background-processing` in Info.plist
- **Status**: ✅ COMPLETED

## 🔧 Firebase dSYM Issues

### 2. Missing FirebaseAnalytics dSYM
**Error**: `The archive did not include a dSYM for the FirebaseAnalytics.framework`

### 3. Missing FirebaseFirestoreInternal dSYM  
**Error**: `The archive did not include a dSYM for the FirebaseFirestoreInternal.framework`

## 🛠️ How to Fix Firebase dSYM Issues

### Option 1: Update Build Settings (Recommended)
1. **Open Xcode Project**
2. **Select your app target** (Purgo)
3. **Go to Build Settings**
4. **Search for "Debug Information Format"**
5. **Set both Debug and Release to "DWARF with dSYM File"**

### Option 2: Clean and Rebuild
1. **Product → Clean Build Folder** (Cmd+Shift+K)
2. **Delete DerivedData**: 
   - Go to `~/Library/Developer/Xcode/DerivedData`
   - Delete the Purgo folder
3. **Archive again**: Product → Archive

### Option 3: Firebase Package Manager Fix
1. **Remove Firebase packages**:
   - Go to Project Settings → Package Dependencies
   - Remove all Firebase packages
2. **Re-add Firebase packages**:
   - Add `https://github.com/firebase/firebase-ios-sdk`
   - Select only the modules you need:
     - `FirebaseAuth`
     - `FirebaseCore` 
     - `FirebaseFirestore`
3. **Clean and rebuild**

### Option 4: Manual dSYM Upload (If still failing)
1. **Archive successfully** (even with warnings)
2. **Upload to App Store Connect**
3. **Download dSYMs** from App Store Connect
4. **Upload to Firebase Crashlytics** (if using)

## 🎯 Step-by-Step Fix Process

### Step 1: Build Settings
```
1. Select Purgo target
2. Build Settings → All → Combined
3. Search "Debug Information Format"
4. Set Debug: "DWARF with dSYM File"
5. Set Release: "DWARF with dSYM File"
```

### Step 2: Clean Everything
```
1. Product → Clean Build Folder
2. Delete ~/Library/Developer/Xcode/DerivedData/Purgo*
3. Restart Xcode
```

### Step 3: Archive Again
```
1. Product → Archive
2. Wait for completion
3. Upload to App Store
```

## 🚨 If Issues Persist

### Check Firebase Dependencies
Make sure you're only including the Firebase modules you actually use:
- ✅ `FirebaseAuth` (for Google Sign-In)
- ✅ `FirebaseCore` (required)
- ✅ `FirebaseFirestore` (for database)
- ❌ Remove `Firebase` (umbrella package)
- ❌ Remove unused modules

### Alternative: Disable dSYM for Release
If the upload keeps failing, you can temporarily disable dSYM generation:
1. Build Settings → Debug Information Format
2. Set Release to "DWARF" (without dSYM)
3. Archive and upload
4. **Note**: This will disable crash reporting symbolication

## 📋 Checklist Before Upload

- [x] Info.plist UIBackgroundModes fixed
- [ ] Debug Information Format set to "DWARF with dSYM File"
- [ ] Clean build folder completed
- [ ] DerivedData deleted
- [ ] Only necessary Firebase modules included
- [ ] Archive completed successfully
- [ ] Upload to App Store successful

## 💡 Prevention for Future Uploads

1. **Always use specific Firebase modules** instead of the umbrella package
2. **Keep Debug Information Format consistent** across all targets
3. **Regular clean builds** before archiving
4. **Test archive process** before final submission

The most likely fix is updating the Debug Information Format in Build Settings! 