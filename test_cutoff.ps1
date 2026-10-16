# UTF-8 clean test script
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$html = [System.IO.File]::ReadAllText("C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\index.html", [System.Text.Encoding]::UTF8)

$t1 = $html.Contains("window.ORDER_CUTOFF_HOUR = 21;")
$t2 = $html.Contains("window.isAfterCutoff = function() { return window.istNow().h >= window.ORDER_CUTOFF_HOUR; };")
$t3 = $html.Contains("window.isOrderClosed = function() { return window.isAfterCutoff(); };")
$t4 = $html.Contains("var cutoffH = window.ORDER_CUTOFF_HOUR || 21;")
$t5 = $html.Contains("cutoff-label")
$t6 = -not $html.Contains("रात 10")

Write-Host "Test 1 (ORDER_CUTOFF_HOUR = 21): $t1"
Write-Host "Test 2 (isAfterCutoff uses cutoff constant): $t2"
Write-Host "Test 3 (isOrderClosed delegates to isAfterCutoff): $t3"
Write-Host "Test 4 (Timer uses cutoffH): $t4"
Write-Host "Test 5 (cutoff-label present): $t5"
Write-Host "Test 6 (Zero remaining 10 PM strings in index.html): $t6"

$sql = [System.IO.File]::ReadAllText("C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\schema.sql", [System.Text.Encoding]::UTF8)
$s1 = $sql.Contains("at time zone 'Asia/Kolkata')) >= 21")
$s2 = -not $sql.Contains("at time zone 'Asia/Kolkata')) >= 22")

Write-Host "Test 7 (schema.sql has 21 cutoff checks): $s1"
Write-Host "Test 8 (schema.sql has no remaining 22 cutoff checks): $s2"

if ($t1 -and $t2 -and $t3 -and $t4 -and $t5 -and $t6 -and $s1 -and $s2) {
    Write-Host "`n>>> ALL CUTOFF VERIFICATION TESTS PASSED SUCCESSFULLY! <<<" -ForegroundColor Green
} else {
    Write-Host "`n>>> SOME TESTS FAILED! <<<" -ForegroundColor Red
    Exit 1
}
