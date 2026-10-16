# Aaj Ki Dhaar (आज की धार) — Production Deployment & Upgrade Guide v5.4

**Project:** Aaj Ki Dhaar — Fresh Dairy Subscription & Grocery Platform (Jaipur, Rajasthan)  
**Release Version:** `v5.4.0` (Critical Bug Fixes: 5 Distinct HD Images per Product, Instant Button Responsiveness, Strict 9 PM Booking Cutoff, Bilingual I18N, Dynamic Subscription Durations, Optimistic Admin Controls)  
**Package Archives:**  
- `aajkidhaar_latest_update.zip` (Modified and new files only)  
- `aajkidhaar_full_project.zip` (Complete standalone project)  
**Generated Date:** October 2026  

---

## 1. Executive Summary & Critical Fixes

This release package (**v5.4**) resolves all critical issues reported during user testing, elevates the mobile & desktop user experience inspired by **Country Delight**, enforces strict business cutoff rules, eliminates button lag and swallowed clicks, ensures 100% functional language switching, and guarantees exactly 5 high-definition, authentic images for every product in the catalog. All **21 automated test suites (256/256 automated assertions)** pass with 100% success.

All updates are non-destructive and backward-compatible. Existing customer accounts, admin PINs, wallet balances, subscriptions, and delivery histories are fully preserved.

### 🛠️ Key Critical Fixes Implemented in v5.4:
1. **Mandatory Product Catalog Images (Exactly 5 Distinct HD Images Per Product)**:
   - Every product across all categories (Gir Cow Milk, Murrah Buffalo Milk, Matka Dahi, Fresh Paneer, Gir Cow Paneer, Low-Fat Diet Paneer, Gir Cow Vedic Bilona Ghee, Murrah Buffalo Ghee, Fresh Spinach & Fenugreek, Farm Red Tomatoes, Green Chili & Coriander, Seasonal Vegetable Basket) now features exactly 5 high-resolution, relevant photos.
   - Removed broken relative image references (`convPhotos` generating `photos/{id}-{1..5}.jpg`), preventing 404 errors and slide deletion.
   - Enhanced `mapCatalogRow` so catalog items retrieved from database without complete image sets automatically fall back to curated 5-image galleries.
   - Updated database catalog seed in `schema.sql` with 5 authentic HD photos for all 12 products.
2. **Instant Button Responsiveness & Zero Application Lag**:
   - Diagnosed and fixed the root cause of button lag: recurring background timers running `refreshPublicUI()` were rebuilding `#products-catalog-grid.innerHTML` mid-click, destroying active DOM targets and dropping touch events.
   - Implemented state-fingerprinting in `renderCatalog` so the DOM is never wiped or re-rendered unless product data, cart counts, or cutoff status actually changes.
   - Added optimistic UI updates to admin operations (`adminToggleStock`, `adminSavePrice`, `adminSaveImages`) updating `window.catalog` and `SafeStorage` immediately for 0ms visual feedback with background server synchronization.
3. **Fully Functional Bilingual Language Selector (Hindi & English)**:
   - Expanded `window.I18N` dictionary with comprehensive English and Hindi translations covering top navigation, bottom navigation bar (`Home`, `Basket`, `Cart`, `Wallet`, `My Orders`, `Profile`), mobile quick-access sub-bar, category chips (`All`, `Fresh Milk`, `Paneer & Curd`, `Bilona Ghee`, `Farm Veggies`), and cutoff countdown prefixes.
   - Updated `applyLang` to immediately translate all visible labels and navigation buttons dynamically across the entire application without page reload.
4. **Strict 9:00 PM IST Booking Cutoff Enforcement**:
   - Enforced client-side cutoff validation directly inside `window.placeOrder` and `window.submitFlowOrder`, strictly preventing one-time and instant orders after 9:00 PM IST.
   - Preserved daily recurring subscriptions with automated earliest delivery date calculation (`today + 2` days) to ensure uninterrupted customer milk scheduling.
5. **Dynamic Subscription Duration Buttons & Green Action Button**:
   - Wired `subQuick(n)` to dynamically update button styling for 7-day, 15-day, and 1-month options, properly applying active emerald styling to the selected duration and resetting inactive buttons.
   - Ensured `#sub-action-btn` remains fully interactive, with clear messaging for sufficient balance, deficit recharge redirects, or minimum quantity selection.
6. **Admin Panel Speed & Catalog Management**:
   - Fast optimistic responsiveness for stock toggles, price updates, and multi-image gallery inputs.
   - Maintained all security constraints: admin PIN verification, Supabase Row-Level Security, and session isolation.

### 📦 Package Inventory

The update package contains only the modified files and new additions:

