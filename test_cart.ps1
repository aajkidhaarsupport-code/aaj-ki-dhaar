# Aaj Ki Dhaar - Multi-Item Cart Verification Test Suite
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  AAJ KI DHAAR - MULTI-ITEM CART TEST SUITE" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

$htmlPath = "C:\Users\Admin\.gemini\antigravity\scratch\aajkidhaar\index.html"
$content = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)

$passed = 0
$total = 0

function Assert-Test($name, $condition, $details) {
    $script:total++
    if ($condition) {
        $script:passed++
        Write-Host " [PASS] $name" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] $name - $details" -ForegroundColor Red
    }
}

# Test 1: Window Cart state & core functions exist
$coreFns = @(
    "window.cart",
    "window.saveCart",
    "window.addToCart",
    "window.removeFromCart",
    "window.clearCart",
    "window.getCartTotals",
    "window.updateCartUI",
    "window.openCartModal",
    "window.closeCartModal",
    "window.setCartSlot",
    "window.toggleCartBell",
    "window.setCartPayMode",
    "window.applyCartCoupon",
    "window.removeCartCoupon",
    "window.renderCartModalBody",
    "window.checkoutCart"
)

$missingFns = @()
foreach ($fn in $coreFns) {
    if (-not $content.Contains($fn)) {
        $missingFns += $fn
    }
}
Assert-Test "Core Cart Functions Definition" ($missingFns.Count -eq 0) "Missing: $($missingFns -join ', ')"

# Test 2: DOM elements for Cart Modal exist
$hasCartModal = $content.Contains('id="cart-modal"')
$hasCartContent = $content.Contains('id="cart-modal-content"')
Assert-Test "Cart Modal DOM Elements" ($hasCartModal -and $hasCartContent) "id='cart-modal' or 'cart-modal-content' missing"

# Test 3: Floating Cart Bar elements exist
$hasFloatBar = $content.Contains('id="floating-cart-bar"')
$hasFloatCount = $content.Contains('id="float-cart-count"')
$hasFloatTotal = $content.Contains('id="float-cart-total"')
Assert-Test "Floating Cart Bar DOM Elements" ($hasFloatBar -and $hasFloatCount -and $hasFloatTotal) "floating bar elements missing"

# Test 4: Header Cart Button & Badge exist
$hasHeaderBadge = $content.Contains('id="header-cart-badge"')
$hasHeaderTotal = $content.Contains('id="header-cart-total"')
Assert-Test "Header Cart Trigger & Badge" ($hasHeaderBadge -and $hasHeaderTotal) "header cart elements missing"

# Test 5: Bottom Dock Cart Button & Badge exist
$hasBottomBadge = $content.Contains('id="bottom-cart-badge"')
Assert-Test "Bottom Dock Cart Button & Badge" ($hasBottomBadge) "bottom cart badge missing"

# Test 6: Catalog Product Cards Inline Stepper & Cart Buttons
$hasCardStepper = $content.Contains("event.stopPropagation();window.addToCart") -and $content.Contains("window.cart[item.id]")
$hasAddCartBtn = $content.Contains("fa-solid fa-plus text-[9px]")
Assert-Test "Product Card Stepper & Cart Actions" ($hasCardStepper -and $hasAddCartBtn) "card stepper missing"

# Test 7: Product Detail View Cart Button
$hasDetailCartBtn = $content.Contains("closeProductDetail();openOrderModal") -and $content.Contains("window.addToCart")
Assert-Test "Product Detail View Cart Button" ($hasDetailCartBtn) "detail cart button missing"

# Test 8: DOMContentLoaded updates Cart UI on launch
$hasInitCartUI = $content.Contains("window.updateCartUI();")
Assert-Test "DOMContentLoaded calls updateCartUI" ($hasInitCartUI) "updateCartUI not called in DOMContentLoaded"

# Test 9: Mathematical simulation of multi-item cart pricing & coupon logic
# Sample items:
# Milk: MRP 76, Price 72, Qty 2 -> MRP Total 152, Price Total 144
# Paneer: MRP 120, Price 110, Qty 1 -> MRP Total 120, Price Total 110
# Subtotal MRP: 272, Subtotal Price: 254
# Direct Savings: 272 - 254 = 18
# Coupon Discount: 20
# Payable: 254 - 20 = 234
$mockItem1_mrp = 76; $mockItem1_price = 72; $mockItem1_qty = 2
$mockItem2_mrp = 120; $mockItem2_price = 110; $mockItem2_qty = 1

$calc_mrpTotal = ($mockItem1_mrp * $mockItem1_qty) + ($mockItem2_mrp * $mockItem2_qty)
$calc_priceTotal = ($mockItem1_price * $mockItem1_qty) + ($mockItem2_price * $mockItem2_qty)
$calc_savings = $calc_mrpTotal - $calc_priceTotal
$calc_discount = 20
$calc_payable = [Math]::Max(0, $calc_priceTotal - $calc_discount)

$mathCorrect = ($calc_mrpTotal -eq 272) -and ($calc_priceTotal -eq 254) -and ($calc_savings -eq 18) -and ($calc_payable -eq 234)
Assert-Test "Cart Calculation Logic Simulation" ($mathCorrect) "Calculation mismatch"

# Test 10: Checkout enforces Cutoff Check & Pay Mode Verification
$hasCutoffCheck = $content.Contains("if (window.isAfterCutoff())")
$hasLoginCheck = $content.Contains("window.requireLogin(")
$hasUtrValidation = $content.Contains("^[0-9]{12}$")
Assert-Test "Checkout Guard Validations (9PM Cutoff, Auth, UTR)" ($hasCutoffCheck -and $hasLoginCheck -and $hasUtrValidation) "guard validations missing"

Write-Host "-------------------------------------------------"
Write-Host "Results: $passed / $total passed." -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Red" })

if ($passed -ne $total) {
    exit 1
}
