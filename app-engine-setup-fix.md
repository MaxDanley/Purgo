# 🔧 App Engine Setup Fix for Cloud Functions

Your Cloud Functions deployment failed because your Firebase project needs a Google App Engine instance. Here's how to fix it:

## 🌐 **Manual Setup (Recommended)**

### Step 1: Go to Google Cloud Console
1. Open [Google Cloud Console](https://console.cloud.google.com/)
2. Make sure you're in the **purgo-1374e** project
3. If not, click the project dropdown at the top and select **purgo-1374e**

### Step 2: Create App Engine Application
1. In the left sidebar, find **App Engine** and click it
2. If you see "Create Application", click it
3. Choose **us-central** as your region (same as your Firebase functions)
4. Click **Create app**
5. Wait for the App Engine instance to be created (takes 1-2 minutes)

### Step 3: Enable Required APIs
1. Go to **APIs & Services** → **Library**
2. Search for and enable these APIs:
   - **Cloud Functions API**
   - **Cloud Build API** 
   - **Artifact Registry API**
   - **Cloud Scheduler API**
   - **Eventarc API**
   - **Cloud Run API**

### Step 4: Deploy Functions
```bash
cd /Users/maxdanley/Desktop/Purgo
firebase deploy --only functions
```

## 🔧 **Alternative: Install Google Cloud CLI**

If you prefer using the command line:

```bash
# Install Google Cloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Login and set project
gcloud auth login
gcloud config set project purgo-1374e

# Create App Engine instance
gcloud app create --region=us-central

# Deploy functions
firebase deploy --only functions
```

## ✅ **Verification**

After creating the App Engine instance, you should see:
- App Engine dashboard showing your application
- Functions deployment should succeed without the authentication error

## 🚀 **Expected Success Output**

```
✔ functions[sendNotification]: Successful create operation.
✔ functions[weeklyLeaderboardNotifications]: Successful create operation.  
✔ functions[monthlyLeaderboardNotifications]: Successful create operation.

✔ Deploy complete!
```

## 📱 **What This Enables**

Once deployed, your push notification system will be fully operational:

1. **Friend Request Notifications**: Instant push notifications when someone sends a friend request
2. **Weekly Leaderboard**: Every Monday at midnight UTC, top 3 users get ranking notifications
3. **Monthly Leaderboard**: 1st of each month, top 3 users get ranking notifications

The manual App Engine setup is the quickest solution - it takes just 2-3 minutes in the Google Cloud Console! 🎉
