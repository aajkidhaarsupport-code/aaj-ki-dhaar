$tests = @(
    'test_cutoff.ps1',
    'test_cards.ps1',
    'test_cart.ps1',
    'test_delivery_notes.ps1',
    'test_dispatch.ps1',
    'test_tracking.ps1',
    'test_calendar.ps1',
    'test_wallet_alert.ps1',
    'test_receipt.ps1',
    'test_coupons.ps1',
    'test_delivery_boy.ps1',
    'test_analytics.ps1',
    'test_whatsapp_reminder.ps1',
    'test_slot_shifter.ps1',
    'test_reviews.ps1',
    'test_referral.ps1',
    'test_export.ps1',
    'test_pincode.ps1',
    'test_whatsapp_order.ps1',
    'test_vacation.ps1',
    'test_reorder.ps1'
)

$allPassed = $true
$totalPass = 0
$totalTests = 0

foreach ($t in $tests) {
    Write-Host "`n--- Running $t ---" -ForegroundColor Cyan
    $fullPath = Join-Path 'C:\Users\Admin\.gemini\antigravity\scratch' $t
    & powershell -ExecutionPolicy Bypass -File $fullPath
    if ($LASTEXITCODE -ne 0) {
        $allPassed = $false
    }
}

Write-Host "`n=======================================================" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host "SUCCESS: ALL 21 TEST SUITES COMPLETED AND PASSED!" -ForegroundColor Green
} else {
    Write-Host "FAILURE: ONE OR MORE TEST SUITES FAILED!" -ForegroundColor Red
    exit 1
}
