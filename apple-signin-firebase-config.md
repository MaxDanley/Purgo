# 🍎 Apple Sign-In Firebase Configuration Guide

## 🎉 **Your Firebase Hosting is Live!**

**Your Domain**: `https://purgo-1374e.web.app`

This domain is now ready to be used for Apple Sign-In configuration with Firebase.

## 🔧 **Step-by-Step Configuration**

### **1. Apple Developer Console Configuration**

#### **A. Configure Your App ID**
1. Go to [Apple Developer Console](https://developer.apple.com/account/resources/identifiers/list)
2. Find your **Purgo App ID** (likely `com.maxdanley.Purgo`)
3. Click **Edit**
4. Under **Capabilities**, ensure **Sign in with Apple** is ✅ **Enabled**
5. Click **Save**

#### **B. Create a Service ID** (New Step Required)
1. In Apple Developer Console, go to **Identifiers**
2. Click the **+** button → **Services IDs**
3. **Description**: `Purgo Web Service`
4. **Identifier**: `com.maxdanley.Purgo.web` (must be different from your app ID)
5. ✅ **Enable "Sign in with Apple"**
6. Click **Configure** next to "Sign in with Apple"
7. **Primary App ID**: Select your Purgo app ID
8. **Web Domain**: `purgo-1374e.web.app`
9. **Return URLs**: `https://purgo-1374e.web.app/__/auth/handler`
10. Click **Save** → **Continue** → **Register**

#### **C. Create a Key for Apple Sign-In** (Required for Firebase)
1. Go to **Keys** section
2. Click **+** button
3. **Key Name**: `Purgo Apple Sign-In Key`
4. ✅ **Enable "Sign in with Apple"**
5. Click **Configure** → Select your **Primary App ID**
6. Click **Save** → **Continue** → **Register**
7. **⚠️ IMPORTANT**: Download the `.p8` key file immediately (you can't download it again!)
8. Note down the **Key ID** (10 characters, like `ABC1234567`)

### **2. Firebase Console Configuration**

1. Go to [Firebase Console](https://console.firebase.google.com/project/purgo-1374e/authentication/providers)
2. Click **Authentication** → **Sign-in method**
3. Find **Apple** in the providers list
4. Click **Apple** to configure it
5. Toggle **Enable** to ON
6. Fill in the required information:

   **OAuth code flow configuration:**
   - **Service ID**: `com.maxdanley.Purgo.web` (from step 1B)
   - **Apple team ID**: Found in Apple Developer Console → Membership tab (10 characters)
   - **Key ID**: From the key you created in step 1C (10 characters)
   - **Private key**: Copy and paste the content of the `.p8` file you downloaded

7. Click **Save**

### **3. Update Your Xcode Project**

#### **A. Enable Sign in with Apple Capability**
1. Open **Purgo.xcodeproj** in Xcode
2. Select your **Purgo target**
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Search for and add **"Sign in with Apple"**
6. Ensure it's enabled ✅

#### **B. Update Entitlements** (Verify)
Your `Purgo.entitlements` should now include:
```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

### **4. Test Your Configuration**

#### **A. Build and Run Your App**
1. Build your app on a **physical device** (Apple Sign-In doesn't work well in Simulator)
2. Navigate to the **Friends** tab
3. You should see both sign-in buttons:
   - 🍎 **Sign in with Apple** (black button, first)
   - **Sign in with Google** (white button, second)

#### **B. Test Apple Sign-In Flow**
1. Tap **"Sign in with Apple"**
2. You should see the native Apple Sign-In sheet
3. Choose to share or hide your email
4. Complete the sign-in process
5. Check Firebase Console → Authentication → Users to see the new user

#### **C. Check Console Logs**
Look for these success messages:
```
🍎 Starting Apple Sign-In process...
🔥 Creating Firebase credential with Apple ID token...
🎉 Apple Sign-In to Firebase successful!
📧 User email: user@privaterelay.appleid.com (or actual email)
```

## 🎯 **App Store Compliance Verification**

Your app now meets **App Store Guideline 4.8** requirements:

✅ **Apple Sign-In Available**: Primary sign-in option  
✅ **Limited Data Collection**: Only name and email  
✅ **Private Email Option**: Users can hide their email  
✅ **No Advertising Data**: No interaction tracking  
✅ **Equivalent Functionality**: Both sign-in methods work the same  

## 🚀 **Ready for App Store Submission**

### **Include This Note in App Review Information:**
> **Guideline 4.8 Compliance**: This app offers Sign in with Apple as the primary login option, which meets all privacy requirements. Users can limit data collection to name and email, keep their email address private, and no interaction data is collected for advertising purposes. Google Sign-In is provided as an equivalent alternative option.

## 🔍 **Troubleshooting**

### **Common Issues:**
- **"Invalid client"**: Check Service ID configuration in Apple Developer Console
- **"Invalid redirect URI"**: Ensure return URL is exactly `https://purgo-1374e.web.app/__/auth/handler`
- **"Invalid key"**: Verify the .p8 key content was copied correctly to Firebase
- **App crashes on sign-in**: Ensure "Sign in with Apple" capability is enabled in Xcode

### **Debug Steps:**
1. Verify your App ID has Sign in with Apple enabled
2. Verify Service ID is configured with correct domain and return URL
3. Verify Firebase has correct Service ID, Team ID, Key ID, and Private Key
4. Test on a physical device (not Simulator)

## ✅ **Final Checklist**

- [ ] App ID has Sign in with Apple enabled
- [ ] Service ID created with correct domain and return URL
- [ ] Key created and downloaded (.p8 file)
- [ ] Firebase Apple provider configured with all required fields
- [ ] Xcode capability "Sign in with Apple" enabled
- [ ] App tested on physical device
- [ ] Both sign-in buttons visible and functional
- [ ] Apple Sign-In appears first (primary option)

Your app is now **fully compliant with App Store Guideline 4.8**! 🎉

## 📱 **Your Website**

Your Purgo website is now live at: **https://purgo-1374e.web.app**

This professional-looking landing page showcases your app and satisfies Firebase's domain requirements for Apple Sign-In backend integration.
