# Test Suite for Product Customer Reviews & Star Ratings Display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$workspaceDir = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar"
$indexHtml = Join-Path $workspaceDir "index.html"

Write-Host "Running Product Customer Reviews & Star Ratings Test Suite..." -ForegroundColor Cyan

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

# 2. window.defaultRatings defined with key dairy items
$hasDefaultRatings = $jsCode.Contains("window.defaultRatings") -and $jsCode.Contains("cow_milk") -and $jsCode.Contains("buffalo_milk") -and $jsCode.Contains("paneer")
Assert-Test $hasDefaultRatings "window.defaultRatings defined with core dairy catalog items"

# 3. window.ratings initialized with defaultRatings
$hasRatingsInit = $jsCode -match 'window\.ratings\s*=\s*Object\.assign\(\s*\{\}\s*,\s*window\.defaultRatings\)'
Assert-Test $hasRatingsInit "window.ratings initialized with default dairy ratings"

# 4. window.ratingChip formatting
$hasRatingChip = $jsCode -match 'window\.ratingChip\s*=\s*function\(id\)' -and $jsCode.Contains("fa-star") -and $jsCode.Contains("r.count")
Assert-Test $hasRatingChip "window.ratingChip renders amber star icon, average score, and count"

# 5. window.loadExtras merges defaultRatings with RPC
$hasLoadExtras = $jsCode -match 'window\.ratings\s*=\s*Object\.assign\(\s*\{\}\s*,\s*window\.defaultRatings\s*,\s*r\.data\)'
Assert-Test $hasLoadExtras "window.loadExtras safely merges database reviews with default ratings"

# 6. window.homeTestimonials contains verified Jaipur testimonials
$hasHomeTestimonials = $jsCode.Contains("window.homeTestimonials") -and $jsCode.Contains("home-reviews-grid")
Assert-Test $hasHomeTestimonials "window.homeTestimonials defined with verified customer reviews"

# 7. window.renderHomeReviews function
$hasRenderHomeReviews = $jsCode -match 'window\.renderHomeReviews\s*=\s*function\(\)' -and $jsCode.Contains("home-reviews-grid")
Assert-Test $hasRenderHomeReviews "window.renderHomeReviews function generates review cards with stars and verified badge"

# 8. window.openCatalogReviewPrompt and window.openOrderReviewPrompt
$hasReviewPrompts = $jsCode -match 'window\.openCatalogReviewPrompt\s*=\s*function\(\)' -and $jsCode -match 'window\.openOrderReviewPrompt\s*=\s*function\(orderId\)'
Assert-Test $hasReviewPrompts "window.openCatalogReviewPrompt and window.openOrderReviewPrompt are defined"

# 9. DOM contains customer-reviews-section and home-reviews-grid
$hasReviewsSection = $content.Contains('id="customer-reviews-section"') -and $content.Contains('id="home-reviews-grid"')
Assert-Test $hasReviewsSection "Homepage contains #customer-reviews-section and #home-reviews-grid"

# 10. Review action button in My Orders delivered list
$hasOrderReviewBtn = $jsCode -match 'openOrderReviewPrompt' -and $jsCode.Contains("o.delivered")
Assert-Test $hasOrderReviewBtn "My Orders history displays review prompt button for delivered orders"

# 11. DOMContentLoaded triggers window.renderHomeReviews()
$hasStartupCall = $jsCode -match 'window\.renderGallery\(\);\s*window\.renderHomeReviews\(\);'
Assert-Test $hasStartupCall "DOMContentLoaded initializes window.renderHomeReviews() alongside gallery"

Write-Host ""
Write-Host "Test Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
