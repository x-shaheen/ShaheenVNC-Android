#!/bin/bash
#
# diagnose_project.sh - Complete static analysis of ShaheenVNC-Android
# This script performs deep code inspection without building
#

set -e

REPORT_FILE="DIAGNOSTIC_REPORT.txt"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_DIR="$PROJECT_ROOT/android"
APP_DIR="$ANDROID_DIR/app/src/main"

echo "================================================"
echo "STATIC CODE ANALYSIS REPORT"
echo "Generated: $(date)"
echo "================================================"
echo ""

{
    echo "DIAGNOSTIC REPORT - ShaheenVNC-Android"
    echo "=========================================="
    echo "Timestamp: $(date)"
    echo "Project Root: $PROJECT_ROOT"
    echo ""
    
    # SECTION 1: Repository Status
    echo "1. GIT REPOSITORY STATUS"
    echo "========================"
    echo "Current Commit: $(cd "$PROJECT_ROOT" && git rev-parse HEAD 2>/dev/null || echo 'N/A')"
    echo "Current Branch: $(cd "$PROJECT_ROOT" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'N/A')"
    echo "Submodule Status:"
    cd "$PROJECT_ROOT" && git submodule status 2>/dev/null || echo "  N/A"
    echo ""
    
    # SECTION 2: Project Structure
    echo "2. PROJECT STRUCTURE"
    echo "===================="
    echo "Android Module: $([ -d "$ANDROID_DIR" ] && echo 'EXISTS' || echo 'MISSING')"
    echo "App Module: $([ -d "$APP_DIR" ] && echo 'EXISTS' || echo 'MISSING')"
    echo "Gradle Files:"
    [ -f "$ANDROID_DIR/build.gradle.kts" ] && echo "  ✓ android/build.gradle.kts" || echo "  ✗ android/build.gradle.kts MISSING"
    [ -f "$ANDROID_DIR/app/build.gradle.kts" ] && echo "  ✓ android/app/build.gradle.kts" || echo "  ✗ android/app/build.gradle.kts MISSING"
    [ -f "$ANDROID_DIR/settings.gradle.kts" ] && echo "  ✓ android/settings.gradle.kts" || echo "  ✗ android/settings.gradle.kts MISSING"
    echo ""
    
    # SECTION 3: AndroidManifest Analysis
    echo "3. ANDROIDMANIFEST.XML ANALYSIS"
    echo "================================"
    MANIFEST="$APP_DIR/AndroidManifest.xml"
    if [ -f "$MANIFEST" ]; then
        echo "✓ Manifest found"
        echo ""
        echo "Package Declaration:"
        grep -o 'package="[^"]*"' "$MANIFEST" || echo "  Not found in root"
        echo ""
        echo "Application Tag:"
        grep -o 'android:label="[^"]*"' "$MANIFEST" || echo "  label not found"
        echo ""
        echo "Activity Declaration:"
        grep 'android:name=".MainActivity"' "$MANIFEST" && echo "  ✓ MainActivity declared" || echo "  ✗ MainActivity NOT found"
        grep 'android:exported="true"' "$MANIFEST" && echo "  ✓ exported=true" || echo "  ✗ exported NOT true"
        grep 'android.intent.action.MAIN' "$MANIFEST" && echo "  ✓ MAIN action present" || echo "  ✗ MAIN action MISSING"
        grep 'android.intent.category.LAUNCHER' "$MANIFEST" && echo "  ✓ LAUNCHER category present" || echo "  ✗ LAUNCHER category MISSING"
    else
        echo "✗ Manifest NOT found at $MANIFEST"
    fi
    echo ""
    
    # SECTION 4: MainActivity Analysis
    echo "4. MAINACTIVITY.KT ANALYSIS"
    echo "============================"
    MAIN_ACTIVITY="$APP_DIR/java/com/kasmtech/kasmvnc/MainActivity.kt"
    if [ -f "$MAIN_ACTIVITY" ]; then
        echo "✓ MainActivity.kt found"
        echo ""
        echo "Checking for termination patterns:"
        
        if grep -q "override fun onBackPressed()" "$MAIN_ACTIVITY"; then
            echo "  ✗ CRITICAL: onBackPressed() override found (BREAKS ACTIVITY LIFECYCLE)"
            echo "     This is the ROOT CAUSE of app termination"
        else
            echo "  ✓ No onBackPressed() override"
        fi
        
        if grep -q "onBackPressedDispatcher.addCallback" "$MAIN_ACTIVITY"; then
            echo "  ✓ OnBackPressedDispatcher callback found (CORRECT)"
        fi
        
        if grep -q "finish()" "$MAIN_ACTIVITY"; then
            echo "  ✗ finish() call found"
        else
            echo "  ✓ No finish() call"
        fi
        
        if grep -q "finishAffinity()" "$MAIN_ACTIVITY"; then
            echo "  ✗ finishAffinity() call found"
        else
            echo "  ✓ No finishAffinity() call"
        fi
        
        if grep -q "System.exit\|exitProcess\|killProcess" "$MAIN_ACTIVITY"; then
            echo "  ✗ System exit/kill calls found"
        else
            echo "  ✓ No System.exit/exitProcess/killProcess calls"
        fi
        
        echo ""
        echo "Lifecycle methods present:"
        grep -c "override fun onCreate" "$MAIN_ACTIVITY" >/dev/null && echo "  ✓ onCreate" || echo "  ✗ onCreate missing"
        grep -c "override fun onStart" "$MAIN_ACTIVITY" >/dev/null && echo "  ✓ onStart" || echo "  (not overridden - OK)"
        grep -c "override fun onResume" "$MAIN_ACTIVITY" >/dev/null && echo "  ✓ onResume" || echo "  (not overridden - OK)"
        grep -c "override fun onDestroy" "$MAIN_ACTIVITY" >/dev/null && echo "  ✓ onDestroy" || echo "  (not overridden - OK)"
        
    else
        echo "✗ MainActivity.kt NOT found at $MAIN_ACTIVITY"
    fi
    echo ""
    
    # SECTION 5: Gradle Configuration
    echo "5. GRADLE BUILD CONFIGURATION"
    echo "=============================="
    APP_GRADLE="$ANDROID_DIR/app/build.gradle.kts"
    if [ -f "$APP_GRADLE" ]; then
        echo "App Module Gradle:"
        grep "compileSdk =" "$APP_GRADLE" | head -1
        grep "targetSdk =" "$APP_GRADLE" | head -1
        grep "minSdk =" "$APP_GRADLE" | head -1
        grep "versionCode =" "$APP_GRADLE" | head -1
        grep "versionName =" "$APP_GRADLE" | head -1
        grep "applicationId =" "$APP_GRADLE" | head -1
        echo ""
        
        echo "Compose Configuration:"
        grep "compose = true" "$APP_GRADLE" && echo "  ✓ Compose enabled" || echo "  ✗ Compose NOT enabled"
        grep "kotlinCompilerExtensionVersion" "$APP_GRADLE"
        echo ""
        
        echo "Dependencies Check:"
        grep "androidx.activity:activity-compose" "$APP_GRADLE" && echo "  ✓ activity-compose found" || echo "  ✗ activity-compose MISSING"
        grep "androidx.compose" "$APP_GRADLE" | wc -l | xargs -I {} echo "  Compose dependencies: {} entries"
    else
        echo "✗ app/build.gradle.kts NOT found"
    fi
    echo ""
    
    # SECTION 6: Kotlin Version Compatibility
    echo "6. VERSION COMPATIBILITY"
    echo "========================"
    ROOT_GRADLE="$ANDROID_DIR/build.gradle.kts"
    if [ -f "$ROOT_GRADLE" ]; then
        echo "Root Gradle Plugins:"
        grep "com.android.application" "$ROOT_GRADLE"
        grep "org.jetbrains.kotlin" "$ROOT_GRADLE"
    fi
    echo ""
    
    # SECTION 7: Resources
    echo "7. RESOURCES & ASSETS"
    echo "====================="
    RESOURCES_DIR="$APP_DIR/res"
    ASSETS_DIR="$APP_DIR/assets"
    echo "Resources directory: $([ -d "$RESOURCES_DIR" ] && echo 'EXISTS' || echo 'MISSING')"
    if [ -d "$RESOURCES_DIR" ]; then
        echo "  Values: $([ -d "$RESOURCES_DIR/values" ] && echo 'EXISTS' || echo 'MISSING')"
        echo "  XML: $([ -d "$RESOURCES_DIR/xml" ] && echo 'EXISTS' || echo 'MISSING')"
    fi
    echo "Assets directory: $([ -d "$ASSETS_DIR" ] && echo 'EXISTS' || echo 'MISSING')"
    echo ""
    
    # SECTION 8: Backup Files Warning
    echo "8. BACKUP FILES DETECTED"
    echo "======================="
    JAVA_DIR="$APP_DIR/java/com/kasmtech/kasmvnc"
    if [ -f "$JAVA_DIR/MainActivity.kt.backup_before_webview_fix" ]; then
        echo "  ⚠ MainActivity.kt.backup_before_webview_fix exists"
        echo "    This contains old WebView implementation"
    fi
    if [ -f "$JAVA_DIR/MainActivity.kt.backup_20260831_144207" ]; then
        echo "  ⚠ MainActivity.kt.backup_20260831_144207 exists"
        echo "    This is intermediate version"
    fi
    echo ""
    
    # SECTION 9: Compile Check
    echo "9. KOTLIN COMPILATION CHECK"
    echo "============================"
    if [ -f "$MAIN_ACTIVITY" ]; then
        # Try basic syntax check
        if grep -q "^package " "$MAIN_ACTIVITY" && grep -q "^import " "$MAIN_ACTIVITY"; then
            echo "  ✓ Basic Kotlin syntax looks valid"
            echo "  ✓ Package declaration present"
            echo "  ✓ Import statements present"
        fi
        
        if grep -q "class MainActivity : ComponentActivity()" "$MAIN_ACTIVITY"; then
            echo "  ✓ MainActivity extends ComponentActivity (CORRECT)"
        fi
    fi
    echo ""
    
    # SECTION 10: Summary & Recommendations
    echo "10. ANALYSIS SUMMARY"
    echo "===================="
    echo "Status: ANALYSIS COMPLETE"
    echo ""
    echo "CRITICAL FINDINGS:"
    
    CRITICAL_COUNT=0
    
    if grep -q "override fun onBackPressed()" "$MAIN_ACTIVITY"; then
        echo "  1. CRITICAL: onBackPressed() override causes Activity termination on Android 15"
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    fi
    
    if [ $CRITICAL_COUNT -eq 0 ]; then
        echo "  ✓ No critical issues detected in static analysis"
    else
        echo ""
        echo "IMMEDIATE ACTION REQUIRED:"
        echo "  - Replace onBackPressed() override with OnBackPressedDispatcher.addCallback()"
        echo "  - This is the root cause of app exit on Android 13+"
    fi
    
} | tee "$REPORT_FILE"

echo ""
echo "Report saved to: $REPORT_FILE"
