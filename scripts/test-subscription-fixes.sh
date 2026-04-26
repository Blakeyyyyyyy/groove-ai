#!/bin/bash
# Test 2: iOS code static checks for subscription cancellation fixes

PASS=0
FAIL=0

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "PASS: $desc"
    PASS=$((PASS+1))
  else
    echo "FAIL: $desc"
    FAIL=$((FAIL+1))
  fi
}

BASE="/Users/blakeyyyclaw/.openclaw/workspace/groove-ai"

# Fix 2a: if/else branch — isSubscribed must be set for BOTH true and false
check "isSubscribed = isPremium (not just if true)" \
  "grep -q 'isSubscribed = isPremium' '$BASE/GrooveAI/App/GrooveAIApp.swift'"

# Fix 2b: scenePhase observer
check "scenePhase environment var present" \
  "grep -q 'scenePhase' '$BASE/GrooveAI/App/GrooveAIApp.swift'"

check "onChange scenePhase present" \
  "grep -q 'onChange.*scenePhase' '$BASE/GrooveAI/App/GrooveAIApp.swift'"

# Fix 3: expiry propagation
check "updateSubscriptionExpiry called from RevenueCatService" \
  "grep -q 'updateSubscriptionExpiry' '$BASE/GrooveAI/Services/RevenueCatService.swift'"

check "updateSubscriptionExpiry defined in SupabaseService" \
  "grep -q 'func updateSubscriptionExpiry' '$BASE/GrooveAI/Services/SupabaseService.swift'"

# Webhook
check "revenuecat-webhook/index.ts exists" \
  "test -f '$BASE/supabase/functions/revenuecat-webhook/index.ts'"

check "webhook handles EXPIRATION event" \
  "grep -q 'EXPIRATION' '$BASE/supabase/functions/revenuecat-webhook/index.ts'"

check "webhook handles BILLING_ISSUE" \
  "grep -q 'BILLING_ISSUE' '$BASE/supabase/functions/revenuecat-webhook/index.ts'"

check "webhook handles INITIAL_PURCHASE" \
  "grep -q 'INITIAL_PURCHASE' '$BASE/supabase/functions/revenuecat-webhook/index.ts'"

# Race guard
check "syncWithServer has RC double-check guard" \
  "grep -q 'RevenueCatService.shared.isSubscribed' '$BASE/GrooveAI/Models/AppState.swift'"

# Old bug: if isPremium { isSubscribed = true } should be gone (one-sided assignment)
check "No old one-sided if isPremium = true pattern" \
  "! grep -q 'if isPremium {' '$BASE/GrooveAI/App/GrooveAIApp.swift'"

# Additional checks
check "CANCELLATION handled in webhook" \
  "grep -q 'CANCELLATION' '$BASE/supabase/functions/revenuecat-webhook/index.ts'"

check "RENEWAL handled in webhook" \
  "grep -q 'RENEWAL' '$BASE/supabase/functions/revenuecat-webhook/index.ts'"

check "UNCANCELLATION handled in webhook" \
  "grep -q 'UNCANCELLATION' '$BASE/supabase/functions/revenuecat-webhook/index.ts'"

check "PRODUCT_CHANGE handled in webhook" \
  "grep -q 'PRODUCT_CHANGE' '$BASE/supabase/functions/revenuecat-webhook/index.ts'"

check "Webhook checks Authorization header" \
  "grep -q 'Authorization' '$BASE/supabase/functions/revenuecat-webhook/index.ts'"

check "get-user lazy expiry block present" \
  "grep -q 'subscription_expires_at' '$BASE/supabase/functions/get-user/index.ts'"

check "get-user clears subscription_expires_at on demotion" \
  "grep -q 'subscription_expires_at.*null' '$BASE/supabase/functions/get-user/index.ts'"

check "applyCustomerInfo calls updateSubscriptionExpiry" \
  "grep -q 'updateSubscriptionExpiry' '$BASE/GrooveAI/Services/RevenueCatService.swift'"

check "updateSubscriptionExpiry uses ISO8601 formatter" \
  "grep -q 'supabaseFormatter\|ISO8601' '$BASE/GrooveAI/Services/SupabaseService.swift'"

check "grant_subscription_coins RPC uses p_user_id and p_amount" \
  "grep -q 'p_user_id.*p_amount\|p_amount.*p_user_id' '$BASE/supabase/functions/revenuecat-webhook/index.ts'"

check "Webhook uses SUPABASE_SERVICE_ROLE_KEY (not anon key)" \
  "grep -q 'SUPABASE_SERVICE_ROLE_KEY' '$BASE/supabase/functions/revenuecat-webhook/index.ts'"

check "CANCELLATION does NOT set subscription_status" \
  "! awk '/CANCELLATION/,/EXPIRATION/' '$BASE/supabase/functions/revenuecat-webhook/index.ts' | grep -q 'subscription_status'"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