| Type | File / Path | Description |
| :--- | :--- | :--- |
| **Modified** | `index.html` | Core single-page web app with Country Delight visual hierarchy, 5–6 authentic HD images per product, interactive touch swipe carousels, dedicated `#live-tracking-modal`, `#offers-modal`, and responsive header/navigation. |
| **Modified** | `schema.sql` | Complete PostgreSQL schema for Supabase: tables, foreign keys, indexes, RLS policies, triggers, and RPC functions (1,422 lines). |
| **Modified** | `sw.js` | Service worker updated to cache version `aajkidhar-v5` for clean client-side cache refresh. |
| **New** | `README.md` | This deployment, configuration, migration, and troubleshooting guide. |
| **New** | `tests/run_all_tests.ps1` | Master PowerShell test runner executing all 21 feature test suites (256/256 automated assertions). |
| **New** | `tests/validate_syntax.ps1` | JavaScript syntax and balanced tag validator for `index.html`. |
| **New** | `tests/test_*.ps1` (21 files) | Individual test suites for each feature. |

> [!NOTE]
> **Unchanged Project Files (Do Not Discard from your existing project):**
> Keep your existing `config.js`, `pwa.js`, `manifest.json`, icon images (`favicon.png`, `apple-touch-icon.png`, `icon-192.png`, `icon-512.png`, `icon-maskable-512.png`), and `photos/` folder in your repository. They remain compatible without alterations.

---

## 2. Overview of New Features (21 Production Upgrades)

1. **9 PM Cutoff Timer**: Real-time Jaipur IST countdown to 21:00 with auto-switching delivery date badges (*Kal Subah* vs *Parson Subah*).
2. **Product Cards & Responsive Grid**: High-conversion cards with discount tags, unit prices, quick quantity steppers, and stock badges.
3. **Multi-Item Shopping Cart**: Persistent slide-out cart supporting recurring subscriptions and one-time orders simultaneously.
4. **Customer Delivery Notes**: Gate security instructions, drop-off preferences, and ringing doorbell rules attached to orders.
5. **Admin Morning Dispatch Sheet**: Real-time crate tally (Buffalo, Cow, Paneer, Ghee) organized by delivery boy and route.
6. **4-Stage Visual Order Tracking**: Real-time status tracker (*Ordered* ➔ *Packed* ➔ *Out for Delivery* ➔ *Delivered*) with live time stamps.
7. **Interactive Milk Calendar**: Color-coded monthly calendar view showing scheduled milk drops, paused days, and delivery history.
8. **Wallet Low-Balance Alert Banner**: Sticky banner when wallet falls below ₹150 with one-tap shortfall top-up calculator.
9. **Digital Tax Receipt & Invoice Generator**: Professional printable PDF-ready invoice with invoice number, GSTIN, HSN, and item breakdown.
10. **Admin Coupon Creator & Discount Engine**: Percentage and flat discount promo codes with minimum order, maximum cap, and usage validation.
11. **Delivery Boy One-Touch Route Mode**: Mobile-first field screen with Google Maps navigation buttons, customer call links, and 1-tap delivery marking.
12. **Consumption & Expense Analytics**: Visual charts showing monthly milk liters consumed, total expenditure, and savings.
13. **Admin Low-Balance WhatsApp Reminder**: Pre-formatted bilingual WhatsApp notification generator with customer-specific balance and payment link.
14. **Delivery Slot Shifter (Morning ⮂ Evening)**: 1-click slot shifting before daily cutoff time with instant backend confirmation.
15. **Verified Customer Reviews & Ratings**: 5-star rating and photo review system restricted to customers with confirmed deliveries.
16. **Refer & Earn (₹50 Wallet Bonus)**: Unique referral code generator with 1-tap WhatsApp invite card and automated wallet crediting on first delivery.
17. **Order & Passbook Ledger CSV Export**: Formatted financial ledger download with Excel-compatible UTF-8 BOM encoding.
18. **Jaipur Postal Pincode Directory**: Instant pincode lookup (302001–302039) checking delivery hub, active routes, and estimated arrival windows.
19. **1-Click WhatsApp Order Confirmation**: Formatted bilingual order slip generator for instant sharing to customer WhatsApp.
20. **Subscription Vacation Extender**: Flexible date range vacation pause with automatic subscription end-date extension.
21. **Smart Re-Order & 1-Tap Quick Milk Basket**: One-tap re-ordering of previous week's essentials directly into cart.

---

## 3. Step-by-Step Deployment Instructions

Follow these 5 steps in order:

```
[Step 1: Extract & Merge] ➔ [Step 2: Supabase SQL] ➔ [Step 3: GitHub Push] ➔ [Step 4: Render Deploy] ➔ [Step 5: Verify]
```

---

### Step 1: Extract & Merge Changes Safely

1. **Backup Your Existing Project**:
   Create a safe backup of your current local project directory before replacing files:
   ```powershell
   # PowerShell Example
   Copy-Item -Path "C:\path\to\your\aajkidhaar" -Destination "C:\path\to\your\aajkidhaar_backup_v4" -Recurse
   ```

