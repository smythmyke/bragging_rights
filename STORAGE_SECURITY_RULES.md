# Firebase Storage Security Rules Documentation

## Overview
This document outlines the security rules for Firebase Storage in the Bragging Rights app, managing user uploads, media files, and document storage.

## Quick Deployment

```bash
# Deploy Storage rules
firebase deploy --only storage:rules

# Test rules locally
firebase emulators:start --only storage

# Run tests
npm test storage.rules.test.js
```

## Storage Structure & Permissions

### 📸 **User Avatars** (`/avatars/{userId}/`)
**Purpose**: Profile pictures for user accounts

| Permission | Who Can Access | Conditions |
|------------|---------------|------------|
| **Read** | Everyone | Public profiles |
| **Write** | Owner only | Must be image, max 5MB |
| **Delete** | Owner only | Remove own avatar |

**Example paths**:
- `/avatars/user123/profile.jpg`
- `/avatars/user123/avatar.png`

**Validation**:
- ✅ File type: images only (jpg, png, gif, etc.)
- ✅ Max size: 5MB
- ✅ User can only modify their own folder

### 🏀 **Team Logos** (`/teams/{sport}/{teamId}/`)
**Purpose**: Official team logos and imagery

| Permission | Who Can Access | Conditions |
|------------|---------------|------------|
| **Read** | Everyone | Public access |
| **Write** | Admins only | System managed |

**Example paths**:
- `/teams/nba/lakers/logo.png`
- `/teams/nfl/patriots/helmet.jpg`

### 🏆 **Achievement Badges** (`/achievements/{achievementId}/`)
**Purpose**: Gamification badges and rewards

| Permission | Who Can Access | Conditions |
|------------|---------------|------------|
| **Read** | Everyone | View all badges |
| **Write** | Admins only | System managed |

**Example paths**:
- `/achievements/first_win/badge.png`
- `/achievements/winning_streak/gold.png`

### 🎯 **Pool Images** (`/pools/{poolId}/cover/`)
**Purpose**: Cover images for betting pools

| Permission | Who Can Access | Conditions |
|------------|---------------|------------|
| **Read** | Authenticated users | Must be logged in |
| **Write** | Authenticated users | Image only, max 3MB |
| **Delete** | Pool creator | Owner only |

**Example paths**:
- `/pools/pool123/cover/banner.jpg`
- `/pools/superbowl2024/cover/image.png`

### 📄 **Verification Documents** (`/verification/{userId}/{documentType}/`)
**Purpose**: KYC/compliance documentation

| Permission | Who Can Access | Conditions |
|------------|---------------|------------|
| **Read** | Owner & Admins | Private documents |
| **Create** | Owner only | Images/PDFs, max 10MB |
| **Update** | ❌ Blocked | Audit trail |
| **Delete** | Admins only | After review |

**Example paths**:
- `/verification/user123/id/drivers_license.jpg`
- `/verification/user123/address/utility_bill.pdf`

**Security Features**:
- No updates allowed (maintains audit trail)
- Strict access control
- Admin review required

### 💬 **Chat Attachments** (`/chat/{poolId}/messages/{messageId}/`)
**Purpose**: Images and files shared in pool chats

| Permission | Who Can Access | Conditions |
|------------|---------------|------------|
| **Read** | Authenticated users | Must be logged in |
| **Create** | Authenticated users | Images/PDFs, max 5MB |
| **Update** | ❌ Blocked | Immutable messages |
| **Delete** | Message sender | Own attachments only |

**Example paths**:
- `/chat/pool123/messages/msg456/screenshot.jpg`
- `/chat/pool123/messages/msg789/bracket.pdf`

### 📁 **Temporary Uploads** (`/temp/{userId}/{sessionId}/`)
**Purpose**: Staging area for file processing

| Permission | Who Can Access | Conditions |
|------------|---------------|------------|
| **Read** | Owner only | Private workspace |
| **Create** | Owner only | Any file, max 10MB |
| **Update** | ❌ Blocked | No modifications |
| **Delete** | Owner only | Cleanup allowed |

**Example paths**:
- `/temp/user123/session456/upload.jpg`
- `/temp/user123/session789/processing.tmp`

### 📊 **Reports & Exports** (`/reports/{userId}/{reportId}/`)
**Purpose**: User-generated reports and data exports

| Permission | Who Can Access | Conditions |
|------------|---------------|------------|
| **Read** | Owner only | Private reports |
| **Write** | ❌ System only | Cloud Functions generate |

**Example paths**:
- `/reports/user123/monthly_2024_01/statement.pdf`
- `/reports/user123/tax_2023/summary.csv`

### 🎨 **App Assets** (`/app_assets/{category}/`)
**Purpose**: Application resources and media

| Permission | Who Can Access | Conditions |
|------------|---------------|------------|
| **Read** | Everyone | Public resources |
| **Write** | Admins only | System managed |

**Example paths**:
- `/app_assets/icons/app_icon.png`
- `/app_assets/backgrounds/home_screen.jpg`
- `/animations/loading.json`

### 💾 **Backups** (`/backups/{date}/`)
**Purpose**: System backups and archives

