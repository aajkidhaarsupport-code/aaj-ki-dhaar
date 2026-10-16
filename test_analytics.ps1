# Test Suite for Customer Monthly Milk Consumption & Expense Analytics (Feature 12)
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

Write-Host "Running Monthly Milk Analytics Test Suite..." -ForegroundColor Cyan

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

# 3. window.renderMonthlyAnalyticsHTML function defined
$hasAnalyticsFn = $indexContent -match "window\.renderMonthlyAnalyticsHTML\s*=\s*function"
Assert-Test $hasAnalyticsFn "window.renderMonthlyAnalyticsHTML function is defined"

# 4. Milk, Paneer and Ghee aggregation logic present
$hasCategoryGrouping = ($indexContent -match 'milkLiters') -and 
                       ($indexContent -match 'paneerGrams') -and 
                       ($indexContent -match 'gheeGrams')
Assert-Test $hasCategoryGrouping "Analytics logic breaks down milk (liters), paneer (g) and ghee (g)"

# 5. Subscription daily basket projection included in month analytics
$hasSubProjection = ($indexContent -match 'window\.subIsActive\(sub\)') -and ($indexContent -match 'daysCount')
Assert-Test $hasSubProjection "Analytics incorporates subscription recurring milk consumption"

# 6. Bar chart visualization rendering
$hasBarChart = ($indexContent -match 'barsHTML') -and ($indexContent -match 'heightPct')
Assert-Test $hasBarChart "Renders CSS responsive bar chart for monthly expense comparisons"

# 7. My Orders modal tab button for 'मासिक व्यय' (stats tab) exists
$hasStatsTabBtn = $indexContent -match 'data-tab="stats"'
Assert-Test $hasStatsTabBtn "My Orders modal header includes stats tab button"

# 8. Dashboard tab includes direct shortcut button to analytics
$hasDashShortcut = $indexContent -match "switchMyTab\('stats'\)"
Assert-Test $hasDashShortcut "Dashboard summary tab contains direct shortcut to analytics"

# 9. renderMyOrders handles tab === 'stats'
$hasStatsTabHandler = $indexContent -match "tab === ['`"]stats['`"]"
Assert-Test $hasStatsTabHandler "renderMyOrders switches cleanly to stats view"

Write-Host ""
Write-Host "Test Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
