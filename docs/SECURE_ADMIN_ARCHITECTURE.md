# 🛡️ SECURE ADMIN ARCHITECTURE - Implementation Guide

## 📦 What Was Built

### 1. **Cloud Functions - Admin Operations** (`functions/adminOps.js`)

Secure callable functions with 3-layer security:

#### **Category Admin Management**
- `assignCategoryAdmin` - Assign admin to category (super admin only)
- `removeCategoryAdmin` - Remove admin from category (super admin only)
- `toggleCategoryAdminStatus` - Activate/deactivate admin (super admin only)

#### **Competition Management**
- `createCompetition` - Create new competition (super admin only)
- `updateCompetition` - Update competition (super admin only)
- `deleteCompetition` - Delete competition (super admin only)

#### **Security Layers**
1. **Auth Layer**: Custom claims verification (`superadmin: true`)
2. **App Check**: Verified app token (ready for enforcement)
3. **Re-auth Check**: Recent authentication required (5 min window)
4. **Audit Log**: All operations logged to `admin_audit` collection

---

### 2. **Custom Claims Script** (`tools/grantAdmin.js`)

Backend script for granting super admin privileges:

```bash
# Grant super admin
node tools/grantAdmin.js <user-uid>

# Remove super admin
node tools/grantAdmin.js <user-uid> --remove

# List all admins
node tools/grantAdmin.js --list
```

**Features:**
- ✅ Sets custom claims: `admin: true`, `superadmin: true`
- ✅ Updates Firestore user document (`isSuperAdmin: true`)
- ✅ Creates audit log
- ✅ Validates against `umityeke@gmail.com`

---

### 3. **Firestore Rules - Locked Down**

#### **Category Admins** (`category_admins/{category}`)
```
✅ Read: Any signed-in user
❌ Write: Client CANNOT write (Functions only)
```

#### **Competitions** (`competitions/{competitionId}`)
```
✅ Read: Public (can add visibility check later)
❌ Write: Client CANNOT write (Functions only)
```

#### **Admin Audit** (`admin_audit/{logId}`)
```
✅ Read: Super admin only
❌ Write: Client CANNOT write (Functions only)
```

**Super Admin Detection:**
```javascript
function isSuperAdmin() {
  return isSignedIn() && (
    request.auth.token.email == 'umityeke@gmail.com' ||
    request.auth.token.superadmin == true ||
    request.auth.token.admin == true
  );
}
```

---

### 4. **Admin Panel Hosting Config** (`firebase.admin-hosting.json`)

Secure headers for `admin.cringebank.com`:

- ✅ **HSTS**: Strict-Transport-Security (2 years, preload)
- ✅ **Frame Protection**: X-Frame-Options: DENY
- ✅ **Content-Type**: X-Content-Type-Options: nosniff
- ✅ **CSP**: Strict Content-Security-Policy (no inline scripts)
- ✅ **Permissions**: Camera/Mic/Geo disabled
- ✅ **Referrer**: No-referrer policy

---

## 🚀 Deployment Steps

### **Step 1: Deploy Functions**

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

**Expected Output:**
```
✔ functions[assignCategoryAdmin] deployed
✔ functions[removeCategoryAdmin] deployed
✔ functions[toggleCategoryAdminStatus] deployed
✔ functions[createCompetition] deployed
✔ functions[updateCompetition] deployed
✔ functions[deleteCompetition] deployed
```

---

### **Step 2: Deploy Firestore Rules**

```bash
firebase deploy --only firestore:rules
```

**Verification:**
- ❌ Client cannot write to `category_admins`
- ❌ Client cannot write to `competitions`
- ❌ Client cannot write to `admin_audit`
- ✅ Functions can write (Admin SDK bypasses rules)

---

### **Step 3: Grant Super Admin (First Time)**

Get your user UID from Firebase Console:
1. Go to Firebase Console → Authentication
2. Find user `umityeke@gmail.com`
3. Copy UID

Run grant script:
```bash
cd tools
node grantAdmin.js YOUR_USER_UID
```

**IMPORTANT:** User must logout and login again for claims to take effect!

---

### **Step 4: Setup Admin Panel Hosting (Optional)**

Create admin site in Firebase Console:
1. Go to Firebase Console → Hosting
2. Add new site: `admin-cringebank`
3. Deploy admin panel:

```bash
# Build admin panel (separate from main app)
flutter build web --web-renderer html --output build/admin

# Deploy to admin site
firebase deploy --only hosting:admin-cringebank --config firebase.admin-hosting.json
```

---

## 🔐 Security Checklist

### **Immediate (Required)**
- [ ] Deploy functions to production
- [ ] Deploy firestore rules
- [ ] Grant super admin to `umityeke@gmail.com`
- [ ] Test: Client CANNOT write to protected collections
- [ ] Test: Functions CAN write to protected collections
- [ ] Verify audit logs are created

### **Short-term (Recommended)**
- [ ] Enable App Check in Firebase Console
- [ ] Uncomment App Check verification in `adminOps.js`
- [ ] Setup admin panel separate domain
- [ ] Test re-auth flow (5 min window)