| Permission | Who Can Access | Conditions |
|------------|---------------|------------|
| **Read** | Admins only | Restricted access |
| **Write** | Admins only | System backups |

## File Type Validations

### Allowed Image Types
```javascript
contentType.matches('image/.*')
```
- ✅ image/jpeg
- ✅ image/png
- ✅ image/gif
- ✅ image/webp
- ✅ image/svg+xml

### Allowed Document Types
```javascript
contentType.matches('application/pdf')
```
- ✅ application/pdf

### Allowed Video Types
```javascript
contentType.matches('video/.*')
```
- ✅ video/mp4
- ✅ video/quicktime
- ✅ video/webm

## Size Limits by Category

| Category | Max Size | Reason |
|----------|----------|--------|
| User Avatars | 5 MB | Quick loading for profiles |
| Pool Covers | 3 MB | Multiple images per page |
| Chat Attachments | 5 MB | Reasonable for sharing |
| Verification Docs | 10 MB | High-quality documents |
| Temp Uploads | 10 MB | Processing buffer |

## Security Best Practices

### ✅ **DO**:
1. **Validate file types** - Only allow expected formats
2. **Enforce size limits** - Prevent storage abuse
3. **Use path patterns** - Organize files logically
4. **Implement audit trails** - Block updates where needed
5. **Test thoroughly** - Use emulator before deployment

### ❌ **DON'T**:
1. **Allow arbitrary paths** - Use defined structure
2. **Skip validation** - Always check file properties
3. **Grant broad permissions** - Be specific
4. **Allow public writes** - Require authentication
5. **Forget cleanup** - Remove temporary files

## Common Use Cases

### Profile Picture Upload
```javascript
// Flutter/Dart example
final ref = FirebaseStorage.instance
  .ref('avatars/${user.uid}/profile.jpg');
  
await ref.putFile(
  imageFile,
  SettableMetadata(contentType: 'image/jpeg')
);

final downloadUrl = await ref.getDownloadURL();
```

### Pool Cover Image
```javascript
// Upload pool cover
final ref = FirebaseStorage.instance
  .ref('pools/$poolId/cover/image.jpg');
  
await ref.putFile(
  coverImage,
  SettableMetadata(contentType: 'image/jpeg')
);
```

### Verification Document
```javascript
// Upload verification document
final ref = FirebaseStorage.instance
  .ref('verification/${user.uid}/id/license.jpg');
  
await ref.putFile(
  documentFile,
  SettableMetadata(contentType: 'image/jpeg')
);
```

## Testing the Rules

### Using Firebase Console
1. Go to Storage → Rules
2. Use Rules Playground
3. Test different scenarios:
   - Authenticated vs unauthenticated
   - Different file types
   - Various file sizes
   - Different user contexts

### Using Emulator
```bash
# Start Storage emulator
firebase emulators:start --only storage

# Run tests
npm test storage.rules.test.js
```

### Test Scenarios
1. **Avatar Upload**: User uploads profile picture
2. **Size Limit**: Upload exceeds max size
3. **Wrong Type**: Upload PDF as avatar
4. **Cross-User**: Access another user's files
5. **Admin Access**: Admin manages team logos

## Monitoring & Maintenance

### Storage Metrics to Monitor
- Total storage used per user
- Upload frequency patterns
- Failed upload attempts
- Storage costs by category

### Cleanup Strategies
1. **Temporary Files**: Auto-delete after 24 hours
2. **Old Avatars**: Keep only current + 1 previous
3. **Chat Attachments**: Archive after 90 days
4. **Reports**: Delete after 1 year

### Cost Optimization
- Implement lifecycle rules
- Use appropriate image compression
- Clean up orphaned files
- Monitor bandwidth usage

## Migration & Updates

### Adding New Categories
1. Define path structure
2. Set appropriate permissions
3. Add validation rules
4. Test with emulator
5. Deploy to production

### Updating Size Limits
1. Analyze current usage
2. Update rules
3. Test edge cases
4. Communicate to users
5. Deploy gradually

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| Permission denied | Unauthorized access | Check authentication |
| Invalid file type | Wrong content type | Validate before upload |
| File too large | Exceeds size limit | Compress or chunk upload |
| Path not allowed | Undefined storage path | Use approved paths |

### Client-Side Validation
Always validate on client before attempting upload:
```javascript
// Check file size
if (file.size > 5 * 1024 * 1024) {
  throw new Error('File too large');
}

// Check file type
if (!file.type.startsWith('image/')) {
  throw new Error('Only images allowed');
}
```

## Support & Resources

### Firebase Documentation
- [Storage Security Rules](https://firebase.google.com/docs/storage/security)
- [Rules Language Reference](https://firebase.google.com/docs/storage/security/rules-language)
- [Testing Rules](https://firebase.google.com/docs/storage/security/test-rules-emulator)

### Debugging
- Check Firebase Console logs
- Use Rules Playground
- Test with emulator first
- Monitor usage patterns

### Contact
- Technical issues: Check Firebase Console
- Security concerns: Review audit logs
- Rule violations: Check client implementation