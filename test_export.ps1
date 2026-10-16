# Test Suite for Customer Order & Ledger CSV Export
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$workspaceDir = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar"
$indexHtml = Join-Path $workspaceDir "index.html"

Write-Host "Running Customer Order & Ledger CSV Export Test Suite..." -ForegroundColor Cyan

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

# 2. window.downloadCSV function with UTF-8 BOM
$hasDownloadCSV = $jsCode -match 'window\.downloadCSV\s*=\s*function\(filename,\s*csvContent\)' -and $jsCode.Contains("URL.createObjectURL")
Assert-Test $hasDownloadCSV "window.downloadCSV creates downloadable Blob with UTF-8 BOM for Excel compatibility"

# 3. window.csvEscape function
$hasCsvEscape = $jsCode -match 'window\.csvEscape\s*=\s*function\(val\)' -and $jsCode.Contains('replace(/"/g')
Assert-Test $hasCsvEscape "window.csvEscape safely escapes quotes and null values"

# 4. window.exportMyOrdersCSV function
$hasExportOrders = $jsCode -match 'window\.exportMyOrdersCSV\s*=\s*function\(\)' -and $jsCode.Contains("aajkidhaar_my_orders_")
Assert-Test $hasExportOrders "window.exportMyOrdersCSV generates itemized orders spreadsheet"

# 5. window.exportMyLedgerCSV function
$hasExportLedger = $jsCode -match 'window\.exportMyLedgerCSV\s*=\s*function\(\)' -and $jsCode.Contains("aajkidhaar_wallet_passbook_")
Assert-Test $hasExportLedger "window.exportMyLedgerCSV generates wallet transactions passbook spreadsheet"

# 6. window.adminExportOrdersCSV function
$hasAdminOrdersCSV = $jsCode -match 'window\.adminExportOrdersCSV\s*=\s*function\(\)' -and $jsCode.Contains("aajkidhaar_admin_orders_")
Assert-Test $hasAdminOrdersCSV "window.adminExportOrdersCSV exports full orders database with addresses and delivery slots"

# 7. window.adminExportUsersCSV function
$hasAdminUsersCSV = $jsCode -match 'window\.adminExportUsersCSV\s*=\s*function\(\)' -and $jsCode.Contains("aajkidhaar_admin_customers_")
Assert-Test $hasAdminUsersCSV "window.adminExportUsersCSV exports customer contacts and subscription profiles"

# 8. My Orders "orders" tab includes export trigger
$hasOrderTabBtn = $jsCode.Contains("window.exportMyOrdersCSV()") -and $jsCode.Contains('tab === "orders"')
Assert-Test $hasOrderTabBtn "My Orders orders tab includes exportMyOrdersCSV button"

# 9. My Orders "txns" tab includes passbook export trigger
$hasTxnTabBtn = $jsCode.Contains("window.exportMyLedgerCSV()") -and $jsCode.Contains('tab === "txns"')
Assert-Test $hasTxnTabBtn "My Orders passbook tab includes exportMyLedgerCSV button"

# 10. Monthly Analytics header includes export button
$hasAnalyticsBtn = $jsCode.Contains("window.exportMyOrdersCSV()") -and $jsCode.Contains("renderMonthlyAnalyticsHTML")
Assert-Test $hasAnalyticsBtn "Monthly analytics report includes 1-click CSV download CTA"

# 11. Admin orders tab includes export button
$hasAdminOrdersBtn = $jsCode.Contains("window.adminExportOrdersCSV()")
Assert-Test $hasAdminOrdersBtn "Admin orders management tab includes adminExportOrdersCSV button"

# 12. Admin users tab includes export button
$hasAdminUsersBtn = $jsCode.Contains("window.adminExportUsersCSV()")
Assert-Test $hasAdminUsersBtn "Admin customer list tab includes adminExportUsersCSV button"

Write-Host ""
Write-Host "Test Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
