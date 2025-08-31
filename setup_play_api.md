# Google Play Developer API Setup Guide

## 1. Enable API in Google Cloud Console

1. Go to: https://console.cloud.google.com
2. Create a new project or select existing one
3. Enable API:
   - Go to "APIs & Services" → "Enable APIs and Services"
   - Search for "Google Play Android Developer API"
   - Click "Enable"

## 2. Create Service Account

1. In Google Cloud Console:
   - Go to "IAM & Admin" → "Service Accounts"
   - Click "Create Service Account"
   - Name: "play-console-api"
   - Click "Create and Continue"
   - Skip permissions (we'll set in Play Console)
   - Click "Done"

2. Create Key:
   - Click on the service account you created
   - Go to "Keys" tab
   - Add Key → Create New Key → JSON
   - Save the JSON file as `play-api-key.json`

## 3. Grant Access in Play Console

1. Go to Play Console: https://play.google.com/console
2. Go to "Users and permissions"
3. Click "Invite new users"
4. Email: [service-account-email]@[project-id].iam.gserviceaccount.com
5. Grant permissions:
   - View app information
   - Manage store presence
   - Manage in-app products

## 4. Wait 24 Hours
- API access takes up to 24 hours to activate after first linking

## Alternative: Use OAuth 2.0 (Immediate Access)
- Can use your personal Google account
- No 24-hour wait
- More complex setup