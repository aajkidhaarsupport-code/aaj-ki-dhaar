# Test Suite for Delivery Slot Shift / Morning to Evening Switcher (Feature 14)
$ErrorActionPreference = "Stop"

$indexPath = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\index.html"
$sqlPath = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\schema.sql"

$indexContent = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
$sqlContent = [System.IO.File]::ReadAllText($sqlPath, [System.Text.Encoding]::UTF8)

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

Write-Host "Running Delivery Slot Shifter Test Suite..." -ForegroundColor Cyan

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

# 3. Schema default_slot and slot_shifts columns
$hasCol1 = $sqlContent -match "alter\s+table\s+public\.profiles\s+add\s+column\s+if\s+not\s+exists\s+default_slot\s+text"
$hasCol2 = $sqlContent -match "alter\s+table\s+public\.profiles\s+add\s+column\s+if\s+not\s+exists\s+slot_shifts\s+jsonb"
Assert-Test ($hasCol1 -and $hasCol2) "schema.sql contains default_slot and slot_shifts column migrations on profiles"

# 4. Schema shift_delivery_slot RPC function
$hasShiftFn = $sqlContent -match "create\s+or\s+replace\s+function\s+public\.shift_delivery_slot"
Assert-Test $hasShiftFn "schema.sql defines shift_delivery_slot RPC function"

# 5. Schema shift_delivery_slot permissions
$hasGrant = $sqlContent -match "grant\s+execute\s+on\s+function\s+public\.shift_delivery_slot"
Assert-Test $hasGrant "schema.sql grants execute on shift_delivery_slot"

# 6. Schema 9 PM cutoff check on tomorrow
$hasSqlCutoff = $sqlContent -match "p_date\s*=\s*tmr\s*and\s*is_cut"
Assert-Test $hasSqlCutoff "schema.sql enforces 9 PM cutoff for next-day delivery slot changes"

# 7. Schema place_order supports evening slot
$hasPlaceOrderEvening = $sqlContent -match "p_slot\s+in\s*\('5:30 AM - 7:00 AM',\s*'7:00 AM - 8:30 AM',\s*'5:00 PM - 7:30 PM'\)"
Assert-Test $hasPlaceOrderEvening "schema.sql place_order validates evening slot 5:00 PM - 7:30 PM"

# 8. applyProfile loads defaultSlot and slotShifts
$hasApplyProfileSlot = $indexContent -match "a\.defaultSlot\s*=" -and $indexContent -match "a\.slotShifts\s*="
Assert-Test $hasApplyProfileSlot "index.html applyProfile initializes defaultSlot and slotShifts"

# 9. Core slot shifter functions defined in index.html
$hasOpenModal = $indexContent -match "window\.openSlotShiftModal\s*=\s*function"
$hasCloseModal = $indexContent -match "window\.closeSlotShiftModal\s*=\s*function"
$hasGetShifted = $indexContent -match "window\.getShiftedSlotForDate\s*=\s*function"
$hasConfirmShift = $indexContent -match "window\.confirmSlotShift\s*=\s*async\s*function"
Assert-Test ($hasOpenModal -and $hasCloseModal -and $hasGetShifted -and $hasConfirmShift) "Core slot shifter functions defined in index.html"

# 10. Client 9 PM cutoff check
$hasClientCutoff = $indexContent -match "dateVal\s*===\s*tomorrow\s*&&" -and $indexContent -match "isAfterCutoff\(\)"
Assert-Test $hasClientCutoff "window.confirmSlotShift enforces 9 PM cutoff on client before RPC"

# 11. Modal markup exists in DOM
$hasModalDOM = $indexContent -match 'id="slot-shift-modal"' -and $indexContent -match 'id="slot-shift-modal-body"'
Assert-Test $hasModalDOM "#slot-shift-modal and #slot-shift-modal-body containers exist in DOM"

# 12. Homepage slot selector contains 3 slots and shifter link
$hasHomeSlots = $indexContent -match 'data-slot="5:00 PM - 7:30 PM"' -and $indexContent -match 'openSlotShiftModal\(\)'
Assert-Test $hasHomeSlots "Homepage slot selector includes evening slot and openSlotShiftModal trigger"

# 13. Dispatch sheet resolves shifted slot for subscriptions
$hasDispatchShift = $indexContent -match "u\.slot_shifts\[window\.todayISO\(\)\]"
Assert-Test $hasDispatchShift "getDispatchEntries resolves temporary shifted slot for subscriptions"

$resColor = if ($passed -eq $total) { "Green" } else { "Red" }
Write-Host "`nTest Results: $passed / $total passed." -ForegroundColor $resColor

if ($passed -ne $total) {
    exit 1
}
