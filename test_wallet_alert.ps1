# Test Suite for Wallet Low Balance Alert & Auto-Topup Prompt (Feature 8)
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

Write-Host "Running Wallet Low Balance Alert Test Suite..." -ForegroundColor Cyan

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

# 3. getWalletLowBalanceStatus function exists and computes threshold
$hasStatusFn = $indexContent -match "window\.getWalletLowBalanceStatus\s*=\s*function"
Assert-Test $hasStatusFn "window.getWalletLowBalanceStatus function is defined"

# 4. Check subscription 3-day buffer threshold calculation
$hasThresholdCalc = $indexContent -match "threshold\s*=\s*hasSub\s*\?\s*Math\.max\(dailyCost\s*\*\s*3,\s*100\)\s*:\s*100"
Assert-Test $hasThresholdCalc "Threshold enforces Math.max(dailyCost * 3, 100) 3-day buffer for dairy subscriptions"

# 5. Check critical balance calculation
$hasCriticalCalc = $indexContent -match "isCritical\s*=\s*hasSub\s*\?\s*\(a\.wallet\s*<\s*dailyCost\)\s*:\s*\(a\.wallet\s*===\s*0\)"
Assert-Test $hasCriticalCalc "Critical condition checks wallet < dailyCost for subscribers or 0 for non-subscribers"

# 6. Check suggested topup calculation
$hasSuggestedCalc = $indexContent -match "suggested\s*=\s*deficit\s*>\s*500\s*\?\s*Math\.ceil\(deficit\s*/\s*500\)\s*\*\s*500"
Assert-Test $hasSuggestedCalc "Suggested topup rounds up intelligently to ₹500/₹200 blocks"

# 7. Check dismissLowBalanceBanner function
$hasDismissFn = $indexContent -match "window\.dismissLowBalanceBanner\s*=\s*function"
Assert-Test $hasDismissFn "window.dismissLowBalanceBanner function is defined"

# 8. Check renderWalletLowBalanceAlert function
$hasAlertFn = $indexContent -match "window\.renderWalletLowBalanceAlert\s*=\s*function"
Assert-Test $hasAlertFn "window.renderWalletLowBalanceAlert function is defined"

# 9. Header wallet button contains all IDs for dynamic styling
$hasHeaderWalletIds = ($indexContent -match 'id="header-wallet-btn"') -and 
                       ($indexContent -match 'id="header-wallet-icon"') -and 
                       ($indexContent -match 'id="header-wallet-label"') -and 
                       ($indexContent -match 'id="header-wallet-badge"')
Assert-Test $hasHeaderWalletIds "Header wallet pill includes required IDs (header-wallet-btn, icon, label, badge)"

# 10. Homepage low balance banner markup is present directly under header
$hasBannerMarkup = ($indexContent -match 'id="wallet-low-balance-banner"') -and 
                    ($indexContent -match 'id="wallet-low-balance-title"') -and 
                    ($indexContent -match 'id="wallet-low-balance-desc"') -and 
                    ($indexContent -match 'id="wallet-low-balance-topup-btn"')
Assert-Test $hasBannerMarkup "Homepage low balance alert banner DOM markup is present"

# 11. updateWalletUI calls renderWalletLowBalanceAlert
$hasUpdateWalletIntegration = $indexContent -match "window\.updateWalletUI\s*=\s*function\(\)\s*\{[^}]*window\.renderWalletLowBalanceAlert\(\);"
Assert-Test $hasUpdateWalletIntegration "window.updateWalletUI triggers window.renderWalletLowBalanceAlert"

# 12. openRechargeModal accepts custom amount prefill
$hasCustomAmtRecharge = $indexContent -match "window\.openRechargeModal\s*=\s*function\(customAmount\)"
Assert-Test $hasCustomAmtRecharge "window.openRechargeModal accepts customAmount parameter"

# 13. Cart modal shortfall includes 1-click openRechargeModal CTA
$hasCartShortfallCTA = $indexContent -match "window\.openRechargeModal\(\s*'\s*\+\s*cartDeficit\s*\+\s*'\s*\)"
Assert-Test $hasCartShortfallCTA "Cart modal shortfall provides 1-click recharge button with deficit amount"

Write-Host ""
Write-Host "Test Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
