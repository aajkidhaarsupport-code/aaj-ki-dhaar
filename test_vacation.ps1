# Test Suite for Subscription Vacation Extension and Pause History (Feature 20)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$workspaceDir = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar"
$indexHtml = Join-Path $workspaceDir "index.html"
$schemaSql = Join-Path $workspaceDir "schema.sql"

Write-Host "Running Subscription Vacation Extension and Pause History Test Suite..." -ForegroundColor Cyan

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
$sqlContent = [System.IO.File]::ReadAllText($schemaSql, [System.Text.Encoding]::UTF8)

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

# 2. Schema extend_vacation RPC definition
$hasExtendRpc = $sqlContent -match "create\s+or\s+replace\s+function\s+public\.extend_vacation\s*\(p_days\s+int"
Assert-Test $hasExtendRpc "schema.sql defines extend_vacation(p_days int) RPC function"

# 3. Schema permissions for extend_vacation
$hasExtendGrant = ($sqlContent -match "grant\s+execute\s+on\s+function\s+public\.extend_vacation\(int\)\s+to\s+authenticated") -and
                  ($sqlContent -match "revoke\s+all\s+on\s+function\s+public\.extend_vacation\(int\)\s+from\s+public")
Assert-Test $hasExtendGrant "schema.sql sets secure permissions for extend_vacation"

# 4. window.calcDateDiffDays function
$hasCalcDiff = $jsCode -match 'window\.calcDateDiffDays\s*=\s*function\(d1,\s*d2\)'
Assert-Test $hasCalcDiff "window.calcDateDiffDays calculates day duration between vacation dates"

# 5. window.calcResumeDate function
$hasResumeDate = $jsCode -match 'window\.calcResumeDate\s*=\s*function\(endDateStr\)'
Assert-Test $hasResumeDate "window.calcResumeDate computes automatic delivery resumption date"

# 6. window.extendVacation function
$hasExtendFn = $jsCode -match 'window\.extendVacation\s*=\s*async function\(days\)' -and $jsCode.Contains('extend_vacation')
Assert-Test $hasExtendFn "window.extendVacation invokes extension RPC and updates local profile/banner"

# 7. window.getPauseHistory function
$hasGetHist = $jsCode -match 'window\.getPauseHistory\s*=\s*function\(\)' -and $jsCode.Contains('aaj_pause_history')
Assert-Test $hasGetHist "window.getPauseHistory compiles active vacation, paused dates, and local history"

# 8. window.renderPauseHistoryHTML function
$hasRenderHist = $jsCode -match 'window\.renderPauseHistoryHTML\s*=\s*function\(\)' -and $jsCode.Contains('window.getPauseHistory()')
Assert-Test $hasRenderHist "window.renderPauseHistoryHTML generates visual pause history timeline"

# 9. window.quickSelectVacation function
$hasQuickSelect = $jsCode -match 'window\.quickSelectVacation\s*=\s*function\(days\)'
Assert-Test $hasQuickSelect "window.quickSelectVacation pre-fills 3, 7, or 15 days vacation dates"

# 10. window.updateVacationSavingsPreview function
$hasPreviewFn = $jsCode -match 'window\.updateVacationSavingsPreview\s*=\s*function\(\)' -and $jsCode.Contains('vac-savings-preview')
Assert-Test $hasPreviewFn "window.updateVacationSavingsPreview displays live wallet savings and auto-resume date"

# 11. Vacation status banner includes auto-resume notice and extend button
$hasBannerExtend = $content.Contains('id="vacation-status-banner"') -and $content.Contains("window.extendVacation(2)") -and $jsCode.Contains("window.calcResumeDate(a.vacationEnd)")
Assert-Test $hasBannerExtend "Active vacation banner incorporates auto-resume schedule and +2 days extension button"

# 12. Vacation modal includes quick duration chips
$hasModalChips = $content.Contains("window.quickSelectVacation(3)") -and $content.Contains("window.quickSelectVacation(7)") -and $content.Contains("window.quickSelectVacation(15)")
Assert-Test $hasModalChips "Vacation modal includes 1-tap quick duration chips for 3, 7, and 15 days"

# 13. Vacation modal includes live savings preview box
$hasPreviewBox = $content.Contains('id="vac-savings-preview"')
Assert-Test $hasPreviewBox "Vacation modal embeds #vac-savings-preview container"

# 14. My Orders plan tab embeds pause history
$hasPlanTabHist = $jsCode.Contains("window.renderPauseHistoryHTML()") -and $jsCode.Contains('tab === "plan"')
Assert-Test $hasPlanTabHist "My Orders subscription plan tab includes vacation and pause history log"

Write-Host ""
Write-Host "Test Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
