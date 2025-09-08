# 📱 Push Notifications Setup Guide

This guide covers setting up Firebase Cloud Messaging (FCM) for friend request notifications and automated weekly/monthly leaderboard notifications.

## 🔧 **Step 1: iOS App Configuration**

### 1.1 Add FCM to Xcode Project
1. Open your project in Xcode
2. Go to **Project Settings** → **Signing & Capabilities**
3. Click **+ Capability** and add **Push Notifications**
4. Click **+ Capability** and add **Background Modes**
5. Under Background Modes, check **Remote notifications**

### 1.2 APNs Certificate Setup
1. Go to [Apple Developer Console](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Keys** and create a new key
4. Enable **Apple Push Notifications service (APNs)**
5. Download the `.p8` key file
6. Note the **Key ID** and **Team ID**

### 1.3 Firebase Console Configuration
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your Purgo project
3. Go to **Project Settings** → **Cloud Messaging**
4. Under **iOS app configuration**:
   - Upload your APNs `.p8` key file
   - Enter your **Key ID** and **Team ID**
   - Save the configuration

## 🔧 **Step 2: Cloud Functions Setup**

### 2.1 Install Firebase CLI
```bash
npm install -g firebase-tools
firebase login
```

### 2.2 Initialize Functions (if not done)
```bash
cd /Users/maxdanley/Desktop/Purgo
firebase init functions
# Select JavaScript
# Install dependencies: Yes
```

### 2.3 Install Function Dependencies
```bash
cd functions
npm install firebase-admin firebase-functions node-cron
```

### 2.4 Deploy Cloud Functions
```bash
firebase deploy --only functions
```

## 🔧 **Step 3: Firestore Security Rules**

Update your Firestore rules to allow the Cloud Functions to read/write notifications:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow Cloud Functions to read/write notifications
    match /notifications/{document} {
      allow read, write: if true; // Cloud Functions have admin access
    }
    
    // Users can read/write their own data and FCM tokens
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null; // Allow reading other users for friend features
    }
    
    // Sessions can be read by authenticated users
    match /sessions/{sessionId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == resource.data.userId;
    }
    
    // Friendships
    match /friendships/{friendshipId} {
      allow read, write: if request.auth != null && 
        (request.auth.uid == resource.data.userId || request.auth.uid == resource.data.friendId);
    }
  }
}
```

## 🔧 **Step 4: Test Notifications**

### 4.1 Test Friend Request Notifications
1. Create two test accounts
2. Send a friend request from one to another
3. Check that the recipient gets a push notification
4. Tap the notification to ensure it opens the app to the Friends tab

### 4.2 Test Leaderboard Notifications (Manual)
You can manually trigger the leaderboard functions for testing:

```bash
# Test weekly notifications
firebase functions:shell
> weeklyLeaderboardNotifications()

# Test monthly notifications  
> monthlyLeaderboardNotifications()
```

## 🔧 **Step 5: Monitoring**

### 5.1 Check Function Logs
```bash
firebase functions:log
```

### 5.2 Monitor in Firebase Console
1. Go to **Functions** tab in Firebase Console
2. Check execution logs and error rates
3. Monitor **Cloud Messaging** tab for delivery metrics

## 📱 **Notification Types**

### Friend Request Notification
- **Title**: "New Friend Request"
- **Body**: "[Name] wants to be friends with you!"
- **Action**: Opens app to Friends tab
- **Data**: `type: "friend_request"`, `senderId: "..."`

### Leaderboard Notification
- **Title**: "🏆 1st Place This Week!" (example)
- **Body**: "Great job! You placed 1st this week in sauna sessions locally! Keep it up!"
- **Action**: Opens app to Leaderboard tab
- **Data**: `type: "leaderboard_ranking"`, `rank: "1"`, `scope: "town"`, `period: "weekly"`

## 🕒 **Automation Schedule**

- **Weekly Notifications**: Every Monday at 12:00 AM UTC
- **Monthly Notifications**: 1st day of each month at 12:00 AM UTC

## 🔍 **Troubleshooting**

### Common Issues:
1. **No FCM Token**: User needs to grant notification permissions
2. **APNs Certificate**: Ensure `.p8` key is correctly uploaded to Firebase
3. **Cloud Function Errors**: Check Firebase Functions logs
4. **Notification Not Received**: Check device notification settings
5. **App Not Opening**: Verify notification data and URL scheme handling

### Debug Commands:
```bash
# Check function deployment
firebase functions:list

# View function logs
firebase functions:log --only sendNotification

# Test notification sending
firebase functions:shell
```

## ✅ **Verification Checklist**

- [ ] Push Notifications capability added to Xcode
- [ ] APNs key uploaded to Firebase Console
- [ ] Cloud Functions deployed successfully
- [ ] FCM tokens being saved to Firestore
- [ ] Friend request notifications working
- [ ] App navigation working from notifications
- [ ] Leaderboard functions scheduled correctly
- [ ] Firestore security rules updated
- [ ] Test notifications received successfully

The push notification system is now fully configured! 🚀
