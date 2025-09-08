#!/bin/bash

echo "🚀 Deploying Purgo Cloud Functions..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo "🔐 Please log in to Firebase first:"
    firebase login
fi

# Install dependencies if needed
if [ ! -d "functions/node_modules" ]; then
    echo "📦 Installing function dependencies..."
    cd functions
    npm install
    cd ..
fi

# Deploy functions
echo "🚀 Deploying functions..."
firebase deploy --only functions

# Check deployment status
if [ $? -eq 0 ]; then
    echo "✅ Functions deployed successfully!"
    echo ""
    echo "📱 Your push notification system is now live:"
    echo "  • Friend request notifications"
    echo "  • Weekly leaderboard notifications (Mondays at midnight UTC)"
    echo "  • Monthly leaderboard notifications (1st of each month at midnight UTC)"
    echo ""
    echo "🔍 Monitor your functions at:"
    echo "https://console.firebase.google.com/project/$(firebase use)/functions"
else
    echo "❌ Function deployment failed. Check the logs above."
    exit 1
fi
