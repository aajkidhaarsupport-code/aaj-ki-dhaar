# Test Suite for Refer & Earn (â‚¹50 Wallet Credit) Program
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$workspaceDir = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar"
$indexHtml = Join-Path $workspaceDir "index.html"
$schemaSql = Join-Path $workspaceDir "schema.sql"

Write-Host "Running Refer & Earn Test Suite..." -ForegroundColor Cyan

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
$schema = [System.IO.File]::ReadAllText($schemaSql, [System.Text.Encoding]::UTF8)

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

# 2. Schema referral columns and indexes
$hasSchemaCols = $schema.Contains("ref_code text") -and $schema.Contains("referred_by uuid") -and $schema.Contains("ref_paid boolean")
Assert-Test $hasSchemaCols "schema.sql contains ref_code, referred_by, and ref_paid columns on profiles"

# 3. Schema referral bonus disbursement on order delivered
$hasSchemaBonus = $schema.Contains("p_action = 'delivered'") -and $schema.Contains("ref_bonus") -and $schema.Contains("p.referred_by is not null and not p.ref_paid")
Assert-Test $hasSchemaBonus "schema.sql disburses referral bonus to both users on first order delivery"

# 4. window.copyRefCode and window.copyRefLink defined
$hasCopyHelpers = $jsCode -match 'window\.copyRefCode\s*=\s*function\(code\)' -and $jsCode -match 'window\.copyRefLink\s*=\s*function\(\)'
Assert-Test $hasCopyHelpers "window.copyRefCode and window.copyRefLink functions are defined"

# 5. window.shareRef function creates rich WhatsApp share link
$hasShareRef = $jsCode -match 'window\.shareRef\s*=\s*function\(\)' -and $jsCode.Contains("wa.me/?text=")
Assert-Test $hasShareRef "window.shareRef generates one-click WhatsApp invite with refer code"

# 6. window.openReferEarn defined and redirects to refer tab
$hasOpenRefer = $jsCode -match 'window\.openReferEarn\s*=\s*function\(\)' -and $jsCode.Contains('openMyOrders("refer")')
Assert-Test $hasOpenRefer "window.openReferEarn navigates user straight to refer tab"

# 7. window.renderReferEarnHTML defined with hero card, stats, steps, history
$hasRenderReferEarn = $jsCode -match 'window\.renderReferEarnHTML\s*=\s*function\(\)' -and $jsCode.Contains("totalRefEarned") -and $jsCode.Contains("refCount")
Assert-Test $hasRenderReferEarn "window.renderReferEarnHTML renders referral stats, code box, and history"

# 8. renderMyOrders tab handling includes 'refer'
$hasReferTabHandling = $jsCode -match 'tab\s*===\s*"refer"' -and $jsCode.Contains("renderReferEarnHTML")
Assert-Test $hasReferTabHandling "renderMyOrders switches cleanly to refer tab view"

# 9. my-orders-modal includes data-tab="refer" button
$hasReferTabButton = $content.Contains('data-tab="refer"') -and $content.Contains("switchMyTab('refer')")
Assert-Test $hasReferTabButton "my-orders-modal tabs header includes refer button"

# 10. Homepage contains #home-refer-banner
$hasHomeReferBanner = $content.Contains('id="home-refer-banner"') -and $content.Contains("window.openReferEarn()")
Assert-Test $hasHomeReferBanner "Homepage displays #home-refer-banner with 1-click CTA"

# 11. URL query ref parameter auto-capture and welcome toast
$hasUrlRefHandling = $jsCode.Contains("new URLSearchParams(location.search).get(`"ref`")") -and $jsCode.Contains("aaj_ref")
Assert-Test $hasUrlRefHandling "URL query ref parameter is stored and prefilled on signup"

# 12. Product detail modal refer CTA points to openReferEarn
$hasPdReferCta = $jsCode.Contains("closeProductDetail();window.openReferEarn()")
Assert-Test $hasPdReferCta "Product detail modal refer banner connects to openReferEarn"

Write-Host ""
Write-Host "Test Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
