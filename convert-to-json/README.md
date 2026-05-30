# convert-to-json

A pure Bash script for converting simple object-storage formats to JSON.

`convert-to-json.sh` supports local files and piped input. It intentionally handles conservative subsets of YAML and TOML instead of pretending to be a full parser.

## Supported Formats

- CSV: `.csv`
- SQL-style CSV rows: `.sql`
- Simple YAML: `.yaml`, `.yml`
- Simple TOML: `.toml`

SQL support means SELECT-like CSV output with a header row. It does not parse SQL statements.

## Usage

Convert one or more local files:

```bash
./convert-to-json.sh data.csv config.yaml settings.toml rows.sql
```

This writes JSON files next to the source files:

```text
data.json
config.json
settings.json
rows.json
```

By default, existing `.json` files are not overwritten. Use `-f` or `--force` to overwrite:

```bash
./convert-to-json.sh -f data.csv
```

## Piped Input

Convert content from standard input by specifying the input type:

```bash
curl -L "https://example.com/data.csv" | ./convert-to-json.sh --type csv
```

Save piped output to a file:

```bash
curl -L "https://example.com/data.csv" | ./convert-to-json.sh --type csv -o data.json
```

Force overwrite for piped output:

```bash
curl -L "https://example.com/data.csv" | ./convert-to-json.sh --type csv -f -o data.json
```

Supported piped types:

```text
csv
sql
yaml
yml
toml
```

## Options

```text
-f, --force           overwrite existing JSON output files
-o, --output FILE     write piped conversion to FILE instead of stdout
-t, --type TYPE       input type for piped content: csv, sql, yaml, yml, or toml
    --format TYPE     alias for --type
-h, --help            show help
```

## What Gets Converted

CSV and SQL-style CSV conversion uses the first row as object keys:

```csv
id,name,active
1,"Ada, A.",true
2,Bob,false
```

Converted JSON:

```json
[
  {
    "id": 1,
    "name": "Ada, A.",
    "active": true
  },
  {
    "id": 2,
    "name": "Bob",
    "active": false
  }
]
```

YAML conversion handles simple mappings, nested mappings with two-space indentation, scalar values, inline arrays, and scalar list items:

```yaml
server:
  host: localhost
  port: 8080
features:
  - csv
  - yaml
```

TOML conversion handles key/value pairs, dotted sections, scalar values, and inline arrays:

```toml
title = "Example"

[server]
host = "localhost"
port = 8080
features = ["csv", "toml"]
```

## Limitations

This is not a complete CSV, SQL, YAML, or TOML parser. It is designed for simple, predictable data.

CSV supports quoted fields, commas inside quoted fields, and escaped double quotes. It does not support multiline quoted fields.

YAML support does not include anchors, aliases, tags, block scalars, flow objects, top-level arrays, arrays of objects, or advanced typing.

TOML support does not include multiline strings, arrays of tables, quoted dotted keys, dates, or inline tables.

For full-spec conversion, use a dedicated parser such as `jq`, `yq`, Python, Ruby, or Node.

## Man Page

A manual page is included:

```bash
man ./convert-to-json.1
```

You can also preview it with:

```bash
mandoc convert-to-json.1
```
