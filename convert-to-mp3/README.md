# convert-to-mp3

`convert-to-mp3` converts one or more video or audio files to MP3 files using VLC.

Each output file is created in the same directory as the input file with the same base name and a `.mp3` extension.

## Requirements

- Bash
- VLC media player

On macOS, the script can use VLC from `/Applications/VLC.app/Contents/MacOS/VLC`. It also supports `cvlc` or `vlc` if either command is available in `PATH`.

## Usage

```bash
./convert-to-mp3.sh [--force] <input-video-or-audio-file> [more-files...]
```

Convert one file:

```bash
./convert-to-mp3.sh movie.mp4
```

Convert multiple files:

```bash
./convert-to-mp3.sh movie.mp4 interview.mov audio.wav
```

Overwrite existing MP3 files:

```bash
./convert-to-mp3.sh --force movie.mp4 interview.mov
```

## Output

Examples:

```text
movie.mp4      -> movie.mp3
interview.mov  -> interview.mp3
audio.wav      -> audio.mp3
```

The script will not overwrite an existing output file unless `--force` or `-f` is provided.

## Exit Status

- `0`: all files converted successfully
- `1`: VLC was not found, a file could not be converted, an output already existed, or another conversion error occurred
- `2`: invalid usage

When converting multiple files, the script continues after per-file errors and exits with status `1` if any conversion failed.

## Man Page

View the included man page locally:

```bash
man ./convert-to-mp3.1
```
