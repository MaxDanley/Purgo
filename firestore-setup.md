# Firebase Firestore Setup Guide

## 🔥 Collections are Created Automatically!

**Good news**: You don't need to manually create collections in Firebase. When your app runs and users complete their first sessions, the collections will be created automatically by the app code.

## 📋 Required Manual Setup Steps:

### 1. **Firestore Security Rules**
Go to Firebase Console → Firestore Database → Rules and replace with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null; // Allow reading other users for search
    }
    
    // Sessions collection - users can only write their own sessions
    match /sessions/{sessionId} {
      allow read, write: if request.auth != null && resource.data.userId == request.auth.uid;
      allow read: if request.auth != null; // Allow reading for leaderboards
    }
    
    // Friendships collection
    match /friendships/{friendshipId} {
      allow read, write: if request.auth != null && 
        (resource.data.userId == request.auth.uid || resource.data.friendId == request.auth.uid);
    }
    
    // Notifications collection
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null && resource.data.toUserId == request.auth.uid;
      allow create: if request.auth != null && request.resource.data.fromUserId == request.auth.uid;
    }
  }
}
```

### 2. **Required Indexes** 
Go to Firebase Console → Firestore Database → Indexes and create these composite indexes:

```
Collection: sessions
Fields: createdAt (Ascending), userId (Ascending)

Collection: sessions  
Fields: createdAt (Descending), duration (Descending)

Collection: users
Fields: username (Ascending)

Collection: friendships
Fields: userId (Ascending), status (Ascending)

Collection: friendships
Fields: friendId (Ascending), status (Ascending)
```

### 3. **Authentication Setup**
Go to Firebase Console → Authentication → Sign-in method:
- Enable **Google** provider
- Add your iOS bundle ID
- Download updated `GoogleService-Info.plist` if needed

## 🚀 How Collections Get Created Automatically:

### When First User Signs In:
- `users` collection created with first user document

### When First Session Completes:
- `sessions` collection created with first session document
- User stats automatically updated in `users` collection

### When First Friend Request Sent:
- `friendships` collection created with first friendship document

### When First Notification Sent:
- `notifications` collection created with first notification document

## 🛠 Testing the Auto-Creation:

1. **Run your app**
2. **Sign in with Google** (creates `users` collection)
3. **Complete a session** (creates `sessions` collection)
4. **Search for and follow a friend** (creates `friendships` collection)
5. **Start a session with mutual friend** (creates `notifications` collection)

## 📱 Required Xcode Dependencies:

Add these to your project via Swift Package Manager:
```
https://github.com/firebase/firebase-ios-sdk
https://github.com/google/GoogleSignIn-iOS
```

Select these products:
- FirebaseAuth
- FirebaseFirestore
- GoogleSignIn

## 🔧 Optional: Firestore Emulator for Development

For local testing, you can use the Firestore emulator:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Initialize Firebase in your project
firebase init firestore

# Start emulator
firebase emulators:start --only firestore
```

Then add to your app initialization:
```swift
// In FirebaseManager.configureFirebase()
#if DEBUG
let settings = Firestore.firestore().settings
settings.host = "localhost:8080"
settings.isSSLEnabled = false
Firestore.firestore().settings = settings
#endif
```

## ✅ That's It!

Your collections will be created automatically when users interact with the app. No manual collection creation needed! 