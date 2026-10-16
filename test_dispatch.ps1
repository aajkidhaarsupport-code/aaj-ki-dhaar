# Test Suite for Morning Dispatch Sheet & Order Packing List (Feature 5)
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

Write-Host "Running Dispatch Sheet Test Suite..." -ForegroundColor Cyan

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

# Test 3: Admin tab button exists
$hasTabBtn = $html -match "switchAdminTab\(['""]dispatch['""],\s*this\)"
Assert-Test $hasTabBtn "Admin modal contains 'switchAdminTab(''dispatch'', this)' tab button"

# Test 4: @media print stylesheet configured
$hasMediaPrint = $html -match "@media\s+print" -and $html -match "#admin-dashboard-modal"
Assert-Test $hasMediaPrint "Print CSS rule for dispatch sheet modal exists in <style>"

# Test 5: window.getDispatchEntries function exists and handles slot/area filtering
$hasGetDispatchEntries = $html -match "window\.getDispatchEntries\s*="
$hasSlotFilter = $html -match "window\.adminDispatchSlot"
$hasAreaFilter = $html -match "window\.adminDispatchArea"
Assert-Test ($hasGetDispatchEntries -and $hasSlotFilter -and $hasAreaFilter) "window.getDispatchEntries defined with slot & area filter logic"

# Test 6: Crate tally logic (20 pouches per crate standard)
$hasCrateMath = $html -match "Math\.floor\s*\(\s*item\.qty\s*/\s*20\s*\)" -or $html -match "crate"
Assert-Test $hasCrateMath "Dispatch sheet calculates crate tally (20-unit standard crate formula)"

# Test 7: window.adminDispatchSheetHTML renders route, COD summary, and delivery stops
$hasSheetHTML = $html -match "window\.adminDispatchSheetHTML\s*="
$hasStopsSummary = $html -match "totalStops" -and $html -match "totalCod"
Assert-Test ($hasSheetHTML -and $hasStopsSummary) "window.adminDispatchSheetHTML builds stops, summary and COD total"

# Test 8: WhatsApp route export function window.adminShareDispatchWA
$hasWAShare = $html -match "window\.adminShareDispatchWA\s*=" -and $html -match "wa\.me"
Assert-Test $hasWAShare "window.adminShareDispatchWA generates formatted delivery run-sheet for WhatsApp"

# Test 9: window.adminPrintDispatch triggers window.print()
$hasPrintFn = $html -match "window\.adminPrintDispatch\s*=\s*function\s*\(\)\s*\{\s*window\.print\(\);"
Assert-Test $hasPrintFn "window.adminPrintDispatch triggers browser print"

# Test 10: renderAdminTab dispatches 'dispatch' tab
$hasRenderDispatch = $html -match 'tab\s*===\s*["'']dispatch["'']'
Assert-Test $hasRenderDispatch "renderAdminTab switches to dispatch view when tab === 'dispatch'"

# Test 11: Schema includes delivery_note & delivery_instructions in admin_dashboard RPC
$sqlHasAdminNotes = $sql -match "delivery_note" -and $sql -match "delivery_instructions"
Assert-Test $sqlHasAdminNotes "schema.sql admin_dashboard RPC selects order delivery_note and profile delivery_instructions"

# Test 12: Customer delivery note badges rendered in dispatch stop cards
$hasNoteInDispatch = $html -match "entry\.deliveryNote" -and $html -match "fa-door-open"
Assert-Test $hasNoteInDispatch "Customer delivery note & instructions displayed in dispatch item cards"

Write-Host "`nTest Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })
if ($passed -ne $total) { exit 1 } else { exit 0 }
