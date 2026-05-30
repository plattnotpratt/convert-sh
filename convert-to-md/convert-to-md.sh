#!/usr/bin/env bash

set -u

force=false
input_type=
output_file=
files=()

usage() {
  printf 'Usage: %s [-f] FILE...\n' "${0##*/}"
  printf '       command | %s --type TYPE [-o OUTPUT.md]\n' "${0##*/}"
  printf '\n'
  printf 'Converts plain text, simple HTML, and simple RST files to Markdown.\n'
  printf 'Pure Bash mode intentionally rejects RTF, DOCX, EPUB, and PDF.\n'
  printf '\n'
  printf 'Options:\n'
  printf '  -f, --force    overwrite existing .md output files\n'
  printf '  -o FILE        write piped conversion to FILE instead of stdout\n'
  printf '  -t, --type     input type for piped content: txt, html, htm, or rst\n'
  printf '  -h, --help     show this help message\n'
}

fail() {
  printf 'convert-to-md: %s\n' "$1" >&2
}

html_decode_entities() {
  local text=$1
  text=${text//&nbsp;/ }
  text=${text//&amp;/&}
  text=${text//&lt;/<}
  text=${text//&gt;/>}
  text=${text//&quot;/\"}
  text=${text//&#39;/\'}
  text=${text//&apos;/\'}
  printf '%s\n' "$text"
}

trim() {
  local text=$1
  text=${text#"${text%%[!$' \t\r\n']*}"}
  text=${text%"${text##*[!$' \t\r\n']}"}
  printf '%s' "$text"
}

convert_txt() {
  local input=$1
  local output=$2
  while IFS= read -r line || [[ -n $line ]]; do
    printf '%s\n' "$line"
  done < "$input" > "$output"
}

convert_html() {
  local input=$1
  local output=$2
  local html line link_re tag_re nl previous_blank wrote_any

  html=$(<"$input")
  nl=$'\n'

  html=${html//$'\r'/}
  html=${html//$'\n'/ }
  html=${html//$'\t'/ }

  html=${html//<h1>/$nl# }
  html=${html//<H1>/$nl# }
  html=${html//<h2>/$nl## }
  html=${html//<H2>/$nl## }
  html=${html//<h3>/$nl### }
  html=${html//<H3>/$nl### }
  html=${html//<h4>/$nl#### }
  html=${html//<H4>/$nl#### }
  html=${html//<h5>/$nl##### }
  html=${html//<H5>/$nl##### }
  html=${html//<h6>/$nl###### }
  html=${html//<H6>/$nl###### }

  html=${html//<\/h1>/$nl$nl}
  html=${html//<\/H1>/$nl$nl}
  html=${html//<\/h2>/$nl$nl}
  html=${html//<\/H2>/$nl$nl}
  html=${html//<\/h3>/$nl$nl}
  html=${html//<\/H3>/$nl$nl}
  html=${html//<\/h4>/$nl$nl}
  html=${html//<\/H4>/$nl$nl}
  html=${html//<\/h5>/$nl$nl}
  html=${html//<\/H5>/$nl$nl}
  html=${html//<\/h6>/$nl$nl}
  html=${html//<\/H6>/$nl$nl}

  html=${html//<strong>/**}
  html=${html//<\/strong>/**}
  html=${html//<b>/**}
  html=${html//<\/b>/**}
  html=${html//<em>/*}
  html=${html//<\/em>/*}
  html=${html//<i>/*}
  html=${html//<\/i>/*}

  html=${html//<p>/$nl$nl}
  html=${html//<P>/$nl$nl}
  html=${html//<\/p>/$nl$nl}
  html=${html//<\/P>/$nl$nl}
  html=${html//<br>/$nl}
  html=${html//<br\/>/$nl}
  html=${html//<br \/>/$nl}
  html=${html//<BR>/$nl}

  html=${html//<ul>/$nl}
  html=${html//<\/ul>/$nl}
  html=${html//<ol>/$nl}
  html=${html//<\/ol>/$nl}
  html=${html//<li>/$nl- }
  html=${html//<\/li>/}

  # Convert simple links before stripping all remaining tags.
  link_re='^(.*)<a[[:space:]]+href=["'\'']([^"'\'']+)["'\''][^>]*>([^<]+)</a>(.*)$'
  while [[ $html =~ $link_re ]]; do
    html="${BASH_REMATCH[1]}[${BASH_REMATCH[3]}](${BASH_REMATCH[2]})${BASH_REMATCH[4]}"
  done

  tag_re='^(.*)<[^>]+>(.*)$'
  while [[ $html =~ $tag_re ]]; do
    html="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
  done

  html=$(html_decode_entities "$html")

  : > "$output"
  previous_blank=true
  wrote_any=false
  while IFS= read -r line || [[ -n $line ]]; do
    line=$(trim "$line")
    if [[ -z $line ]]; then
      if [[ $wrote_any == true && $previous_blank == false ]]; then
        printf '\n' >> "$output"
      fi
      previous_blank=true
      continue
    fi

    printf '%s\n' "$line" >> "$output"
    previous_blank=false
    wrote_any=true
  done <<< "$html"
}

rst_heading_level() {
  case $1 in
    '=') printf '#';;
    '-') printf '##';;
    '~') printf '###';;
    '^') printf '####';;
    '"') printf '#####';;
    "'") printf '######';;
    *) printf '';;
  esac
}

is_repeated_marker() {
  local text=$1
  local marker=$2
  local i

  [[ -n $text ]] || return 1
  for ((i = 0; i < ${#text}; i++)); do
    [[ ${text:i:1} == "$marker" ]] || return 1
  done
}

convert_rst() {
  local input=$1
  local output=$2
  local current marker hashes line previous previous_set

  : > "$output"
  previous_set=false

  while IFS= read -r current || [[ -n $current ]]; do
    if [[ $previous_set == true ]]; then
      marker=${current:0:1}
      hashes=$(rst_heading_level "$marker")

      if [[ -n $hashes && ${#current} -ge ${#previous} && -n $(trim "$previous") ]] && is_repeated_marker "$current" "$marker"; then
        printf '%s %s\n' "$hashes" "$previous" >> "$output"
        previous_set=false
      else
        line=$previous
        line=${line//\`\`/\`}
        printf '%s\n' "$line" >> "$output"
        previous=$current
        previous_set=true
      fi
    else
      previous=$current
      previous_set=true
    fi
  done < "$input"

  if [[ $previous_set == true ]]; then
    line=$previous
    line=${line//\`\`/\`}
    printf '%s\n' "$line" >> "$output"
  fi
}

convert_file() {
  local input=$1
  local base ext output

  if [[ ! -f $input ]]; then
    fail "not a file: $input"
    return 1
  fi

  base=${input%.*}
  ext=${input##*.}
  output="$base.md"

  if [[ $input == "$base" ]]; then
    fail "missing file extension: $input"
    return 1
  fi

  if [[ -e $output && $force != true ]]; then
    fail "refusing to overwrite existing file: $output (use -f to overwrite)"
    return 1
  fi

  case $ext in
    [Tt][Xx][Tt])
      convert_txt "$input" "$output"
      ;;
    [Hh][Tt][Mm][Ll]|[Hh][Tt][Mm])
      convert_html "$input" "$output"
      ;;
    [Rr][Ss][Tt])
      convert_rst "$input" "$output"
      ;;
    [Rr][Tt][Ff]|[Dd][Oo][Cc][Xx]|[Ee][Pp][Uu][Bb]|[Pp][Dd][Ff])
      fail "unsupported in pure Bash: $input"
      return 1
      ;;
    *)
      fail "unsupported file extension: .$ext ($input)"
      return 1
      ;;
  esac

  printf 'Wrote %s\n' "$output"
}

convert_by_type() {
  local type=$1
  local input=$2
  local output=$3

  case $type in
    [Tt][Xx][Tt])
      convert_txt "$input" "$output"
      ;;
    [Hh][Tt][Mm][Ll]|[Hh][Tt][Mm])
      convert_html "$input" "$output"
      ;;
    [Rr][Ss][Tt])
      convert_rst "$input" "$output"
      ;;
    [Rr][Tt][Ff]|[Dd][Oo][Cc][Xx]|[Ee][Pp][Uu][Bb]|[Pp][Dd][Ff])
      fail "unsupported in pure Bash for piped input: $type"
      return 1
      ;;
    *)
      fail "unsupported input type for piped input: $type"
      return 1
      ;;
  esac
}

print_file() {
  local input=$1
  local line

  while IFS= read -r line || [[ -n $line ]]; do
    printf '%s\n' "$line"
  done < "$input"
}

remove_temp_files() {
  [[ -n ${stdin_input:-} && -f ${stdin_input:-} ]] && rm -f "$stdin_input"
  [[ -n ${stdin_output:-} && -f ${stdin_output:-} ]] && rm -f "$stdin_output"
}

convert_stdin() {
  local line

  if [[ -z $input_type ]]; then
    fail "piped input requires --type txt, --type html, or --type rst"
    return 2
  fi

  if [[ -n $output_file && -e $output_file && $force != true ]]; then
    fail "refusing to overwrite existing file: $output_file (use -f to overwrite)"
    return 1
  fi

  stdin_input="${TMPDIR:-/tmp}/convert-to-md-input.$$"
  stdin_output="${TMPDIR:-/tmp}/convert-to-md-output.$$"
  trap remove_temp_files EXIT

  : > "$stdin_input"
  while IFS= read -r line || [[ -n $line ]]; do
    printf '%s\n' "$line" >> "$stdin_input"
  done

  if [[ -n $output_file ]]; then
    if ! convert_by_type "$input_type" "$stdin_input" "$output_file"; then
      return 1
    fi
    printf 'Wrote %s\n' "$output_file"
  else
    if ! convert_by_type "$input_type" "$stdin_input" "$stdin_output"; then
      return 1
    fi
    print_file "$stdin_output"
  fi
}

while (($#)); do
  case $1 in
    -f|--force)
      force=true
      shift
      ;;
    -o|--output)
      if (($# < 2)); then
        fail "$1 requires an output file"
        exit 2
      fi
      output_file=$2
      shift 2
      ;;
    -t|--type|--format)
      if (($# < 2)); then
        fail "$1 requires an input type"
        exit 2
      fi
      input_type=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while (($#)); do
        files+=("$1")
        shift
      done
      ;;
    -*)
      fail "unknown option: $1"
      usage >&2
      exit 2
      ;;
    *)
      files+=("$1")
      shift
      ;;
  esac
done

if ((${#files[@]} == 0)); then
  if [[ -t 0 ]]; then
    usage >&2
    exit 2
  fi

  convert_stdin
  exit $?
fi

if [[ -n $output_file ]]; then
  fail "-o is only supported with piped input"
  exit 2
fi

status=0
for file in "${files[@]}"; do
  if ! convert_file "$file"; then
    status=1
  fi
done

exit "$status"
