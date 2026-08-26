#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
catalog="$project_dir/StrengthLog/Resources/exercise-catalog.json"
image_dir="$project_dir/StrengthLog/Resources/ExerciseImages"
expected_paths=$(mktemp /private/tmp/strengthlog-expected-images.XXXXXX)
actual_paths=$(mktemp /private/tmp/strengthlog-actual-images.XXXXXX)

cleanup() {
  rm -f -- "$expected_paths" "$actual_paths"
}
trap cleanup EXIT INT TERM

jq -r '.[].imagePaths[] | sub("[.]jpg$"; ".webp")' "$catalog" | sort > "$expected_paths"
find "$image_dir" -type f -name '*.webp' | sed "s|^$image_dir/||" | sort > "$actual_paths"

if ! cmp -s "$expected_paths" "$actual_paths"; then
  echo "Bundled exercise images do not exactly match the catalog." >&2
  diff -u "$expected_paths" "$actual_paths" | sed -n '1,80p' >&2
  exit 1
fi

image_count=$(wc -l < "$actual_paths" | tr -d ' ')
size=$(du -sh "$image_dir" | awk '{print $1}')
echo "Exercise images OK: $image_count bundled WebP files ($size)"