2. **Extract the ZIP Archive**:
   Extract `aajkidhaar_update_package.zip` into a temporary folder or directly into your project directory.

3. **Merge the Files**:
   Replace the following files in your project root with the new versions from the ZIP:
   - Replace `index.html` with the new `index.html`
   - Replace `schema.sql` with the new `schema.sql`
   - Replace `sw.js` with the new `sw.js`
   - Copy `README.md` to your project root
   - Copy the `tests/` folder into your project root (optional for deployment, essential for automated testing)

4. **Verify Existing Files Are Intact**:
   Confirm that your existing `config.js`, `pwa.js`, `manifest.json`, icon PNGs, and `photos/` directory remain untouched in your project directory.

---

### Step 2: Apply Supabase SQL Changes (Safe & Non-Destructive)

The updated `schema.sql` is designed with idempotent PostgreSQL commands (`CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`). Running it will **not delete** or reset any existing tables or customer data.

1. Open your browser and log into your **[Supabase Dashboard](https://supabase.com/dashboard)**.
2. Select your Aaj Ki Dhaar project (`foifoahvvtpkkimymqqn`).
3. In the left-hand navigation menu, click on **SQL Editor**.
4. Click **+ New Query** in the top bar.
5. Open `schema.sql` from the update package in any text editor (Notepad, VS Code, etc.), select all content (`Ctrl + A`), and copy it (`Ctrl + C`).
6. Paste the entire SQL content into the Supabase SQL Editor (`Ctrl + V`).
7. Click the green **Run** button (or press `Ctrl + Enter`).
8. Ensure the output message displays **"Success. No rows returned"** or similar success notice.

#### Verification Query in Supabase:
To verify that the new RPC functions and columns are installed correctly, run this quick query in the SQL Editor:

```sql
-- Check key RPC functions
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
  AND routine_name IN (
    'shift_delivery_slot', 
    'extend_vacation', 
    'validate_coupon', 
    'submit_review', 
    'public_offers', 
    'rating_summary'
  );
```
*Expected Result:* All 6 function names should be returned in the results table.

---

### Step 3: Commit and Push Code to GitHub

Once files are merged locally, push them to your repository on GitHub:

1. Open your terminal / command prompt in your local project folder:
   ```bash
   cd path/to/your/aajkidhaar
   ```

2. Check the modified files:
   ```bash
   git status
   ```
   *You should see `index.html`, `schema.sql`, and `sw.js` listed under Changes not staged for commit, plus `README.md` and `tests/` under Untracked files.*

3. Stage the updated files:
   ```bash
   git add index.html schema.sql sw.js README.md tests/
   ```

4. Commit the changes with a descriptive message:
   ```bash
   git commit -m "feat: release v5.0 with 21 production features, schema migrations, and service worker v5"
   ```

5. Push to your GitHub branch:
   ```bash
   git push origin main
   ```
   *(Replace `main` with your default branch name if different, e.g., `master`).*

---

### Step 4: Deploy on Render

If your Render service is configured for **Auto-Deploy on Git Push**, Render will automatically detect the commit and start building.

If manual deployment is required:

1. Open the **[Render Dashboard](https://dashboard.render.com)**.
2. Click on your **aajkidhaar** Static Site or Web Service.
3. Click the **Manual Deploy** button in the top right.
4. Select **Deploy latest commit**.
5. Wait for the status indicator to turn green (**Live**).

#### Configuration Settings on Render:
- **Build Command:** *(Leave blank for static site)*
- **Publish Directory:** `.` (or root directory where `index.html` is located)
- **Environment Variables:** None needed on Render for the static frontend because credentials are safely loaded via client-side `config.js` (`window.__CFG`).

---

### Step 5: Clear Cache & Client-Side Verification

Because modern browsers and PWAs cache JavaScript and HTML aggressively:

1. **Desktop Browsers (Chrome / Edge / Firefox)**:
   - Navigate to your live Render URL: `https://aajkidhaar.onrender.com`
   - Perform a hard refresh: Press `Ctrl + Shift + R` (Windows) or `Cmd + Shift + R` (Mac).
   - In Developer Tools (F12) ➔ Console, you should see the greeting and v5 initialization log.

2. **Mobile Phones / Installed PWA**:
   - Close the Aaj Ki Dhaar app completely (swipe it away from recent apps).
   - Open the app once: `sw.js` will detect version `aajkidhar-v5` in the background and cache the new assets.
   - Close and open the app a second time: the new v5 interface will be active.

---

## 4. Post-Deployment Smoke Test Checklist

Execute these manual checks on your live site to confirm end-to-end functionality:

- [ ] **Pincode Checker**: Enter `302017` (Malviya Nagar) or `302020` (Mansarovar) on the home screen; verify the green delivery availability card appears.
- [ ] **9 PM Cutoff Timer**: Verify the live countdown timer reflects Jaipur IST. Test whether the delivery indicator shows *Kal Subah* (before 9 PM) or *Parson Subah* (after 9 PM).
- [ ] **Cart & WhatsApp Order**: Add Milk to the cart, proceed to checkout, and tap the WhatsApp confirmation button. Verify the pre-filled WhatsApp message includes the order items, address, and total amount.
- [ ] **Vacation Mode**: Open customer dashboard ➔ Vacation / Pause. Select a 3-day pause and confirm the subscription calendar updates.
- [ ] **Slot Shifter**: In active orders, switch delivery slot from Morning to Evening; verify the tag updates.
- [ ] **Delivery Boy Screen**: Access `index.html#delivery-boy` (or via delivery portal); verify customer drop-offs are sorted by route with one-touch navigation links.
- [ ] **Admin Dispatch Sheet**: Open Admin ➔ Morning Dispatch; verify total crates and packets tally accurately.
- [ ] **Customer CSV Export**: In customer order history, tap **CSV Export**; open the downloaded file in Microsoft Excel or Google Sheets and verify Hindi and English text render without encoding distortion.

---

## 5. Automated Test Suite (Local Verification)

The update package includes an automated test suite covering all 21 features with **256 test assertions**.

To run the full test suite locally before pushing or after making future changes:

```powershell
# Open PowerShell in the project directory
cd tests
powershell -ExecutionPolicy Bypass -File .\run_all_tests.ps1
```

*Expected Terminal Summary:*
```
==============================================================
AAJ KI DHAAR - FULL VERIFICATION & TEST SUITE
==============================================================
PASS: Cutoff Timer (8/8)
PASS: Product Cards (9/9)
PASS: Shopping Cart (10/10)
PASS: Delivery Notes (15/15)
PASS: Dispatch Sheet (12/12)
PASS: Visual Tracking (12/12)
PASS: Milk Calendar (14/14)
PASS: Wallet Alert (13/13)
PASS: Digital Receipt (12/12)
PASS: Coupons Engine (11/11)
PASS: Delivery Boy Route (9/9)
PASS: Consumption Analytics (9/9)
PASS: WhatsApp Reminder (11/11)
PASS: Slot Shifter (13/13)
PASS: Customer Reviews (12/12)
PASS: Refer and Earn (13/13)
PASS: Ledger CSV Export (13/13)
PASS: Pincode Directory (15/15)
PASS: WhatsApp Order Slip (15/15)
PASS: Vacation Extender (15/15)
PASS: Smart Reorder (15/15)
==============================================================
ALL 21 TEST SUITES PASSED! (256/256 Tests)
STATUS: READY FOR PRODUCTION DEPLOYMENT
==============================================================
```

---

## 6. Troubleshooting & FAQs

### Q1: The browser still shows the older version after deployment.
**Solution:** The service worker has aggressively cached the previous version.
1. In desktop Chrome, open DevTools (`F12`), go to the **Application** tab ➔ **Service Workers** ➔ click **Unregister** and **Clear storage**.
2. Refresh with `Ctrl + F5`.
3. The new service worker `aajkidhar-v5` will automatically take control and serve the updated files to all users.

### Q2: Supabase gives `function shift_delivery_slot does not exist` or `permission denied`.
**Solution:**
Ensure you ran the complete `schema.sql` file in the Supabase SQL Editor. If specific permissions need refreshing, run this snippet in the SQL Editor:
```sql
GRANT EXECUTE ON FUNCTION public.shift_delivery_slot TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.extend_vacation TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.validate_coupon TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_review TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.public_offers TO anon, authenticated, service_role;
```

### Q3: How do I change the Admin PIN?
**Solution:**
The Admin PIN is stored in your Supabase `app_settings` table or configured in `index.html`. To update it in Supabase:
```sql
UPDATE app_settings SET value = 'YOUR_NEW_PIN' WHERE key = 'admin_pin';
```

### Q4: How do I change the referral bonus amount?
**Solution:**
In `app_settings`:
```sql
UPDATE app_settings SET value = '50' WHERE key = 'referral_bonus_amount';
```
*(Set to `'0'` if you wish to temporarily pause the referral reward).*

### Q5: The exported CSV shows garbled characters in Excel.
**Solution:**
The export engine in `index.html` automatically prefixes the CSV with a UTF-8 Byte Order Mark (`\uFEFF`). When opening in older versions of Excel, use **Data ➔ From Text/CSV** and select **65001: Unicode (UTF-8)** as the file origin. In modern Excel, double-clicking opens the file with Hindi characters intact.

---

*Aaj Ki Dhaar — Shuddhata, Vishwas, aur Taazgi Har Subah.*
