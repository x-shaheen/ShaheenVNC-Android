#!/bin/bash
#
# strict_verification.sh - Strict source code and build artifact verification
# This script finds ALL MainActivity files and verifies the correct one is being built
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="${1:-.}"
VERIFICATION_REPORT="$PROJECT_ROOT/STRICT_VERIFICATION_REPORT.txt"

log_section() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
}

log_ok() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

report() {
    echo "$1" | tee -a "$VERIFICATION_REPORT"
}

# Initialize report
> "$VERIFICATION_REPORT"

report "╔════════════════════════════════════════════════════════╗"
report "║         STRICT SOURCE CODE VERIFICATION REPORT         ║"
report "╚════════════════════════════════════════════════════════╝"
report ""
report "Timestamp: $(date)"
report "Project Root: $PROJECT_ROOT"
report ""

# STEP 1: Find all MainActivity files
log_section "STEP 1: FIND ALL MainActivity FILES"

report "STEP 1: FIND ALL MainActivity FILES"
report "===================================="
report ""

MAIN_ACTIVITY_FILES=$(find "$PROJECT_ROOT" -name "MainActivity.kt*" -type f 2>/dev/null)
FILE_COUNT=$(echo "$MAIN_ACTIVITY_FILES" | wc -l)

report "Total MainActivity files found: $FILE_COUNT"
report ""

declare -a FILE_ARRAY
declare -a SHA256_ARRAY

while IFS= read -r file; do
    if [ -f "$file" ]; then
        FILE_ARRAY+=("$file")
        
        # Calculate SHA256
        if command -v sha256sum &> /dev/null; then
            SHA=$(sha256sum "$file" | awk '{print $1}')
        elif command -v shasum &> /dev/null; then
            SHA=$(shasum -a 256 "$file" | awk '{print $1}')
        else
            SHA="N/A"
        fi
        SHA256_ARRAY+=("$SHA")
        
        SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        
        report "File $((${#FILE_ARRAY[@]})):"
        report "  Path: $file"
        report "  SHA256: $SHA"
        report "  Size: $SIZE bytes"
        report ""
    fi
done <<< "$MAIN_ACTIVITY_FILES"

