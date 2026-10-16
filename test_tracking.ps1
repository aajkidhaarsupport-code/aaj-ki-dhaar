# Test Suite for Customer Order Tracking & 4-Stage Status Timeline (Feature 6)
$htmlPath = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\index.html"
$sqlPath = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\schema.sql"

$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$sql = [System.IO.File]::ReadAllText($sqlPath, [System.Text.Encoding]::UTF8)

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

Write-Host "Running 4-Stage Order Tracking Test Suite..." -ForegroundColor Cyan

# Test 1: HTML script tags balance
$so = ([regex]::Matches($html, '<script[\s>]')).Count
$sc = ([regex]::Matches($html, '</script>')).Count
Assert-Test ($so -eq $sc -and $so -ge 5) "Script tags balanced (Open=$so, Close=$sc)"

# Test 2: JavaScript brace balance inside <script> blocks
$scriptMatches = [regex]::Matches($html, '(?s)<script.*?>(.*?)</script>')
$jsBracePass = $true
$totalOpen = 0
$totalClose = 0
foreach ($m in $scriptMatches) {
    $body = $m.Groups[1].Value
    if ($body.Trim().Length -gt 0) {
        $bOpen = ([regex]::Matches($body, '\{')).Count
        $bClose = ([regex]::Matches($body, '\}')).Count
        $totalOpen += $bOpen
        $totalClose += $bClose
        if ($bOpen -ne $bClose) {
            $jsBracePass = $false
        }
    }
}
Assert-Test ($jsBracePass -and $totalOpen -gt 500) "JavaScript braces balanced across script blocks (Open=$totalOpen, Close=$totalClose)"

# Test 3: Schema orders out_for_delivery column migration
$sqlHasCol = $sql -match "alter\s+table\s+public\.orders\s+add\s+column\s+if\s+not\s+exists\s+out_for_delivery\s+boolean"
Assert-Test $sqlHasCol "schema.sql contains out_for_delivery column migration on public.orders"

# Test 4: Schema admin_dashboard selects out_for_delivery
$sqlSelectsOut = $sql -match "delivered,\s*delivery_note,\s*out_for_delivery,\s*created_at"
Assert-Test $sqlSelectsOut "schema.sql admin_dashboard RPC selects out_for_delivery"

# Test 5: Schema admin_do actions for out_for_delivery
$sqlHasAdminDoOut = ($sql -match "p_action\s*=\s*'out_for_delivery'") -and ($sql -match "p_action\s*=\s*'un_out_for_delivery'")
Assert-Test $sqlHasAdminDoOut "schema.sql admin_do supports out_for_delivery & un_out_for_delivery actions"

# Test 6: index.html loadMyData selects out_for_delivery
$htmlLoadMyDataOut = $html -match "orders.*select\(.*out_for_delivery.*created_at"
Assert-Test $htmlLoadMyDataOut "index.html loadMyData selects out_for_delivery for client-side tracking"

# Test 7: window.getOrderDeliveryStage function exists and covers 4 stages
$hasGetStage = $html -match "window\.getOrderDeliveryStage\s*="
$hasStage1 = $html -match "stage:\s*1"
$hasStage2 = $html -match "stage:\s*2"
$hasStage3 = $html -match "stage:\s*3"
$hasStage4 = $html -match "stage:\s*4"
Assert-Test ($hasGetStage -and $hasStage1 -and $hasStage2 -and $hasStage3 -and $hasStage4) "window.getOrderDeliveryStage defined with 4-stage progression logic"

# Test 8: 4-stage stepper rendered in orderStepsHTML with grid-cols-4 and 4 steps
$hasStepsHTML = $html -match "window\.orderStepsHTML\s*="
$hasGrid4 = $html -match "grid-cols-4"
$hasStepsPill = $html -match "stgInfo\.desc" -and $html -match "/4</span>"
Assert-Test ($hasStepsHTML -and $hasGrid4 -and $hasStepsPill) "window.orderStepsHTML renders 4-column timeline stepper with live step pill"

# Test 9: Admin helper functions adminMarkOutForDelivery & adminUnOutForDelivery
$hasAdminFns = ($html -match "window\.adminMarkOutForDelivery\s*=") -and ($html -match "window\.adminUnOutForDelivery\s*=")
Assert-Test $hasAdminFns "window.adminMarkOutForDelivery and window.adminUnOutForDelivery defined"

# Test 10: Admin orders tab has 'Out' action button
$hasAdminOrderOutBtn = $html -match "adminMarkOutForDelivery" -and $html -match "\(Out\)"
Assert-Test $hasAdminOrderOutBtn "Admin orders tab has 'Out' button to transition to Stage 3"

# Test 11: Dispatch sheet stop cards have out_for_delivery integration
$hasDispatchOutBtn = $html -match "out_for_delivery" -and $html -match "entry\.out_for_delivery"
Assert-Test $hasDispatchOutBtn "Dispatch sheet stop cards display out_for_delivery status & controls"

# Test 12: Order completion redirects directly to orders tab
$hasRedirectOrders = ($html -match 'openMyOrders\("orders"\)')
Assert-Test $hasRedirectOrders "Cart checkout and quick order placement redirect directly to orders tab"

Write-Host "`nTest Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })
if ($passed -ne $total) { exit 1 } else { exit 0 }
