# 🔥 Firebase Hosting Setup for Apple Sign-In

## Quick Firebase Hosting Setup (5 minutes)

### 1. Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 2. Login and Initialize
```bash
# Login to Firebase
firebase login

# Navigate to your project directory
cd /Users/maxdanley/Desktop/Purgo

# Initialize Firebase Hosting
firebase init hosting
```

### 3. Select Options
- **Select your existing Firebase project** (Purgo)
- **Public directory**: `public` (default)
- **Single-page app**: `No`
- **Automatic builds**: `No`

### 4. Create Simple Index Page
Create `public/index.html`:
```html
<!DOCTYPE html>
<html>
<head>
    <title>Purgo - Sauna & Cold Therapy Timer</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
    <h1>Purgo</h1>
    <p>Your sauna and cold therapy companion app.</p>
    <p>Available on the App Store.</p>
</body>
</html>
```

### 5. Deploy
```bash
firebase deploy --only hosting
```

### 6. Get Your Domain
Firebase will give you a domain like:
`https://your-project-id.web.app`

## Use This Domain for Apple Sign-In Configuration

This domain satisfies Firebase's requirements and costs nothing!
