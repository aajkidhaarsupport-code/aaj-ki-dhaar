# Test Suite for Product Cards and Responsive Layout
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$html = [System.IO.File]::ReadAllText("C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\index.html", [System.Text.Encoding]::UTF8)

$t1 = $html.Contains("window.setCardImg = function(btn, newSrc)")
$t2 = $html.Contains("card-img-dot")
$t3 = $html.Contains("product-main-img")
$t4 = $html.Contains("grid-cols-2 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4")
$t5 = $html.Contains("md:max-w-4xl lg:max-w-6xl xl:max-w-7xl")
$t6 = $html.Contains("h-36 sm:h-44 md:h-48")

Write-Host "Test 1 (window.setCardImg defined): $t1"
Write-Host "Test 2 (Multi-image interactive dots present): $t2"
Write-Host "Test 3 (product-main-img class for dynamic swap): $t3"
Write-Host "Test 4 (Responsive 2/3/4 column catalog grid): $t4"
Write-Host "Test 5 (Responsive container width): $t5"
Write-Host "Test 6 (Responsive product card heights): $t6"

# Verify script syntax integrity
$openBraces = ([regex]::Matches($html, '\{')).Count
$closeBraces = ([regex]::Matches($html, '\}')).Count
$openScript = ([regex]::Matches($html, '<script', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
$closeScript = ([regex]::Matches($html, '</script>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count

$syntaxOk = ($openBraces -eq $closeBraces) -and ($openScript -eq $closeScript)
Write-Host "Test 7 (Script & Brace Syntax Integrity - Braces: $openBraces/$closeBraces, Scripts: $openScript/$closeScript): $syntaxOk"

# Verify schema.sql
$sql = [System.IO.File]::ReadAllText("C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\schema.sql", [System.Text.Encoding]::UTF8)
$s1 = $sql.Contains("imgs jsonb not null default '[]'::jsonb")
$s2 = $sql.Contains("insert into public.catalog(id, cat, name, tag, unit, descr, mrp, price, img, imgs, sort)")
Write-Host "Test 8 (schema.sql has imgs column): $s1"
Write-Host "Test 9 (schema.sql seed insert includes imgs): $s2"

if ($t1 -and $t2 -and $t3 -and $t4 -and $t5 -and $t6 -and $syntaxOk -and $s1 -and $s2) {
    Write-Host "`n>>> ALL 9 PRODUCT CARD & RESPONSIVE UI TESTS PASSED! <<<" -ForegroundColor Green
} else {
    Write-Host "`n>>> SOME TESTS FAILED! <<<" -ForegroundColor Red
    Exit 1
}
