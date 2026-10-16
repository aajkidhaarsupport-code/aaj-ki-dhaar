# Validate index.html script block balance
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$html = [System.IO.File]::ReadAllText("C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\index.html", [System.Text.Encoding]::UTF8)

# Check script open/close tags count
$openTags = ([regex]::Matches($html, "<script", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
$closeTags = ([regex]::Matches($html, "</script>", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
Write-Host "Open script tags: $openTags | Close script tags: $closeTags"

if ($openTags -ne $closeTags) {
    Write-Host "ERROR: Mismatched script tags!" -ForegroundColor Red
    Exit 1
}

# Check main JS script block length and brace balance
$startIdx = $html.IndexOf("<script>")
$endIdx = $html.IndexOf("</script>", $startIdx)
$js = $html.Substring($startIdx + 8, $endIdx - $startIdx - 8)
Write-Host "Main JS block length: $($js.Length) characters"

$openBraces = ([regex]::Matches($js, '\{')).Count
$closeBraces = ([regex]::Matches($js, '\}')).Count
Write-Host "Open braces '{': $openBraces | Close braces '}': $closeBraces"

if ($openBraces -eq $closeBraces) {
    Write-Host "`n>>> SCRIPT SYNTAX INTEGRITY VERIFIED (Braces balanced)! <<<" -ForegroundColor Green
} else {
    Write-Host "ERROR: Brace mismatch in JavaScript!" -ForegroundColor Red
    Exit 1
}
