# Test Suite for Customer 1-Click WhatsApp Order Confirmation and Slip Share
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$workspaceDir = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar"
$indexHtml = Join-Path $workspaceDir "index.html"

Write-Host "Running Customer 1-Click WhatsApp Order Confirmation and Slip Share Test Suite..." -ForegroundColor Cyan

$passed = 0
$total = 0

function Assert-Test($condition, $msg) {
    $script:total++
    if ($condition) {
        Write-Host "  [PASS] $msg" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  [FAIL] $msg" -ForegroundColor Red
    }
}

$content = [System.IO.File]::ReadAllText($indexHtml, [System.Text.Encoding]::UTF8)

# 1. Syntax integrity
$openScript = ([regex]::Matches($content, "<script", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
$closeScript = ([regex]::Matches($content, "</script>", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
Assert-Test ($openScript -eq $closeScript -and $openScript -gt 0) "Script tags balanced (Open=$openScript, Close=$closeScript)"

# Main JS block extraction and brace balance
$startIdx = $content.IndexOf("<script>")
$endIdx = $content.IndexOf("</script>", $startIdx)
$jsCode = $(if ($startIdx -ge 0 -and $endIdx -gt $startIdx) { $content.Substring($startIdx + 8, $endIdx - $startIdx - 8) } else { "" })
$openBraces = ([regex]::Matches($jsCode, '\{')).Count
$closeBraces = ([regex]::Matches($jsCode, '\}')).Count
Assert-Test ($openBraces -eq $closeBraces -and $openBraces -gt 1000) "JavaScript braces balanced across script blocks (Open=$openBraces, Close=$closeBraces)"

# 2. window.formatOrderWhatsAppMessage function
$hasFormatFn = $jsCode -match 'window\.formatOrderWhatsAppMessage\s*=\s*function\(orderId\)'
Assert-Test $hasFormatFn "window.formatOrderWhatsAppMessage function implemented"

# 3. Message formatting content checks
$hasMsgFields = $jsCode.Contains("Aaj Ki Dhaar") -and $jsCode.Contains("o.slot") -and $jsCode.Contains("o.total") -and $jsCode.Contains("aajkidhaar.onrender.com") -and $jsCode.Contains("7357911954")
Assert-Test $hasMsgFields "formatOrderWhatsAppMessage includes order ID, slot, total, tracking link, and helpline"

# 4. window.shareOrderWA function
$hasShareWA = $jsCode -match 'window\.shareOrderWA\s*=\s*function\(orderId\)' -and $jsCode.Contains('"https://wa.me/?text="')
Assert-Test $hasShareWA "window.shareOrderWA opens WhatsApp sharing link with encoded receipt"

# 5. window.shareReceiptWA backward compatibility alias
$hasShareReceipt = $jsCode -match 'window\.shareReceiptWA\s*=\s*function\(orderId\)'
Assert-Test $hasShareReceipt "window.shareReceiptWA maintained for backwards compatibility"

# 6. window.sendOrderToSupportWA helpline confirmation
$hasSupportWA = $jsCode -match 'window\.sendOrderToSupportWA\s*=\s*function\(orderId\)' -and $jsCode.Contains('"https://wa.me/917357911954?text="')
Assert-Test $hasSupportWA "window.sendOrderToSupportWA sends order details directly to care helpline"

# 7. window.formatSubscriptionWhatsAppMessage function
$hasSubMsg = $jsCode -match 'window\.formatSubscriptionWhatsAppMessage\s*=\s*function\(\)' -and $jsCode.Contains("s.dailyCost")
Assert-Test $hasSubMsg "window.formatSubscriptionWhatsAppMessage generates daily subscription basket summary"

# 8. window.shareSubscriptionWA function
$hasShareSub = $jsCode -match 'window\.shareSubscriptionWA\s*=\s*function\(\)'
Assert-Test $hasShareSub "window.shareSubscriptionWA function opens WhatsApp with subscription schedule"

# 9. window.showOrderSuccessBanner function
$hasSuccessBanner = $jsCode -match 'window\.showOrderSuccessBanner\s*=\s*function\(orderId,\s*total,\s*mode\)' -and $jsCode.Contains("order-success-prompt")
Assert-Test $hasSuccessBanner "window.showOrderSuccessBanner displays interactive post-order confirmation toast"

# 10. Single order triggers success banner
$hasSingleTrigger = $jsCode.Contains("window.showOrderSuccessBanner(r.order_id, r.total, mode)")
Assert-Test $hasSingleTrigger "placeOrder triggers instant WhatsApp confirmation banner with new order ID"

# 11. Multi-item cart checkout triggers success banner
$hasCartTrigger = $jsCode.Contains("window.showOrderSuccessBanner(latestOrd, totals.payable, mode)")
Assert-Test $hasCartTrigger "checkoutCart triggers instant WhatsApp confirmation banner for cart purchases"

# 12. Digital receipt modal includes WhatsApp share buttons
$hasReceiptBtns = $jsCode.Contains("window.shareOrderWA(") -and $jsCode.Contains("window.sendOrderToSupportWA(")
Assert-Test $hasReceiptBtns "openOrderReceipt modal embeds 1-click WhatsApp share and care helpline buttons"

# 13. Subscription receipt modal includes WhatsApp plan button
$hasSubReceiptBtn = $jsCode.Contains("window.shareSubscriptionWA()")
Assert-Test $hasSubReceiptBtn "openSubscriptionReceipt modal embeds WhatsApp plan share button"

# 14. My Orders cards include 1-click WhatsApp slip button
$hasOrdersCardBtn = $jsCode.Contains("window.shareOrderWA(") -and $jsCode.Contains("fa-brands fa-whatsapp text-emerald-600")
Assert-Test $hasOrdersCardBtn "My Orders history cards display 1-click WhatsApp slip button alongside bill receipt"

Write-Host ""
Write-Host "Test Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
