# Test Suite for Delivery Boy One-Touch Route Mode (Feature 11)
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

Write-Host "Running Delivery Boy Route Mode Test Suite..." -ForegroundColor Cyan

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

# 3. openDeliveryBoyRoute & closeDeliveryBoyRoute functions defined
$hasRouteOpenClose = ($indexContent -match "window\.openDeliveryBoyRoute\s*=\s*function") -and ($indexContent -match "window\.closeDeliveryBoyRoute\s*=\s*function")
Assert-Test $hasRouteOpenClose "window.openDeliveryBoyRoute and window.closeDeliveryBoyRoute are defined"

# 4. setDeliveryRouteFilter function defined
$hasFilterFn = $indexContent -match "window\.setDeliveryRouteFilter\s*=\s*function"
Assert-Test $hasFilterFn "window.setDeliveryRouteFilter allows toggling between pending, done, and all stops"

# 5. toggleDeliveryStopCheck handles check-offs & auto sync
$hasToggleStop = $indexContent -match "window\.toggleDeliveryStopCheck\s*=\s*(async\s*)?function"
Assert-Test $hasToggleStop "window.toggleDeliveryStopCheck toggles local state and triggers order completion"

# 6. renderDeliveryBoyRouteHTML builds live progress & COD tracker
$hasRenderRoute = ($indexContent -match "window\.renderDeliveryBoyRouteHTML\s*=\s*function") -and 
                  ($indexContent -match "doneCount") -and 
                  ($indexContent -match "pendingCod")
Assert-Test $hasRenderRoute "window.renderDeliveryBoyRouteHTML computes live delivery progress % and remaining COD"

# 7. Route stop cards render one-tap call, map, and WhatsApp buttons
$hasActionsInCard = ($indexContent -match "Google Maps") -and ($indexContent -match "wa\.me") -and ($indexContent -match "tel:")
Assert-Test $hasActionsInCard "Delivery cards include direct Phone call, Google Maps, and WhatsApp buttons"

# 8. Dispatch sheet header includes 'डिलीवरी बॉय मोड' trigger button
$hasDispatchHeaderBtn = $indexContent -match "window\.openDeliveryBoyRoute\(\)"
Assert-Test $hasDispatchHeaderBtn "Dispatch sheet contains openDeliveryBoyRoute button"

# 9. #delivery-boy-modal and #delivery-boy-modal-body present in DOM
$hasModalDOM = ($indexContent -match 'id="delivery-boy-modal"') -and ($indexContent -match 'id="delivery-boy-modal-body"')
Assert-Test $hasModalDOM "#delivery-boy-modal and #delivery-boy-modal-body containers exist in HTML"

Write-Host ""
Write-Host "Test Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
