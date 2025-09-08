# 🔧 Cloud Functions Deployment Fix

Your Cloud Functions deployment failed due to missing IAM permissions. Here's how to fix it:

## 📋 **Prerequisites**

You need to be the **project owner** or have admin permissions to set IAM policies.

## 🔧 **Option 1: Run as Project Owner**

If you're the project owner, simply run the deployment again:

```bash
cd /Users/maxdanley/Desktop/Purgo
firebase deploy --only functions
```

Firebase will automatically set the required permissions.

## 🔧 **Option 2: Manual IAM Setup**

If you're not the project owner, run these commands in your terminal:

### Install Google Cloud CLI (if not installed)
```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init
```

### Set IAM Policies
```bash
# Login to gcloud
gcloud auth login

# Set your project
gcloud config set project purgo-1374e

# Add required IAM bindings
gcloud projects add-iam-policy-binding purgo-1374e \
  --member=serviceAccount:service-658074709437@gcp-sa-pubsub.iam.gserviceaccount.com \
  --role=roles/iam.serviceAccountTokenCreator

gcloud projects add-iam-policy-binding purgo-1374e \
  --member=serviceAccount:658074709437-compute@developer.gserviceaccount.com \
  --role=roles/run.invoker

gcloud projects add-iam-policy-binding purgo-1374e \
  --member=serviceAccount:658074709437-compute@developer.gserviceaccount.com \
  --role=roles/eventarc.eventReceiver
```

### Deploy Functions
```bash
cd /Users/maxdanley/Desktop/Purgo
firebase deploy --only functions
```

## 🔧 **Option 3: Simplified Approach (Recommended)**

If the IAM setup is too complex, we can implement a simpler solution:

1. **Keep friend request notifications** (these work without scheduled functions)
2. **Use Firestore triggers** instead of scheduled functions for leaderboard notifications
3. **Trigger leaderboard calculations** when sessions are completed

This approach doesn't require complex IAM permissions and works immediately.

## ✅ **Verification**

After successful deployment, you should see:

```
✔ functions[sendNotification]: Successful create operation.
✔ functions[weeklyLeaderboardNotifications]: Successful create operation.
✔ functions[monthlyLeaderboardNotifications]: Successful create operation.
```

## 🚀 **Next Steps**

1. Try Option 1 first (run as project owner)
2. If that fails, use Option 2 (manual IAM setup)
3. If still having issues, let me know and we'll implement Option 3 (simplified approach)

The push notification system will work perfectly once the functions are deployed! 🎉