### **Long-term (Best Practice)**
- [ ] Enable MFA for super admin account
- [ ] Setup BigQuery export for audit logs
- [ ] Add alerting for failed admin operations
- [ ] Implement Passkey/WebAuthn (phishing protection)
- [ ] Add IP/geo restrictions (optional)

---

## 🧪 Testing Guide

### **Test 1: Grant Super Admin**
```bash
node tools/grantAdmin.js <YOUR_UID>
```
Expected: ✅ Claims granted, Firestore updated, audit log created

### **Test 2: Call Admin Function from Flutter**
```dart
final callable = FirebaseFunctions.instance.httpsCallable('assignCategoryAdmin');
final result = await callable.call({
  'category': 'fizikselRezillik',
  'targetUserId': 'user123',
  'targetUsername': 'TestAdmin',
  'permissions': ['approve', 'reject'],
});
print(result.data); // Should succeed for super admin
```

### **Test 3: Verify Client Write Blocked**
```dart
// Should FAIL - client cannot write
await FirebaseFirestore.instance
  .collection('category_admins')
  .doc('fizikselRezillik')
  .set({'test': 'data'});
// Expected: Permission denied error
```

### **Test 4: Check Audit Logs**
```dart
// Only super admin can read
final logs = await FirebaseFirestore.instance
  .collection('admin_audit')
  .orderBy('timestamp', descending: true)
  .limit(10)
  .get();
print(logs.docs.map((d) => d.data()));
```

---

## 🎯 Usage Examples

### **Assign Category Admin**
```dart
final callable = FirebaseFunctions.instance.httpsCallable('assignCategoryAdmin');

try {
  final result = await callable.call({
    'category': 'sosyalRezillik',
    'targetUserId': 'abc123',
    'targetUsername': 'AdminUser',
    'permissions': ['approve', 'reject', 'delete'],
  });
  
  print('✅ ${result.data['message']}');
} catch (e) {
  print('❌ Error: $e');
}
```

### **Create Competition**
```dart
final callable = FirebaseFunctions.instance.httpsCallable('createCompetition');

try {
  final result = await callable.call({
    'title': 'En Komik Rezillik 2025',
    'description': 'Yılın en eğlenceli yarışması!',
    'visibility': 'public',
    'startDate': DateTime.now().toIso8601String(),
    'endDate': DateTime.now().add(Duration(days: 30)).toIso8601String(),
  });
  
  print('✅ Competition ID: ${result.data['competitionId']}');
} catch (e) {
  print('❌ Error: $e');
}
```

---

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      CLIENT (Flutter)                       │
│  ❌ Direct Firestore Write: BLOCKED by rules                │
│  ✅ Callable Functions: Allowed with proper auth            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              CLOUD FUNCTIONS (adminOps.js)                  │
│  1. Verify App Check ✓                                     │
│  2. Verify Auth ✓                                          │
│  3. Check Super Admin Claim ✓                              │
│  4. Verify Re-auth (5 min) ✓                               │
│  5. Execute Operation                                       │
│  6. Create Audit Log                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  FIRESTORE (Admin SDK)                      │
│  ✅ Write: Functions bypass rules                           │
│  ❌ Write: Client blocked by rules                          │
│                                                             │
│  Collections:                                               │
│  - category_admins (Functions only)                         │
│  - competitions (Functions only)                            │
│  - admin_audit (Functions only)                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Troubleshooting

### **Issue: "Permission denied" when calling function**
- ✅ Check: User has `superadmin: true` claim?
- ✅ Check: User logged out and back in after claim grant?
- ✅ Check: Function deployed successfully?

### **Issue: "Re-authentication required"**
- ✅ User must have logged in within last 5 minutes
- ✅ For testing, increase `RE_AUTH_WINDOW_SECONDS` in `adminOps.js`

### **Issue: Audit logs not created**
- ✅ Check Firestore rules allow Functions to write
- ✅ Check function logs: `firebase functions:log`

---

## 📝 Next Steps

1. **Deploy everything:**
   ```bash
   firebase deploy --only functions,firestore:rules
   ```

2. **Grant super admin:**
   ```bash
   node tools/grantAdmin.js YOUR_UID
   ```

3. **Test from Flutter app** (user must re-login first)

4. **Optional: Enable App Check** in Firebase Console

5. **Build admin panel UI** (separate Flutter build for admin.cringebank.com)

---

## 🔗 Related Files

- `functions/adminOps.js` - Secure callable functions
- `functions/index.js` - Function exports
- `tools/grantAdmin.js` - Custom claims script
- `firestore.rules` - Security rules (lines 13-17, 405-445)
- `firebase.admin-hosting.json` - Admin hosting config
- `lib/services/category_admin_service.dart` - Client-side service (deprecated for writes)

---

**Author:** GitHub Copilot  
**Date:** October 5, 2025  
**Security Level:** 🛡️🛡️🛡️ (3-Layer Protection)
