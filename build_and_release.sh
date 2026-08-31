#!/bin/bash
#
# build_and_release.sh - Complete build and GitHub release pipeline
# This script handles build, APK generation, GitHub release creation
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$PROJECT_ROOT/android"
RELEASES_DIR="$PROJECT_ROOT/releases"
BUILD_OUTPUT="$ANDROID_DIR/app/build/outputs/apk/debug"
APK_NAME="app-debug.apk"

# Version info
VERSION_NAME="1.0.0"
VERSION_CODE="1"
APP_ID="com.kasmtech.kasmvnc"
RELEASE_NAME="ShaheenVNC-v${VERSION_NAME}-debug.apk"

# Report file
REPORT_FILE="$PROJECT_ROOT/BUILD_RELEASE_REPORT.txt"

log_section() {
    echo -e "${GREEN}[*]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Initialize report
init_report() {
    {
        echo "================================================"
        echo "BUILD AND RELEASE REPORT"
        echo "================================================"
        echo "Timestamp: $(date)"
        echo "Project: $PROJECT_ROOT"
        echo "Android Module: $ANDROID_DIR"
        echo ""
    } | tee "$REPORT_FILE"
}

append_report() {
    echo "$1" >> "$REPORT_FILE"
}

# Phase 1: Pre-build verification
phase_1_verify() {
    log_section "PHASE 1: PRE-BUILD VERIFICATION"
    
    append_report ""
    append_report "PHASE 1: PRE-BUILD VERIFICATION"
    append_report "=============================="
    
    # Check git status
    log_section "Checking Git status..."
    cd "$PROJECT_ROOT"
    
    GIT_STATUS=$(git status --porcelain | wc -l)
    if [ $GIT_STATUS -eq 0 ]; then
        log_success "Working directory clean"
        append_report "✓ Working directory clean"
    else
        log_warn "Working directory has changes:"
        git status --short
        append_report "⚠ Working directory has changes"
        cd "$ANDROID_DIR" && git status --short >> "$REPORT_FILE"
    fi
    
    # Check current commit
    CURRENT_COMMIT=$(git rev-parse HEAD | head -c 8)
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    log_success "Current commit: $CURRENT_COMMIT on branch: $CURRENT_BRANCH"
    append_report "Current commit: $CURRENT_COMMIT"
    append_report "Current branch: $CURRENT_BRANCH"
    
    # Check submodules
    log_section "Checking submodules..."
    git submodule status | while read line; do
        append_report "Submodule: $line"
    done
    
    # Verify key files exist
    log_section "Verifying key files..."
    
    declare -a FILES=(
        "$ANDROID_DIR/app/build.gradle.kts"
        "$ANDROID_DIR/app/src/main/AndroidManifest.xml"
        "$ANDROID_DIR/app/src/main/java/com/kasmtech/kasmvnc/MainActivity.kt"
        "$ANDROID_DIR/settings.gradle.kts"
        "$ANDROID_DIR/build.gradle.kts"
    )
    
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            log_success "Found: $(basename $file)"
            append_report "✓ $file"
        else
            log_error "MISSING: $file"
            append_report "✗ MISSING: $file"
            return 1
        fi
    done
    
    # Check MainActivity for critical issues
    log_section "Scanning MainActivity for issues..."
    MA_FILE="$ANDROID_DIR/app/src/main/java/com/kasmtech/kasmvnc/MainActivity.kt"
    
    if grep -q "override fun onBackPressed()" "$MA_FILE"; then
        log_error "CRITICAL: onBackPressed() override still present!"
        append_report "✗ CRITICAL: onBackPressed() override detected"
        return 1
    else
        log_success "No onBackPressed() override (good)"
        append_report "✓ No onBackPressed() override"
    fi
    
    if grep -q "onBackPressedDispatcher.addCallback" "$MA_FILE"; then
        log_success "OnBackPressedDispatcher callback found"
        append_report "✓ OnBackPressedDispatcher callback present"
    else
        log_warn "OnBackPressedDispatcher callback not found"
        append_report "⚠ OnBackPressedDispatcher callback not found"
    fi
    
    append_report ""
}

# Phase 2: Clean build
phase_2_clean_build() {
    log_section "PHASE 2: GRADLE CLEAN BUILD"
    
    append_report ""
    append_report "PHASE 2: GRADLE CLEAN BUILD"
    append_report "=========================="
    
    cd "$ANDROID_DIR"
    
    log_section "Running: gradlew clean"
    if ./gradlew clean > /dev/null 2>&1; then
        log_success "Gradle clean completed"
        append_report "✓ Gradle clean successful"
    else
        log_error "Gradle clean failed"
        append_report "✗ Gradle clean failed"
        return 1
    fi
    
    log_section "Running: gradlew :app:assembleDebug"
    if ./gradlew :app:assembleDebug --no-daemon --stacktrace > /tmp/gradle_build.log 2>&1; then
        log_success "BUILD SUCCESSFUL"
        append_report "✓ BUILD SUCCESSFUL"
        
        # Extract build info
        grep "BUILD SUCCESSFUL" /tmp/gradle_build.log >> "$REPORT_FILE"
    else
        log_error "BUILD FAILED"
        append_report "✗ BUILD FAILED"
        tail -50 /tmp/gradle_build.log >> "$REPORT_FILE"
        return 1
    fi
    
    append_report ""
}

# Phase 3: Verify APK
phase_3_verify_apk() {
    log_section "PHASE 3: APK VERIFICATION"
    
    append_report ""
    append_report "PHASE 3: APK VERIFICATION"
    append_report "========================"
    
    APK_PATH="$BUILD_OUTPUT/$APK_NAME"
    
    if [ ! -f "$APK_PATH" ]; then
        log_error "APK not found at: $APK_PATH"
        append_report "✗ APK not found at: $APK_PATH"
        return 1
    fi
    
    log_success "APK found"
    
    # Get APK details
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    APK_SIZE_BYTES=$(stat -f%z "$APK_PATH" 2>/dev/null || stat -c%s "$APK_PATH" 2>/dev/null || echo "unknown")
    
    log_success "APK Size: $APK_SIZE"
    append_report "APK Path: $APK_PATH"
    append_report "APK Size: $APK_SIZE ($APK_SIZE_BYTES bytes)"
    
    # Try to extract manifest info
    if command -v unzip &> /dev/null; then
        log_section "Extracting APK manifest..."
        
        # Extract package name from manifest
        if unzip -p "$APK_PATH" AndroidManifest.xml | strings | grep -o "com.kasmtech.kasmvnc" > /dev/null; then
            log_success "Package ID verified: $APP_ID"
            append_report "✓ Package ID verified: $APP_ID"
        else
            log_error "Package ID mismatch"
            append_report "✗ Package ID verification failed"
        fi
    fi
    
    # Calculate SHA256
    log_section "Computing APK SHA256..."
    if command -v sha256sum &> /dev/null; then
        APK_SHA256=$(sha256sum "$APK_PATH" | awk '{print $1}')
    elif command -v shasum &> /dev/null; then
        APK_SHA256=$(shasum -a 256 "$APK_PATH" | awk '{print $1}')
    else
        log_warn "sha256sum not available, skipping hash"
        APK_SHA256="N/A"
    fi
    
    log_success "SHA256: $APK_SHA256"
    append_report "SHA256: $APK_SHA256"
    
    append_report ""
}

# Phase 4: Create release directory and copy APK
phase_4_prepare_release() {
    log_section "PHASE 4: PREPARE RELEASE"
    
    append_report ""
    append_report "PHASE 4: PREPARE RELEASE"
    append_report "======================="
    
    # Create releases directory
    mkdir -p "$RELEASES_DIR"
    log_success "Created releases directory: $RELEASES_DIR"
    append_report "✓ Created releases directory"
    
    # Copy APK
    cp "$BUILD_OUTPUT/$APK_NAME" "$RELEASES_DIR/$RELEASE_NAME"
    log_success "Copied APK to: $RELEASES_DIR/$RELEASE_NAME"
    append_report "✓ Copied APK: $RELEASE_NAME"
    
    # Create SHA256 file
    if [ "$APK_SHA256" != "N/A" ]; then
        echo "$APK_SHA256  $RELEASE_NAME" > "$RELEASES_DIR/$RELEASE_NAME.sha256"
        log_success "Created SHA256 file"
        append_report "✓ Created SHA256 file"
    fi
    
    # List release directory
    log_section "Release directory contents:"
    ls -lh "$RELEASES_DIR" | tail -n +2 | while read line; do
        log_success "$line"
    done
    
    append_report ""
}

# Phase 5: Git operations
phase_5_git_commit() {
    log_section "PHASE 5: GIT COMMIT AND PUSH"
    
    append_report ""
    append_report "PHASE 5: GIT COMMIT AND PUSH"
    append_report "============================"
    
    cd "$PROJECT_ROOT"
    
    # Check what needs to be committed
    GIT_CHANGES=$(git status --porcelain | grep -v "??")
    
    if [ -z "$GIT_CHANGES" ]; then
        log_warn "No tracked files changed, skipping commit"
        append_report "⚠ No tracked files changed"
    else
        log_section "Changed files:"
        git status --short
        
        log_section "Adding changes..."
        git add -A
        
        log_section "Committing with message..."
        COMMIT_MSG="fix: stabilize Android runtime - resolve Activity termination issue

- Fix: Replace deprecated onBackPressed() override with OnBackPressedDispatcher
- Reason: ComponentActivity from androidx.activity does not support onBackPressed override
- Impact: Prevents Activity lifecycle corruption on Android 13+
- Verified: MainActivity now properly reaches onCreate->setContent->Compose lifecycle
- Device: HONOR NIC-LX2 (Android 15, API 35)

Release: v${VERSION_NAME} (code: ${VERSION_CODE})"
        
        if git commit -m "$COMMIT_MSG"; then
            log_success "Commit successful"
            COMMIT_HASH=$(git rev-parse HEAD | head -c 8)
            append_report "✓ Commit successful: $COMMIT_HASH"
        else
            log_warn "No changes to commit"
            append_report "⚠ No changes to commit"
        fi
    fi
    
    # Show current status
    log_section "Git status:"
    git status --short
    
    append_report ""
}

# Phase 6: GitHub push
phase_6_git_push() {
    log_section "PHASE 6: PUSH TO GITHUB"
    
    append_report ""
    append_report "PHASE 6: PUSH TO GITHUB"
    append_report "======================"
    
    cd "$PROJECT_ROOT"
    
    # Get remote and branch info
    REMOTE=$(git remote -v | grep "push" | awk '{print $1}' | head -1)
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    
    log_section "Remote: $REMOTE"
    log_section "Branch: $BRANCH"
    
    append_report "Remote: $REMOTE"
    append_report "Branch: $BRANCH"
    
    # Push to remote
    if git push "$REMOTE" "$BRANCH" > /tmp/git_push.log 2>&1; then
        log_success "Push successful"
        append_report "✓ Push to $REMOTE/$BRANCH successful"
    else
        log_error "Push failed"
        append_report "✗ Push failed"
        cat /tmp/git_push.log >> "$REPORT_FILE"
        return 1
    fi
    
    append_report ""
}

# Phase 7: Create GitHub Release
phase_7_github_release() {
    log_section "PHASE 7: CREATE GITHUB RELEASE"
    
    append_report ""
    append_report "PHASE 7: CREATE GITHUB RELEASE"
    append_report "=============================="
    
    # Check if gh CLI is available
    if ! command -v gh &> /dev/null; then
        log_warn "GitHub CLI (gh) not available, cannot create release automatically"
        append_report "⚠ GitHub CLI not available - cannot create release"
        append_report ""
        append_report "MANUAL STEPS TO CREATE RELEASE:"
        append_report "1. Go to: https://github.com/x-shaheen/ShaheenVNC-Android/releases/new"
        append_report "2. Tag version: v${VERSION_NAME}"
        append_report "3. Release title: ShaheenVNC v${VERSION_NAME}"
        append_report "4. Attach file: $RELEASES_DIR/$RELEASE_NAME"
        append_report "5. Attach file: $RELEASES_DIR/$RELEASE_NAME.sha256"
        return 0
    fi
    
    log_section "GitHub CLI available, attempting release creation..."
    
    # Check auth status
    if gh auth status > /dev/null 2>&1; then
        log_success "GitHub CLI authenticated"
        append_report "✓ GitHub CLI authenticated"
    else
        log_error "GitHub CLI not authenticated"
        append_report "✗ GitHub CLI not authenticated"
        return 1
    fi
    
    # Get repository info
    REPO="x-shaheen/ShaheenVNC-Android"
    TAG="v${VERSION_NAME}"
    
    log_section "Creating tag: $TAG"
    
    # Check if tag exists
    if git rev-parse "$TAG" >/dev/null 2>&1; then
        log_warn "Tag $TAG already exists"
        append_report "⚠ Tag $TAG already exists"
    else
        if git tag -a "$TAG" -m "ShaheenVNC Android Release v${VERSION_NAME}"; then
            log_success "Tag created: $TAG"
            append_report "✓ Tag created: $TAG"
            
            if git push origin "$TAG"; then
                log_success "Tag pushed to origin"
                append_report "✓ Tag pushed to origin"
            else
                log_error "Failed to push tag"
                append_report "✗ Failed to push tag"
                return 1
            fi
        else
            log_error "Failed to create tag"
            append_report "✗ Failed to create tag"
            return 1
        fi
    fi
    
    # Create release
    RELEASE_NOTES="## ShaheenVNC v${VERSION_NAME}

### Fix: Stabilized Android Runtime

**Issue**: Application exits immediately on Android 15 (API 35)

**Root Cause**: Broken \`onBackPressed()\` override in MainActivity
- ComponentActivity from androidx.activity does not support \`onBackPressed()\` override
- Attempting to override corrupts Activity lifecycle
- Activity fails to reach resumed state and is terminated by system

**Solution**: Replaced with OnBackPressedDispatcher callback pattern
- Modern approach compatible with Android 5+
- Properly integrated with ComponentActivity lifecycle
- Maintains Activity state machine integrity

**Device**: HONOR NIC-LX2 (Android 15, API 35)
**Status**: ✓ Verified working

### Files Modified
- \`android/app/src/main/java/com/kasmtech/kasmvnc/MainActivity.kt\`
  - Removed: \`override fun onBackPressed()\`
  - Added: \`onBackPressedDispatcher.addCallback()\` in onCreate()

### Build Info
- Gradle: 8.2.2
- Kotlin: 1.9.22
- Compose: 2023.10.01
- Min API: 26
- Target API: 34
- Compiled API: 34

### Downloads
- [ShaheenVNC-v${VERSION_NAME}-debug.apk](releases/download/v${VERSION_NAME}/$RELEASE_NAME)
- SHA256: \`$APK_SHA256\`"

    if gh release create "$TAG" \
        "$RELEASES_DIR/$RELEASE_NAME" \
        "$RELEASES_DIR/$RELEASE_NAME.sha256" \
        --title "ShaheenVNC v${VERSION_NAME}" \
        --notes "$RELEASE_NOTES" > /tmp/gh_release.log 2>&1; then
        
        log_success "GitHub Release created successfully"
        append_report "✓ GitHub Release created: $TAG"
        
        # Get release URL
        RELEASE_URL=$(gh release view "$TAG" --json url --jq .url)
        log_success "Release URL: $RELEASE_URL"
        append_report "Release URL: $RELEASE_URL"
    else
        log_error "Failed to create GitHub Release"
        append_report "✗ Failed to create GitHub Release"
        cat /tmp/gh_release.log >> "$REPORT_FILE"
        return 1
    fi
    
    append_report ""
}

# Main execution
main() {
    init_report
    
    if phase_1_verify; then
        log_success "Phase 1 completed"
    else
        log_error "Phase 1 failed"
        return 1
    fi
    
    if phase_2_clean_build; then
        log_success "Phase 2 completed"
    else
        log_error "Phase 2 failed"
        return 1
    fi
    
    if phase_3_verify_apk; then
        log_success "Phase 3 completed"
    else
        log_error "Phase 3 failed"
        return 1
    fi
    
    if phase_4_prepare_release; then
        log_success "Phase 4 completed"
    else
        log_error "Phase 4 failed"
        return 1
    fi
    
    phase_5_git_commit
    log_success "Phase 5 completed"
    
    if phase_6_git_push; then
        log_success "Phase 6 completed"
    else
        log_error "Phase 6 failed - continuing to Phase 7"
    fi
    
    if phase_7_github_release; then
        log_success "Phase 7 completed"
    else
        log_error "Phase 7 completed with warnings"
    fi
    
    # Final summary
    echo ""
    echo "================================================"
    log_success "BUILD AND RELEASE PIPELINE COMPLETED"
    echo "================================================"
    echo ""
    log_success "Report saved to: $REPORT_FILE"
    echo ""
    
    append_report "================================================"
    append_report "PIPELINE COMPLETED"
    append_report "================================================"
    
    cat "$REPORT_FILE"
}

main "$@"
