# Test Suite for Admin Coupon & Discount Code Manager (Feature 10)
$ErrorActionPreference = "Stop"

$indexPath = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\index.html"
$indexContent = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)

$schemaPath = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\schema.sql"
$schemaContent = [System.IO.File]::ReadAllText($schemaPath, [System.Text.Encoding]::UTF8)

$passed = 0
$total = 0

function Assert-Test($condition, $name) {
    $script:total++
    if ($condition) {
        $script:passed++
        Write-Host "  [PASS] $name" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $name" -ForegroundColor Red
    }
}

Write-Host "Running Admin Coupon & Discount Manager Test Suite..." -ForegroundColor Cyan

# 1. Script tag balance
$scriptOpen = ([regex]::Matches($indexContent, '<script\b')).Count
$scriptClose = ([regex]::Matches($indexContent, '</script>')).Count
Assert-Test ($scriptOpen -eq $scriptClose -and $scriptOpen -gt 0) "Script tags balanced (Open=$scriptOpen, Close=$scriptClose)"

# 2. JavaScript brace balance
$scripts = [regex]::Matches($indexContent, '(?s)<script\b[^>]*>(.*?)</script>')
$openBraces = 0
$closeBraces = 0
foreach ($s in $scripts) {
    $code = $s.Groups[1].Value
    $openBraces += ([regex]::Matches($code, '\{')).Count
    $closeBraces += ([regex]::Matches($code, '\}')).Count
}
Assert-Test ($openBraces -eq $closeBraces) "JavaScript braces balanced across script blocks (Open=$openBraces, Close=$closeBraces)"

# 3. schema.sql coupons table exists with limits
$hasCouponTable = ($schemaContent -match 'create table if not exists public\.coupons') -and 
                  ($schemaContent -match 'kind text not null check') -and 
                  ($schemaContent -match 'first_order_only') -and 
                  ($schemaContent -match 'once_per_user') -and 
                  ($schemaContent -match 'used_count')
Assert-Test $hasCouponTable "schema.sql defines coupons table with constraints and usage tracking columns"

# 4. schema.sql _coupon_calc enforces limits (expiry, min_order, first_order, once_per_user)
$hasCalcLogic = ($schemaContent -match 'c\.expires_on is not null and c\.expires_on <') -and 
                ($schemaContent -match 'p_amount < c\.min_order') -and 
                ($schemaContent -match 'c\.first_order_only and exists') -and 
                ($schemaContent -match 'c\.once_per_user and exists')
Assert-Test $hasCalcLogic "schema.sql _coupon_calc validates expiry, min_order, first-order, and single-use rules"

# 5. schema.sql admin_do handles save_coupon and delete_coupon
$hasAdminDoCoupons = ($schemaContent -match "p_action = 'save_coupon'") -and ($schemaContent -match "p_action = 'delete_coupon'")
Assert-Test $hasAdminDoCoupons "schema.sql admin_do RPC implements save_coupon and delete_coupon actions"

# 6. window.adminSetCouponFilter defined for search & filtering
$hasCouponFilter = $indexContent -match "window\.adminSetCouponFilter\s*=\s*function"
Assert-Test $hasCouponFilter "window.adminSetCouponFilter provides dynamic coupon search"

# 7. window.adminPrefillCoupon & window.adminEditCoupon defined
$hasEditFns = ($indexContent -match "window\.adminPrefillCoupon\s*=\s*function") -and ($indexContent -match "window\.adminEditCoupon\s*=\s*function")
Assert-Test $hasEditFns "window.adminPrefillCoupon and window.adminEditCoupon allow quick template/editing"

# 8. window.adminCouponsHTML renders metrics and quick presets
$hasCouponMetrics = ($indexContent -match 'activeCount') -and 
                    ($indexContent -match 'totalUsed') -and 
                    ($indexContent -match 'WELCOME50') -and 
                    ($indexContent -match 'FLAT50')
Assert-Test $hasCouponMetrics "adminCouponsHTML displays coupon stats summary and one-touch presets"

# 9. window.adminSaveCoupon validates code regex and percent cap
$hasSaveValidation = ($indexContent -match '\^\[A-Z0-9\]\{3,15\}\$') -and ($indexContent -match 'args\.kind === "percent"')
Assert-Test $hasSaveValidation "window.adminSaveCoupon enforces 3-15 alphanumeric format and 90% cap"

# 10. window.adminToggleCoupon and window.adminDeleteCoupon defined
$hasToggleDel = ($indexContent -match "window\.adminToggleCoupon\s*=\s*(async\s*)?function") -and ($indexContent -match "window\.adminDeleteCoupon\s*=\s*(async\s*)?function")
Assert-Test $hasToggleDel "window.adminToggleCoupon and window.adminDeleteCoupon manage lifecycle"

# 11. Cart modal includes available public offer chips for 1-click apply
$hasCartOfferChips = $indexContent -match "window\.appSettings\.offers\.slice"
Assert-Test $hasCartOfferChips "Cart modal coupon section shows available public offer chips"

Write-Host ""
Write-Host "Test Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
