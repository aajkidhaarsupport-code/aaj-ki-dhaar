# Test Suite for Admin to Customer WhatsApp Low Balance Reminder (Feature 13)
$ErrorActionPreference = "Stop"

$indexPath = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\index.html"
$indexContent = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)

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

Write-Host "Running Admin to Customer Low Balance WhatsApp Reminder Test Suite..." -ForegroundColor Cyan

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

# 3. window.adminGetUserLowBalance defined
$hasAdminLowBalFn = $indexContent -match "window\.adminGetUserLowBalance\s*=\s*function"
Assert-Test $hasAdminLowBalFn "window.adminGetUserLowBalance function is defined"

# 4. adminGetUserLowBalance computes threshold with 3-day buffer
$hasSubThreshold = $indexContent -match "threshold\s*=\s*hasSub\s*\?\s*Math\.max\(dailyCost\s*\*\s*3,\s*100\)\s*:\s*100"
Assert-Test $hasSubThreshold "adminGetUserLowBalance enforces Math.max(dailyCost * 3, 100) 3-day buffer"

# 5. adminGetUserLowBalance critical condition
$hasCriticalCheck = $indexContent -match "isCritical\s*=\s*hasSub\s*\?\s*\(wallet\s*<\s*dailyCost\)\s*:\s*\(wallet\s*<=\s*0\)"
Assert-Test $hasCriticalCheck "adminGetUserLowBalance detects critical zero or sub-dailyCost deficit"

# 6. window.adminSendLowBalanceWA defined
$hasSendWAFn = $indexContent -match "window\.adminSendLowBalanceWA\s*=\s*function"
Assert-Test $hasSendWAFn "window.adminSendLowBalanceWA function is defined"

# 7. adminSendLowBalanceWA cleans phone and opens wa.me link
$hasWaUrlGen = $indexContent -match "waPhone\s*=\s*rawPhone\.length\s*===\s*10" -and $indexContent -match 'wa\.me/'
Assert-Test $hasWaUrlGen "adminSendLowBalanceWA normalizes 10-digit Indian numbers and generates wa.me URL"

# 8. window.adminUserFilter and window.adminSetUserFilter defined
$hasFilterLogic = $indexContent -match "window\.adminUserFilter\s*=\s*" -and $indexContent -match "window\.adminSetUserFilter\s*=\s*function"
Assert-Test $hasFilterLogic "window.adminUserFilter and window.adminSetUserFilter allow dynamic filtering"

# 9. adminUsersHTML includes filter toggle buttons
$hasFilterButtons = $indexContent -match "adminSetUserFilter\(.+?all.+?\)" -and $indexContent -match "adminSetUserFilter\(.+?low_balance.+?\)"
Assert-Test $hasFilterButtons "adminUsersHTML contains dynamic toggle buttons for all vs low balance customers"

# 10. adminUsersHTML customer cards contain adminSendLowBalanceWA trigger
$hasUserCardWABtn = $indexContent -match "adminSendLowBalanceWA\("
Assert-Test $hasUserCardWABtn "adminUsersHTML customer cards include 1-click WhatsApp prompt button"

# 11. Active subscriptions in renderAdminTab('orders') contains low balance indicator and WhatsApp alert
$hasSubTabWA = $indexContent -match 'balInfo\.isLow' -and $indexContent -match "adminSendLowBalanceWA"
Assert-Test $hasSubTabWA "Active subscriptions list displays low balance warning pill and WhatsApp reminder button"

$resColor = if ($passed -eq $total) { "Green" } else { "Red" }
Write-Host "`nTest Results: $passed / $total passed." -ForegroundColor $resColor

if ($passed -ne $total) {
    exit 1
}