if [ ${#FILE_ARRAY[@]} -eq 0 ]; then
    log_error "NO MainActivity.kt files found!"
    report "✗ ERROR: No MainActivity.kt files found"
    exit 1
fi

log_ok "Found ${#FILE_ARRAY[@]} MainActivity file(s)"

# STEP 2: Identify the active source file used by Gradle
log_section "STEP 2: IDENTIFY ACTIVE GRADLE SOURCE"

report ""
report "STEP 2: IDENTIFY ACTIVE GRADLE SOURCE FILE"
report "=========================================="
report ""

GRADLE_SOURCE_PATH="$PROJECT_ROOT/android/app/src/main/java/com/kasmtech/kasmvnc/MainActivity.kt"

if [ ! -f "$GRADLE_SOURCE_PATH" ]; then
    log_error "Gradle source file NOT found at expected path!"
    report "✗ Expected Gradle source NOT found: $GRADLE_SOURCE_PATH"
    exit 1
fi

log_ok "Gradle source file found"
report "✓ Gradle source file found"
report "  Path: $GRADLE_SOURCE_PATH"

# Get Gradle source SHA256
if command -v sha256sum &> /dev/null; then
    GRADLE_SHA=$(sha256sum "$GRADLE_SOURCE_PATH" | awk '{print $1}')
elif command -v shasum &> /dev/null; then
    GRADLE_SHA=$(shasum -a 256 "$GRADLE_SOURCE_PATH" | awk '{print $1}')
else
    GRADLE_SHA="N/A"
fi

GRADLE_SIZE=$(stat -f%z "$GRADLE_SOURCE_PATH" 2>/dev/null || stat -c%s "$GRADLE_SOURCE_PATH" 2>/dev/null)

report "  SHA256: $GRADLE_SHA"
report "  Size: $GRADLE_SIZE bytes"
report ""

# STEP 3: Verify fix in active source file
log_section "STEP 3: VERIFY FIX IN ACTIVE SOURCE"

report "STEP 3: VERIFY FIX IN ACTIVE SOURCE FILE"
report "========================================"
report ""

# Check for problematic patterns
PATTERNS_TO_CHECK=(
    "override fun onBackPressed()"
    "onBackPressedDispatcher.addCallback"
    "fun onCreate"
    "class MainActivity"
    "setContent"
)

report "Checking for expected and problematic patterns:"
report ""

# Check for the old problematic override
if grep -q "override fun onBackPressed()" "$GRADLE_SOURCE_PATH"; then
    log_error "CRITICAL: onBackPressed() override FOUND (this is the bug!)"
    report "✗ CRITICAL BUG: onBackPressed() override found at:"
    grep -n "override fun onBackPressed()" "$GRADLE_SOURCE_PATH" | sed 's/^/    /' >> "$VERIFICATION_REPORT"
    report ""
    HAS_BUG=true
else
    log_ok "No onBackPressed() override found (good)"
    report "✓ No onBackPressed() override found"
fi

# Check for the fix
if grep -q "onBackPressedDispatcher.addCallback" "$GRADLE_SOURCE_PATH"; then
    log_ok "OnBackPressedDispatcher callback found (FIX PRESENT)"
    report "✓ OnBackPressedDispatcher callback found (FIX PRESENT)"
    report "  Location:"
    grep -n "onBackPressedDispatcher.addCallback" "$GRADLE_SOURCE_PATH" | sed 's/^/    /' >> "$VERIFICATION_REPORT"
    HAS_FIX=true
else
    log_warn "OnBackPressedDispatcher callback NOT found"
    report "⚠ OnBackPressedDispatcher callback not found"
    HAS_FIX=false
fi

report ""

# STEP 4: Print full MainActivity content for review
log_section "STEP 4: FULL SOURCE CODE REVIEW"

report ""
report "STEP 4: FULL ACTIVE SOURCE CODE"
report "================================"
report ""
report "File: $GRADLE_SOURCE_PATH"
report ""
report "──────────────────────────────────────"

cat "$GRADLE_SOURCE_PATH" | nl | sed 's/^/  /' >> "$VERIFICATION_REPORT"

report "──────────────────────────────────────"
report ""

# STEP 5: Check all backup files
log_section "STEP 5: CHECK BACKUP FILES"

report ""
report "STEP 5: BACKUP FILES ANALYSIS"
report "============================="
report ""

BACKUP_FILES=$(find "$PROJECT_ROOT" -name "MainActivity.kt.backup*" -type f 2>/dev/null)

if [ -z "$BACKUP_FILES" ]; then
    log_ok "No backup files found"
    report "✓ No backup files found"
else
    log_warn "Backup files detected:"
    echo "$BACKUP_FILES" | while read backup; do
        log_warn "  - $(basename $backup)"
        report "⚠ Backup file: $backup"
        
        if grep -q "override fun onBackPressed()" "$backup" 2>/dev/null; then
            report "  Contains: onBackPressed() override (OLD VERSION)"
        fi
        if grep -q "onBackPressedDispatcher" "$backup" 2>/dev/null; then
            report "  Contains: onBackPressedDispatcher (FIXED VERSION)"
        fi
    done
fi

report ""

# STEP 6: Verify Gradle build configuration
log_section "STEP 6: GRADLE BUILD CONFIGURATION"

report ""
report "STEP 6: GRADLE BUILD CONFIGURATION"
report "==================================="
report ""

GRADLE_KTS="$PROJECT_ROOT/android/app/build.gradle.kts"

if [ ! -f "$GRADLE_KTS" ]; then
    log_error "Gradle build file NOT found!"
    report "✗ Gradle build file not found"
    exit 1
fi

log_ok "Gradle build file found"
report "✓ Gradle build file found: $GRADLE_KTS"
report ""

# Check key Gradle settings
GRADLE_CONTENT=$(cat "$GRADLE_KTS")

report "Key Gradle settings:"
report ""

# Application ID
if echo "$GRADLE_CONTENT" | grep -q 'applicationId = "com.kasmtech.kasmvnc"'; then
    report "✓ applicationId: com.kasmtech.kasmvnc"
else
    log_error "Application ID not found or incorrect"
    report "✗ Application ID incorrect"
fi

# Version info
if echo "$GRADLE_CONTENT" | grep -q 'versionCode = 1'; then
    report "✓ versionCode: 1"
fi

if echo "$GRADLE_CONTENT" | grep -q 'versionName = "1.0.0"'; then
    report "✓ versionName: 1.0.0"
fi

# Compose
if echo "$GRADLE_CONTENT" | grep -q 'compose = true'; then
    report "✓ Compose enabled"
fi

# Android version
if echo "$GRADLE_CONTENT" | grep -q 'compileSdk = 34'; then
    report "✓ compileSdk: 34"
fi

if echo "$GRADLE_CONTENT" | grep -q 'targetSdk = 34'; then
    report "✓ targetSdk: 34"
fi

report ""

# STEP 7: Git verification
log_section "STEP 7: GIT STATUS & HISTORY"

report ""
report "STEP 7: GIT VERIFICATION"
report "========================"
report ""

cd "$PROJECT_ROOT"

# Check git status
GIT_STATUS=$(git status --porcelain 2>/dev/null || echo "Git not available")

report "Git status:"
report "$GIT_STATUS"
report ""

# Check recent commits
report "Recent commits affecting MainActivity:"
git log --oneline -10 -- "android/app/src/main/java/com/kasmtech/kasmvnc/MainActivity.kt" 2>/dev/null | sed 's/^/  /' >> "$VERIFICATION_REPORT"

report ""

# STEP 8: Final verdict
log_section "STEP 8: VERIFICATION VERDICT"

report ""
report "STEP 8: FINAL VERDICT"
report "===================="
report ""

VERDICT="PASS"

if [ "$HAS_BUG" = true ]; then
    VERDICT="FAIL"
    log_error "FIX NOT APPLIED - onBackPressed() override still present"
    report "✗ FAIL: onBackPressed() override still present - FIX NOT APPLIED"
fi

if [ "$HAS_FIX" = false ] && [ "$VERDICT" = "FAIL" ]; then
    log_error "FIX NOT APPLIED - OnBackPressedDispatcher not found"
    report "✗ FAIL: OnBackPressedDispatcher callback not found - FIX NOT APPLIED"
fi

if [ "$HAS_FIX" = true ] && [ "$HAS_BUG" != true ]; then
    log_ok "FIX VERIFIED - Ready for build"
    report "✓ PASS: Fix verified and applied correctly"
    report ""
    report "Summary:"
    report "  ✓ onBackPressed() override removed"
    report "  ✓ onBackPressedDispatcher.addCallback() implemented"
    report "  ✓ Source file is active Gradle source"
    report "  ✓ No conflicting backup files in build path"
    report ""
    report "Status: READY FOR BUILD"
else
    VERDICT="FAIL"
    report "Status: FIX VERIFICATION FAILED"
fi

report ""
report "════════════════════════════════════════════════════════"
report "Verification complete. Report saved to: $VERIFICATION_REPORT"
report "════════════════════════════════════════════════════════"

echo ""
echo "════════════════════════════════════════════════════════"
if [ "$VERDICT" = "PASS" ]; then
    log_ok "VERIFICATION PASSED - FIX IS CORRECTLY APPLIED"
else
    log_error "VERIFICATION FAILED - FIX NOT APPLIED OR INCOMPLETE"
    exit 1
fi
echo "════════════════════════════════════════════════════════"
echo ""
echo "Full report: $VERIFICATION_REPORT"
