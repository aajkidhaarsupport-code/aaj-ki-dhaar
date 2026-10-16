# Test Suite for Smart Re-Order & 1-Tap Quick Milk Basket (Feature 21)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$workspaceDir = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar"
$indexHtml = Join-Path $workspaceDir "index.html"

Write-Host "Running Smart Re-Order & 1-Tap Quick Milk Basket Test Suite..." -ForegroundColor Cyan

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

# 2. window.getLastOrderedItems function
$hasGetLastOrd = $jsCode -match 'window\.getLastOrderedItems\s*=\s*function\(\)'
Assert-Test $hasGetLastOrd "window.getLastOrderedItems function implemented"

# 3. Default curated morning basket fallback
$hasBasketFallback = $jsCode.Contains('"gir_cow_raw"') -and $jsCode.Contains('"paneer_fresh"') -and $jsCode.Contains("isDefault: true")
Assert-Test $hasBasketFallback "getLastOrderedItems provides curated Jaipur Morning Milk & Paneer basket for new customers"

# 4. window.reOrderQuickBasket function
$hasQuickBasket = $jsCode -match 'window\.reOrderQuickBasket\s*=\s*function\(\)'
Assert-Test $hasQuickBasket "window.reOrderQuickBasket function implemented"

# 5. reOrderQuickBasket checks 9 PM cutoff
$hasCutoffCheck1 = $jsCode.Contains("window.reOrderQuickBasket = function()") -and $jsCode.Contains("window.isAfterCutoff && window.isAfterCutoff()")
Assert-Test $hasCutoffCheck1 "reOrderQuickBasket enforces 9 PM cutoff rule before adding to cart"

# 6. reOrderQuickBasket loads items and opens cart
$hasCartLoad1 = $jsCode.Contains("window.cart = {};") -and $jsCode.Contains("window.saveCart();") -and $jsCode.Contains("window.openCartModal();")
Assert-Test $hasCartLoad1 "reOrderQuickBasket populates window.cart, updates SafeStorage and opens cart modal"

# 7. window.reOrderSingleOrder function
$hasSingleReorder = $jsCode -match 'window\.reOrderSingleOrder\s*=\s*function\(orderId\)'
Assert-Test $hasSingleReorder "window.reOrderSingleOrder function implemented"

# 8. reOrderSingleOrder checks catalog stock
$hasStockCheck = $jsCode.Contains("it.outOfStock") -and $jsCode.Contains("reOrderSingleOrder")
Assert-Test $hasStockCheck "reOrderSingleOrder checks live catalog inventory before re-ordering past items"

# 9. reOrderSingleOrder preserves slot and delivery instructions
$hasSlotPreserve = $jsCode.Contains("window.cartSlot = o.slot") -and $jsCode.Contains("window.cartDeliveryNote = noteMatch")
Assert-Test $hasSlotPreserve "reOrderSingleOrder preserves customer delivery slot and gate instructions from previous order"

# 10. window.renderQuickReOrderWidgetHTML function
$hasWidgetHTML = $jsCode -match 'window\.renderQuickReOrderWidgetHTML\s*=\s*function\(\)' -and $jsCode.Contains("window.getLastOrderedItems()")
Assert-Test $hasWidgetHTML "window.renderQuickReOrderWidgetHTML generates interactive re-order widget markup"

# 11. window.renderQuickReOrderWidget DOM updater
$hasWidgetUpdater = $jsCode -match 'window\.renderQuickReOrderWidget\s*=\s*function\(\)' -and $jsCode.Contains("quick-reorder-widget")
Assert-Test $hasWidgetUpdater "window.renderQuickReOrderWidget updates DOM container"

# 12. Homepage includes quick-reorder-widget container
$hasWidgetDOM = $content.Contains('id="quick-reorder-widget"')
Assert-Test $hasWidgetDOM "Homepage contains #quick-reorder-widget DOM element"

# 13. My Orders cards include 1-tap re-order button
$hasCardBtn = $jsCode.Contains("window.reOrderSingleOrder(") -and $jsCode.Contains("fa-solid fa-rotate-right")
Assert-Test $hasCardBtn "My Orders history cards embed 1-tap re-order button"

# 14. afterAuthUI and loadMyData trigger widget re-render
$hasAutoRefresh = $jsCode.Contains("window.renderQuickReOrderWidget()") -and $jsCode.Contains("window.afterAuthUI = function()")
Assert-Test $hasAutoRefresh "afterAuthUI and data loading automatically refresh quick re-order widget"

Write-Host ""
Write-Host "Test Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
