#!/usr/bin/env bash

set -euo pipefail

usage() {
  printf 'Usage: %s [--force] <input-video-or-audio-file> [more-files...]\n' "$(basename "$0")"
}

force=0

if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
  force=1
  shift
fi

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi

if command -v cvlc >/dev/null 2>&1; then
  vlc=(cvlc)
elif command -v vlc >/dev/null 2>&1; then
  vlc=(vlc -I dummy)
elif [[ -x /Applications/VLC.app/Contents/MacOS/VLC ]]; then
  vlc=(/Applications/VLC.app/Contents/MacOS/VLC -I dummy)
else
  printf 'Error: VLC was not found. Install VLC or add vlc/cvlc to PATH.\n' >&2
  exit 1
fi

failures=0

for input in "$@"; do
  if [[ ! -f "$input" ]]; then
    printf 'Error: input file not found: %s\n' "$input" >&2
    failures=$((failures + 1))
    continue
  fi

  input_dir=$(cd "$(dirname "$input")" && pwd)
  input_file=$(basename "$input")
  base_name=${input_file%.*}
  output="$input_dir/$base_name.mp3"

  if [[ "$input_dir/$input_file" == "$output" ]]; then
    printf 'Error: input is already the target MP3 file: %s\n' "$input" >&2
    failures=$((failures + 1))
    continue
  fi

  if [[ -e "$output" && "$force" -ne 1 ]]; then
    printf 'Error: output already exists: %s\n' "$output" >&2
    printf 'Use --force to overwrite it.\n' >&2
    failures=$((failures + 1))
    continue
  fi

  if [[ "$force" -eq 1 ]]; then
    rm -f "$output"
  fi

  if "${vlc[@]}" "$input" \
    --sout "#transcode{acodec=mp3,ab=192,channels=2,samplerate=44100}:std{access=file,mux=raw,dst=$output}" \
    vlc://quit; then
    printf 'Created: %s\n' "$output"
  else
    printf 'Error: failed to convert: %s\n' "$input" >&2
    failures=$((failures + 1))
  fi
done

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
