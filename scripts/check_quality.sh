#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FIX_MODE=0
WITH_LIVE=0
for arg in "$@"; do
    case "$arg" in
        --fix) FIX_MODE=1 ;;
        --with-live) WITH_LIVE=1 ;;
        *)
            echo "Unknown option: $arg" >&2
            echo "Usage: $0 [--fix] [--with-live]" >&2
            exit 2
            ;;
    esac
done

if [[ $FIX_MODE -eq 1 ]]; then
    echo "==> [0/4] Running swift-format --in-place..."
    xcrun swift-format format --in-place --configuration "$ROOT_DIR/.swift-format" -r -p Sources Tests
fi

echo "==> [1/4] Checking file length (<= 300 lines) & UpperCamelCase naming..."
MAX_LINES=300
VIOLATIONS=0
while IFS= read -r -d '' file; do
    base="$(basename "$file")"
    if [[ "$base" == *"+"* ]]; then
        echo "ERROR [Naming]: '$file' contains '+' (use UpperCamelCase modular file names)." >&2
        VIOLATIONS=1
    fi
    if [[ ! "$base" =~ ^[A-Z][A-Za-z0-9]*\.swift$ ]]; then
        echo "ERROR [Naming]: '$file' must be UpperCamelCase ASCII identifier." >&2
        VIOLATIONS=1
    fi
    line_count="$(wc -l < "$file" | tr -d ' ')"
    if [[ "$line_count" -gt "$MAX_LINES" ]]; then
        echo "ERROR [LineLimit]: '$file' has $line_count lines (limit: $MAX_LINES)." >&2
        VIOLATIONS=1
    fi
done < <(find Sources Tests -type f -name '*.swift' -print0)

if [[ $VIOLATIONS -ne 0 ]]; then
    exit 1
fi
echo "    OK: All Swift files are <= $MAX_LINES lines and follow UpperCamelCase modular naming."

if [[ "${SKIP_SWIFT_FORMAT:-0}" != "1" ]]; then
    echo "==> [2/4] Running strict format & lint check (swift-format lint --strict)..."
    xcrun swift-format lint --strict --configuration "$ROOT_DIR/.swift-format" -r -p Sources Tests
    echo "    OK: 0 lint warnings/errors."
else
    echo "==> [2/4] Skipping swift-format lint (SKIP_SWIFT_FORMAT=1)."
fi

echo "==> [3/4] Running strict Swift 6 static type & concurrency check (-warnings-as-errors)..."
swift build --package-path "$ROOT_DIR" --build-tests -Xswiftc -warnings-as-errors
echo "    OK: Zero warnings, zero errors."

echo "==> [4/4] Running unit test suites..."
FILTER="BillingEngineTests|SQLiteMigrationAndRepoTests|ViewModelTests|ViewModelPresetFeatureTests|ViewModelLedgerFeatureTests|ViewModelV9FeatureTests|ViewModelV11FeatureTests|APIBalanceAndBackupTests|WorkflowRegressionTests|SQLiteSecretsAndUpdateTests|EditorHistoryAndRenewalModeTests|AppLogServiceTests|AppUpdateFlowTests|InitialBillingRecordTests|EditorFormInteractionsTests"
if [[ $WITH_LIVE -eq 1 ]]; then
    swift test --package-path "$ROOT_DIR"
else
    swift test --package-path "$ROOT_DIR" --filter "$FILTER"
fi
echo "==> All quality checks passed!"
