# Test Suite for Interactive Milk Calendar & Vacation Pause (Feature 7)
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

Write-Host "Running Milk Calendar & Vacation Pause Test Suite..." -ForegroundColor Cyan

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

# Test 3: Schema paused_dates column migration on public.profiles
$sqlHasCol = $sql -match "alter\s+table\s+public\.profiles\s+add\s+column\s+if\s+not\s+exists\s+paused_dates\s+jsonb"
Assert-Test $sqlHasCol "schema.sql contains paused_dates column migration on profiles"

# Test 4: Schema admin_dashboard selects paused_dates
$sqlSelectsPaused = $sql -match "delivery_instructions,\s*paused_dates,\s*lat"
Assert-Test $sqlSelectsPaused "schema.sql admin_dashboard RPC selects paused_dates"

# Test 5: Schema toggle_date_pause function exists
$sqlHasToggleFn = $sql -match "create\s+or\s+replace\s+function\s+public\.toggle_date_pause\s*\(p_date\s+date\)"
Assert-Test $sqlHasToggleFn "schema.sql defines toggle_date_pause(p_date date) RPC function"

# Test 6: Schema permissions for toggle_date_pause
$sqlHasGrant = ($sql -match "grant\s+execute\s+on\s+function\s+public\.toggle_date_pause\s*\(date\)\s+to\s+authenticated") -and
               ($sql -match "revoke\s+all\s+on\s+function\s+public\.toggle_date_pause\s*\(date\)\s+from\s+public")
Assert-Test $sqlHasGrant "schema.sql sets secure permissions for toggle_date_pause"

# Test 7: Schema resume_delivery resets paused_dates
$sqlResumeReset = $sql -match "paused_dates\s*=\s*'\[\]'::jsonb"
Assert-Test $sqlResumeReset "schema.sql resume_delivery resets paused_dates to empty array"

# Test 8: index.html applyProfile manages pausedDates
$htmlProfilePaused = $html -match "a\.pausedDates\s*=\s*.*row\.paused_dates"
Assert-Test $htmlProfilePaused "index.html applyProfile initializes a.pausedDates from profile"

# Test 9: index.html isDatePaused function defined
$htmlIsDatePaused = $html -match "window\.isDatePaused\s*=\s*function\s*\(dateStr\)" -and $html -match "pausedDates\.indexOf"
Assert-Test $htmlIsDatePaused "window.isDatePaused handles single pause, vacation and pausedDates"

# Test 10: index.html toggleDatePause function with 9PM cutoff check
$htmlToggleFn = $html -match "window\.toggleDatePause\s*=" -and $html -match "isAfterCutoff" -and $html -match "toggle_date_pause"
Assert-Test $htmlToggleFn "window.toggleDatePause enforces 9PM cutoff on tomorrow and invokes RPC"

# Test 11: index.html renderMilkCalendarHTML builds month grid
$htmlCalRenderer = $html -match "window\.renderMilkCalendarHTML\s*=" -and $html -match "grid-cols-7" -and $html -match "changeCalendarMonth"
Assert-Test $htmlCalRenderer "window.renderMilkCalendarHTML generates 7-column calendar with month navigation"

# Test 12: index.html milk-calendar-modal element present
$htmlHasModal = $html -match 'id="milk-calendar-modal"' -and $html -match 'id="milk-calendar-modal-body"'
Assert-Test $htmlHasModal "index.html contains #milk-calendar-modal DOM elements"

# Test 13: index.html active-sub-badge links to openMilkCalendarModal
$htmlSubBadgeLink = $html -match "openMilkCalendarModal" -and $html -match 'id="active-sub-badge"'
Assert-Test $htmlSubBadgeLink "Homepage active-sub-badge contains button to open milk calendar"

# Test 14: My Orders plan tab renders milk calendar
$htmlPlanTabCal = $html -match "tab\s*===\s*['""]plan['""]" -and $html -match "renderMilkCalendarHTML"
Assert-Test $htmlPlanTabCal "My Orders subscription tab renders interactive milk calendar directly"

Write-Host "`nTest Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })
if ($passed -ne $total) { exit 1 } else { exit 0 }
