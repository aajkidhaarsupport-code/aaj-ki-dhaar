# Test Suite for Jaipur Pincode and Route Availability Checker
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$workspaceDir = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar"
$indexHtml = Join-Path $workspaceDir "index.html"

Write-Host "Running Jaipur Pincode and Route Availability Checker Test Suite..." -ForegroundColor Cyan

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

# 2. window.jaipurPincodeDirectory defined with major Jaipur hubs
$hasDir = $jsCode -match 'window\.jaipurPincodeDirectory\s*='
$hasHubs = $jsCode.Contains('"302001"') -and $jsCode.Contains('"302012"') -and $jsCode.Contains('"302017"') -and $jsCode.Contains('"302018"') -and $jsCode.Contains('"302021"') -and $jsCode.Contains('"302034"')
Assert-Test ($hasDir -and $hasHubs) "window.jaipurPincodeDirectory contains Vaishali Nagar, Mansarovar, Malviya Nagar, Sirsi Road, Jagatpura, C-Scheme"

# 3. window.checkPincodeService function
$hasCheckFunc = $jsCode -match 'window\.checkPincodeService\s*=\s*function\(pin\)'
Assert-Test $hasCheckFunc "window.checkPincodeService function implemented"

# 4. Range check for 302001 - 302039 in checkPincodeService
$hasRangeCheck = $jsCode.Contains("302001") -and $jsCode.Contains("302039") -and $jsCode.Contains("num >= 302001 && num <= 302039")
Assert-Test $hasRangeCheck "checkPincodeService verifies Jaipur municipal delivery range (302001 to 302039)"

# 5. window.runPincodeCheck function
$hasRunCheck = $jsCode -match 'window\.runPincodeCheck\s*=\s*function\(inputId,\s*resultBoxId\)'
Assert-Test $hasRunCheck "window.runPincodeCheck function updates DOM and stores verified pin in SafeStorage"

# 6. window.quickCheckPin 1-tap chip selector
$hasQuickCheck = $jsCode -match 'window\.quickCheckPin\s*=\s*function\(pin\)'
Assert-Test $hasQuickCheck "window.quickCheckPin function enables 1-tap verification for popular Jaipur areas"

# 7. Homepage checker widget element
$hasWidget = $content.Contains('id="pincode-checker-widget"')
Assert-Test $hasWidget "Homepage includes pincode-checker-widget"

# 8. Pincode input element and button
$hasInput = $content.Contains('id="pincode-input"') -and $content.Contains("runPincodeCheck('pincode-input','pincode-result-box')")
Assert-Test $hasInput "pincode-input and verify button properly wired to runPincodeCheck"

# 9. Pincode result box container
$hasResultBox = $content.Contains('id="pincode-result-box"')
Assert-Test $hasResultBox "pincode-result-box container present on homepage"

# 10. Quick check chips for prominent Jaipur localities
$hasChips = $content.Contains("quickCheckPin('302021')") -and $content.Contains("quickCheckPin('302018')") -and $content.Contains("quickCheckPin('302017')") -and $content.Contains("quickCheckPin('302012')") -and $content.Contains("quickCheckPin('302034')")
Assert-Test $hasChips "Pincode checker widget provides chips for Vaishali Nagar, Mansarovar, Malviya Nagar, Sirsi Rd and Jagatpura"

# 11. Quick order modal pincode badge
$hasOrderBadge = $content.Contains('id="order-pincode-badge"') -and $jsCode.Contains("order-pincode-badge") -and $jsCode.Contains("window.checkPincodeService(userPin)")
Assert-Test $hasOrderBadge "Quick Order modal displays live Jaipur delivery route badge with estimated morning delivery window"

# 12. Cart modal route verification badge
$hasCartBadge = $jsCode.Contains("routeBadgeHTML") -and $jsCode.Contains("pinCheck.available ?") -and $jsCode.Contains("pinCheck.estTime")
Assert-Test $hasCartBadge "Shopping Cart modal embeds routeBadgeHTML showing delivery availability before checkout"

# 13. Address profile autofill integration
$hasPfPin = $jsCode -match 'window\.pfPin\s*=\s*async function\(px\)' -and $jsCode.Contains("window.checkPincodeService(pin)")
Assert-Test $hasPfPin "Customer address profile autofill integrates route availability notification"

# 14. Auto-check on DOMContentLoaded from user profile
$hasAutoCheck = $jsCode.Contains("pInp.value = savedPin;") -and $jsCode.Contains('window.runPincodeCheck("pincode-input", "pincode-result-box");')
Assert-Test $hasAutoCheck "DOMContentLoaded automatically restores and checks customer saved pincode"

Write-Host ""
Write-Host "Test Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
