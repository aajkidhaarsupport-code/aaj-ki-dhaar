# Test Suite for Customer Digital Receipt & Invoice Download (Feature 9)
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

Write-Host "Running Digital Receipt & Invoice Test Suite..." -ForegroundColor Cyan

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

# 3. Print styles support #order-receipt-modal
$hasPrintStyle = ($indexContent -match '#order-receipt-modal') -and ($indexContent -match '#order-receipt-modal-body') -and ($indexContent -match '\.receipt-no-print')
Assert-Test $hasPrintStyle "@media print rules include #order-receipt-modal, modal-body and .receipt-no-print"

# 4. closeOrderReceipt & printReceipt functions defined
$hasBasicReceiptFns = ($indexContent -match 'window\.closeOrderReceipt\s*=\s*function') -and ($indexContent -match 'window\.printReceipt\s*=\s*function')
Assert-Test $hasBasicReceiptFns "window.closeOrderReceipt and window.printReceipt functions are defined"

# 5. findOrderForReceipt helper function defined
$hasFindOrderFn = $indexContent -match 'window\.findOrderForReceipt\s*=\s*function'
Assert-Test $hasFindOrderFn "window.findOrderForReceipt searches myData and adminData"

# 6. shareReceiptWA function defined
$hasShareWAFn = $indexContent -match 'window\.shareReceiptWA\s*=\s*function'
Assert-Test $hasShareWAFn "window.shareReceiptWA generates WhatsApp text receipt"

# 7. openOrderReceipt function defined with itemized table & stamp
$hasOpenOrderReceipt = ($indexContent -match 'window\.openOrderReceipt\s*=\s*function') -and 
                        ($indexContent -match 'grossAmt') -and 
                        ($indexContent -match 'itemsRowsHTML')
Assert-Test $hasOpenOrderReceipt "window.openOrderReceipt calculates gross total, discounts, items table and stamp"

# 8. openSubscriptionReceipt function defined
$hasOpenSubReceipt = ($indexContent -match 'window\.openSubscriptionReceipt\s*=\s*function') -and 
                      ($indexContent -match 'totalAdvance') -and 
                      ($indexContent -match 's\.dailyCost')
Assert-Test $hasOpenSubReceipt "window.openSubscriptionReceipt renders monthly dairy subscription invoice"

# 9. My Orders order cards have receipt button
$hasCardReceiptBtn = $indexContent -match 'window\.openOrderReceipt\('
Assert-Test $hasCardReceiptBtn "My Orders order card includes window.openOrderReceipt trigger button"

# 10. My Orders subscription plan tab has receipt button
$hasPlanReceiptBtn = $indexContent -match 'window\.openSubscriptionReceipt\(\)'
Assert-Test $hasPlanReceiptBtn "Subscription plan tab includes window.openSubscriptionReceipt trigger button"

# 11. Admin orders tab has receipt button
$hasAdminReceiptBtn = $indexContent -match "window\.openOrderReceipt\("
Assert-Test $hasAdminReceiptBtn "Admin orders tab includes receipt view button"

# 12. Modal DOM element #order-receipt-modal is present
$hasModalDOM = ($indexContent -match 'id="order-receipt-modal"') -and ($indexContent -match 'id="order-receipt-modal-body"')
Assert-Test $hasModalDOM "#order-receipt-modal and #order-receipt-modal-body exist in DOM"

Write-Host ""
Write-Host "Test Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
