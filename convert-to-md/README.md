# convert-to-md

A pure Bash script for converting simple text-like documents to Markdown.

`convert-to-md.sh` supports local files and piped input from commands like `curl`. It intentionally rejects complex binary or container formats instead of producing unreliable output.

## Supported Formats

- Plain text: `.txt`
- Simple HTML: `.html`, `.htm`
- Simple reStructuredText: `.rst`

Unsupported in pure Bash:

- `.rtf`
- `.docx`
- `.epub`
- `.pdf`

## Usage

Convert one or more local files:

```bash
./convert-to-md.sh notes.txt page.html doc.rst
```

This writes Markdown files next to the source files:

```text
notes.md
page.md
doc.md
```

By default, existing `.md` files are not overwritten. Use `-f` or `--force` to overwrite:

```bash
./convert-to-md.sh -f page.html
```

## Piped Input

Convert content from standard input by specifying the input type:

```bash
curl -L "https://example.com/page.html" | ./convert-to-md.sh --type html
```

Save piped output to a file:

```bash
curl -L "https://example.com/page.html" | ./convert-to-md.sh --type html -o page.md
```

Force overwrite for piped output:

```bash
curl -L "https://example.com/page.html" | ./convert-to-md.sh --type html -f -o page.md
```

Supported piped types:

```text
txt
html
htm
rst
```

## Options

```text
-f, --force           overwrite existing Markdown output files
-o, --output FILE     write piped conversion to FILE instead of stdout
-t, --type TYPE       input type for piped content: txt, html, htm, or rst
    --format TYPE     alias for --type
-h, --help            show help
```

## What Gets Converted

HTML conversion handles basic structure:

- Headings: `<h1>` through `<h6>`
- Paragraphs and line breaks
- Bold: `<strong>`, `<b>`
- Italic: `<em>`, `<i>`
- Simple links: `<a href="url">text</a>`
- Basic lists: `<ul>`, `<ol>`, `<li>`

RST conversion handles underline-style headings, such as:

```rst
Title
=====

Section
-------
```

Converted Markdown:

```markdown
# Title

## Section
```

## Limitations

This is not a complete HTML, RST, or document parser. It is designed for simple documents and predictable markup.

Complex nested HTML, tables, scripts, styles, advanced RST directives, and binary formats are outside the scope of this pure Bash implementation.

For full document conversion, use a dedicated converter such as Pandoc.

## Man Page

A manual page is included:

```bash
man ./convert-to-md.1
```

You can also preview it with:

```bash
mandoc convert-to-md.1
```
