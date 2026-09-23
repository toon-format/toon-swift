#!/usr/bin/env bash
#
# Regenerates Tests/ToonFormatTests/Support/FixtureExpectations.swift from a
# live test run. Run this script after a migration step, then review the diff:
# every line that disappears is a conformance gap that the step closed.
#
# The script clears the list first, so the run reports every failing case.

set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TARGET="$ROOT/Tests/ToonFormatTests/Support/FixtureExpectations.swift"
readonly FIXTURES="$ROOT/Tests/ToonFormatTests/Fixtures"

write_list() {
  python3 - "$TARGET" "$FIXTURES" "$@" <<'PY'
import json, pathlib, sys

target = pathlib.Path(sys.argv[1])
fixtures = pathlib.Path(sys.argv[2])
ids = sys.argv[3:]

details = {}
for path in sorted(fixtures.glob("*/*.json")):
    if path.name == "PROVENANCE.json":
        continue
    key = f"{path.parent.name}/{path.name}"
    for index, test in enumerate(json.loads(path.read_text())["tests"]):
        section = test.get("specSection", "")
        section = f"§{section.lstrip('§')} " if section else ""
        details[f"{key}#{index}"] = f"{section}{test['name']}"

lines = []
for identifier in sorted(ids):
    reason = details.get(identifier, "unknown case")
    reason = reason.replace("\\", "\\\\").replace('"', "'")
    lines.append(f'        "{identifier}":\n            "{reason}",')

body = "\n".join(lines) if lines else ""
entries = f"\n{body}\n    " if body else ":"

target.write_text(f'''/// The conformance cases that the library does not satisfy yet.
///
/// The key is `<category>/<file>#<index>`, the identifier that
/// ``FixtureCase/id`` builds. The value names the specification section and the
/// case, so that a diff of this file reads as a list of closed gaps.
///
/// ``FixtureTests`` wraps a listed case in `withKnownIssue`, so the run fails
/// when the case starts to pass. Each step of the migration to specification
/// 4.1 removes its own entries, and cannot forget to. The list must be empty
/// for the release.
///
/// Regenerate this file with `Scripts/record-fixture-gaps.sh`.
enum FixtureExpectations {{
    static let knownGaps: [String: String] = [{entries}]
}}
''')
print(f"Recorded {len(ids)} known gaps.")
PY
}

log="$(mktemp)"
backup="$(mktemp)"
cp "$TARGET" "$backup"

# Warning: the script clears the list before the run. Put the list back
# whenever the script stops early, so that a broken run never leaves an empty
# list behind. An empty list makes every case look closed.
restore_on_failure() {
  status=$?
  rm -f "$log"
  if [ "$status" -ne 0 ]; then
    cp "$backup" "$TARGET"
    echo "The script stopped. The list is unchanged." >&2
  fi
  rm -f "$backup"
  exit "$status"
}
trap restore_on_failure EXIT

echo "Clearing the list…"
write_list

echo "Running the fixture suite…"
(cd "$ROOT" && swift test --filter FixtureTests > "$log" 2>&1) || true

# A build failure and a failing case both give a non-zero exit status, so the
# status alone cannot tell them apart. Only a suite that starts writes the
# summary line, so use that line instead.
if ! grep -q 'Test run started' "$log"; then
  echo "The fixture suite did not run. The last 40 lines of the log follow." >&2
  tail -40 "$log" >&2
  exit 1
fi

# Only the issue lines. A "Test case passing …" line names a case that ran,
# not a case that failed.
failing=()
while IFS= read -r identifier; do
  [ -n "$identifier" ] && failing+=("$identifier")
done < <(
  grep 'recorded an issue' "$log" \
    | grep -Eo 'fixture → [A-Za-z0-9_-]+/[A-Za-z0-9_-]+\.json#[0-9]+' \
    | awk '{print $NF}' \
    | sort -u
)

if [ "${#failing[@]}" -eq 0 ]; then
  echo "No failing case found. The library satisfies every fixture."
fi

write_list ${failing[@]+"${failing[@]}"}
