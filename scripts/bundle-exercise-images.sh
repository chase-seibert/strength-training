#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
catalog="$project_dir/StrengthLog/Resources/exercise-catalog.json"
output_dir="$project_dir/StrengthLog/Resources/ExerciseImages"
source_revision="b0eed061e1c832b3ed815fbaa4b45b3cdc14df49"
work_dir=$(mktemp -d /private/tmp/strengthlog-exercise-images.XXXXXX)

cleanup() {
  rm -rf -- "$work_dir"
}
trap cleanup EXIT INT TERM

for command_name in cwebp git jq; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
done

echo "Fetching Free Exercise DB at $source_revision..."
git -C "$work_dir" init --quiet source
git -C "$work_dir/source" remote add origin https://github.com/yuhonas/free-exercise-db.git
git -C "$work_dir/source" fetch --quiet --depth 1 origin "$source_revision"
git -C "$work_dir/source" checkout --quiet FETCH_HEAD -- exercises LICENSE.md

staging_dir="$work_dir/ExerciseImages"
mkdir -p "$staging_dir"
jq -r '.[].imagePaths[]' "$catalog" > "$work_dir/image-paths.txt"

image_count=0
while IFS= read -r image_path; do
  source_image="$work_dir/source/exercises/$image_path"
  relative_webp=${image_path%.jpg}.webp
  output_image="$staging_dir/$relative_webp"
  if [ ! -f "$source_image" ]; then
    echo "Missing upstream image: $image_path" >&2
    exit 1
  fi
  mkdir -p "$(dirname -- "$output_image")"
  cwebp -quiet -q 65 -resize 640 0 "$source_image" -o "$output_image"
  image_count=$((image_count + 1))
done < "$work_dir/image-paths.txt"

if [ "$image_count" -ne 1746 ]; then
  echo "Expected 1,746 images, generated $image_count" >&2
  exit 1
fi

if [ "$output_dir" != "$project_dir/StrengthLog/Resources/ExerciseImages" ]; then
  echo "Refusing to replace unexpected output path: $output_dir" >&2
  exit 1
fi
rm -rf -- "$output_dir"
mv "$staging_dir" "$output_dir"

size=$(du -sh "$output_dir" | awk '{print $1}')
echo "Bundled $image_count exercise images at 640 px / WebP quality 65 ($size)."
