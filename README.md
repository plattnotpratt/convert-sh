# convert

Small Bash utilities for converting files:

- `convert-to-md`: converts simple text-like documents to Markdown.
- `convert-to-mp3`: converts audio or video files to MP3 using VLC.
- `convert-to-json`: converts simple object-storage formats to JSON.

Each utility lives in its own folder with a script, README, and man page.

## Contents

```text
convert-to-md/
  convert-to-md.sh
  convert-to-md.1
  README.md

convert-to-mp3/
  convert-to-mp3.sh
  convert-to-mp3.1
  README.md

convert-to-json/
  convert-to-json.sh
  convert-to-json.1
  README.md
```

## convert-to-md

`convert-to-md/convert-to-md.sh` is a pure Bash converter for simple text-like formats.

It supports:

- Plain text: `.txt`
- Simple HTML: `.html`, `.htm`
- Simple reStructuredText: `.rst`

It intentionally rejects formats that are not practical to parse correctly in pure Bash:

- `.rtf`
- `.docx`
- `.epub`
- `.pdf`

### File Usage

```bash
cd convert-to-md
./convert-to-md.sh notes.txt page.html doc.rst
```

For file inputs, output is written next to each source file by replacing the source extension with `.md`:

```text
notes.txt  -> notes.md
page.html  -> page.md
doc.rst    -> doc.md
```

Existing Markdown files are not overwritten unless force mode is enabled:

```bash
./convert-to-md.sh --force page.html
```

### Piped Usage

Piped input requires an explicit type because there is no filename extension to inspect:

```bash
curl -L "https://example.com/page.html" | ./convert-to-md.sh --type html
```

Write piped output to a file:

```bash
curl -L "https://example.com/page.html" | ./convert-to-md.sh --type html --output page.md
```

Force overwrite for piped output:

```bash
curl -L "https://example.com/page.html" | ./convert-to-md.sh --type html --force --output page.md
```

### Options

```text
-f, --force              overwrite existing Markdown output files
-o, --output FILE        write piped conversion to FILE instead of stdout
-t, --type TYPE          input type for piped content: txt, html, htm, or rst
    --format TYPE        alias for --type
-h, --help               show help
```

Notes:

- `--output` is only valid with piped input.
- Piped `--type` values are `txt`, `html`, `htm`, and `rst`.
- The HTML and RST conversion is intentionally simple and is not a complete parser.

## convert-to-mp3

`convert-to-mp3/convert-to-mp3.sh` converts one or more audio or video files to MP3 using VLC.

The script looks for VLC in this order:

- `cvlc` in `PATH`
- `vlc` in `PATH`
- `/Applications/VLC.app/Contents/MacOS/VLC` on macOS

### Usage

```bash
cd convert-to-mp3
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

For each input, the output is written to the same directory with the same base name and a `.mp3` extension:

```text
movie.mp4      -> movie.mp3
interview.mov  -> interview.mp3
audio.wav      -> audio.mp3
```

### Options

```text
-f, --force    overwrite existing MP3 output files
```

The MP3 conversion uses VLC transcoding with these audio settings:

- Codec: MP3
- Bitrate: 192 kbps
- Channels: 2
- Sample rate: 44100 Hz

## convert-to-json

`convert-to-json/convert-to-json.sh` is a pure Bash converter for simple object-storage formats.

It supports:

- CSV: `.csv`
- SQL-style CSV rows: `.sql`
- Simple YAML: `.yaml`, `.yml`
- Simple TOML: `.toml`

SQL support means SELECT-like CSV output with a header row. It does not parse SQL statements.

### File Usage

```bash
cd convert-to-json
./convert-to-json.sh data.csv config.yaml settings.toml rows.sql
```

For file inputs, output is written next to each source file by replacing the source extension with `.json`:

```text
data.csv       -> data.json
config.yaml    -> config.json
settings.toml  -> settings.json
rows.sql       -> rows.json
```

Existing JSON files are not overwritten unless force mode is enabled:

```bash
./convert-to-json.sh --force data.csv
```

### Piped Usage

Piped input requires an explicit type because there is no filename extension to inspect:

```bash
curl -L "https://example.com/data.csv" | ./convert-to-json.sh --type csv
```

Write piped output to a file:

```bash
curl -L "https://example.com/settings.toml" | ./convert-to-json.sh --type toml --output settings.json
```

Force overwrite for piped output:

```bash
curl -L "https://example.com/data.csv" | ./convert-to-json.sh --type csv --force --output data.json
```

### Options

```text
-f, --force              overwrite existing JSON output files
-o, --output FILE        write piped conversion to FILE instead of stdout
-t, --type TYPE          input type for piped content: csv, sql, yaml, yml, or toml
    --format TYPE        alias for --type
-h, --help               show help
```

Notes:

- `--output` is only valid with piped input.
- Piped `--type` values are `csv`, `sql`, `yaml`, `yml`, and `toml`.
- The YAML and TOML conversion is intentionally simple and is not a complete parser.

## Man Pages

Each tool includes a local man page:

```bash
man ./convert-to-md/convert-to-md.1
man ./convert-to-mp3/convert-to-mp3.1
man ./convert-to-json/convert-to-json.1
```

## Exit Status

`convert-to-md` exits non-zero if usage is invalid, an input cannot be converted, an output already exists without `--force`, or the input format is unsupported.

`convert-to-mp3` uses:

- `0`: all files converted successfully
- `1`: VLC was not found, a file could not be converted, an output already existed, or another conversion error occurred
- `2`: invalid usage

When converting multiple MP3 inputs, the script continues after per-file errors and exits with `1` if any conversion failed.

`convert-to-json` exits non-zero if usage is invalid, an input cannot be converted, an output already exists without `--force`, or the input format is unsupported.
