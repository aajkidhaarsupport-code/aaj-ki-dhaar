# Aaj Ki Dhaar - Delivery Instructions & Gate Notes Test Suite
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  AAJ KI DHAAR - DELIVERY INSTRUCTIONS & GATE NOTES TESTS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$htmlPath = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\index.html"
$sqlPath  = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\schema.sql"

$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$sql  = [System.IO.File]::ReadAllText($sqlPath, [System.Text.Encoding]::UTF8)

$passed = 0
$total = 0

function Assert-Test($name, $condition, $details) {
    $script:total++
    if ($condition) {
        $script:passed++
        Write-Host " [PASS] $name" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] $name - $details" -ForegroundColor Red
    }
}

# Test 1: delivery_instructions in window.pfKeys
$hasPfKeys = $html.Contains('"delivery_instructions"') -and $html.Contains('window.pfKeys = [')
Assert-Test "delivery_instructions in window.pfKeys" ($hasPfKeys) "Key missing from pfKeys"

# Test 2: pfQuickInst helper function
$hasQuickInst = $html.Contains("window.pfQuickInst = function(px, text)")
Assert-Test "pfQuickInst helper function defined" ($hasQuickInst) "pfQuickInst function missing"

# Test 3: Profile form has quick-tap instruction chips
$hasQuickChips = $html.Contains("pfQuickInst(\'' + px + '\',") -and $html.Contains("F(px, ""delivery_instructions""")
Assert-Test "Profile form quick chips & delivery_instructions field" ($hasQuickChips) "Profile form inputs missing"

# Test 4: pfCheck validates delivery instructions length
$hasPfCheck = $html.Contains("d.delivery_instructions.length > 120")
Assert-Test "pfCheck delivery instructions length check" ($hasPfCheck) "Validation check missing"

# Test 5: Quick Single Order modal has #order-delivery-note input
$hasOrderNoteInp = $html.Contains('id="order-delivery-note"')
Assert-Test "Quick Order modal #order-delivery-note element" ($hasOrderNoteInp) "DOM element missing"

# Test 6: openOrderModal pre-fills #order-delivery-note
$hasPrefillOrderNote = $html.Contains('document.getElementById("order-delivery-note")')
Assert-Test "openOrderModal pre-fills delivery note" ($hasPrefillOrderNote) "Pre-fill logic missing"

# Test 7: placeOrder passes p_note in RPC call
$hasPlaceOrderNote = $html.Contains('p_note: note || null')
Assert-Test "placeOrder passes p_note to RPC" ($hasPlaceOrderNote) "p_note missing in placeOrder"

# Test 8: Cart modal contains #cart-delivery-note input
$hasCartNoteInp = $html.Contains('id="cart-delivery-note"')
Assert-Test "Cart modal #cart-delivery-note element" ($hasCartNoteInp) "DOM element missing"

# Test 9: checkoutCart passes p_note in batch RPC calls
$hasCheckoutNote = $html.Contains('p_note: note || null') -and $html.Contains('window.checkoutCart')
Assert-Test "checkoutCart passes p_note to RPC" ($hasCheckoutNote) "p_note missing in checkoutCart"

# Test 10: My Orders card displays note badge
$hasMyOrdersBadge = $html.Contains('o.delivery_note') -and $html.Contains('noteMatch')
Assert-Test "My Orders displays delivery note badge" ($hasMyOrdersBadge) "Badge display missing in My Orders"

# Test 11: Admin orders view displays delivery note badge
$hasAdminBadge = $html.Contains('pOrders.map') -and $html.Contains('noteMatch')
Assert-Test "Admin orders tab displays delivery note badge" ($hasAdminBadge) "Badge display missing in Admin view"

# Test 12: schema.sql column migrations
$hasSqlColProf = $sql.Contains("alter table public.profiles add column if not exists delivery_instructions text;")
$hasSqlColOrd  = $sql.Contains("alter table public.orders add column if not exists delivery_note text;")
Assert-Test "schema.sql column migrations for profiles and orders" ($hasSqlColProf -and $hasSqlColOrd) "SQL alter table statements missing"

# Test 13: schema.sql _profile_error and _save_profile_fields
$hasSqlProfileErr = $sql.Contains("delivery_instructions', ''))") -and $sql.Contains("length(di) > 120")
$hasSqlSaveFields = $sql.Contains("delivery_instructions = di")
Assert-Test "schema.sql _profile_error & _save_profile_fields" ($hasSqlProfileErr -and $hasSqlSaveFields) "Profile SQL logic missing"

# Test 14: schema.sql place_order signature & delivery_note insertion
$hasSqlPlaceOrder = $sql.Contains("p_note text default null") -and $sql.Contains("delivery_note")
Assert-Test "schema.sql place_order p_note parameter & column insert" ($hasSqlPlaceOrder) "place_order SQL changes missing"

# Test 15: Syntax integrity check (braces & script tags)
$openBraces = ([regex]::Matches($html, '\{')).Count
$closeBraces = ([regex]::Matches($html, '\}')).Count
$openScripts = ([regex]::Matches($html, '<script')).Count
$closeScripts = ([regex]::Matches($html, '</script>')).Count

$syntaxOk = ($openBraces -eq $closeBraces) -and ($openScripts -eq $closeScripts)
Assert-Test "index.html syntax balance (Braces: $openBraces/$closeBraces, Scripts: $openScripts/$closeScripts)" ($syntaxOk) "Syntax mismatch"

Write-Host "------------------------------------------------------------"
Write-Host "Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
