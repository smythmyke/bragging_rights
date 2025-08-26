#!/bin/bash

echo "🔒 Deploying Firestore Security Rules for Bragging Rights"
echo "========================================="

# Check if firebase-tools is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
fi

# Check if we're in the right directory
if [ ! -f "firestore.rules" ]; then
    echo "❌ firestore.rules file not found in current directory"
    exit 1
fi

# Backup current rules (if they exist)
echo "📦 Creating backup of current rules..."
firebase firestore:rules:get > firestore.rules.backup.$(date +%Y%m%d_%H%M%S).txt 2>/dev/null

# Test rules locally first (optional - requires emulator setup)
echo "🧪 Testing rules locally..."
if [ -f "firestore.rules.test.js" ]; then
    echo "Running security rules tests..."
    # Uncomment if you have tests set up:
    # npm test
else
    echo "⚠️  No test file found, skipping tests"
fi

# Deploy rules to Firebase
echo "🚀 Deploying rules to Firebase..."
firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
    echo "✅ Firestore security rules deployed successfully!"
    echo ""
    echo "📋 Rules Summary:"
    echo "  • Users can only read/write their own data"
    echo "  • Wallet balances are read-only (server-managed)"
    echo "  • Bets require sufficient balance and game not started"
    echo "  • Pools have controlled join mechanics"
    echo "  • Transactions are read-only for users"
    echo "  • Leaderboards are publicly readable"
    echo ""
    echo "⚠️  Important Notes:"
    echo "  1. Test thoroughly in development before production"
    echo "  2. Monitor Firebase Console for rule violations"
    echo "  3. Set up admin custom claims for admin users"
    echo "  4. Implement Cloud Functions for secure wallet operations"
else
    echo "❌ Failed to deploy rules. Check your Firebase configuration."
    exit 1
fi

echo "========================================="
echo "Next steps:"
echo "1. Test the rules in Firebase Console Simulator"
echo "2. Monitor security rule denials in Firebase Console"
echo "3. Set up Cloud Functions for secure operations"