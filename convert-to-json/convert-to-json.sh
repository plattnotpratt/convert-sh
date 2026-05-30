#!/usr/bin/env bash

set -u

force=false
input_type=
output_file=
files=()

CSV_FIELDS=()
record_paths=()
record_values=()
record_arrays=()
yaml_keys=()

usage() {
  printf 'Usage: %s [-f] FILE...\n' "${0##*/}"
  printf '       command | %s --type TYPE [-o OUTPUT.json]\n' "${0##*/}"
  printf '\n'
  printf 'Converts CSV, SQL-style CSV, simple YAML, and simple TOML to JSON.\n'
  printf 'Pure Bash mode intentionally supports conservative, predictable subsets.\n'
  printf '\n'
  printf 'Options:\n'
  printf '  -f, --force    overwrite existing .json output files\n'
  printf '  -o FILE        write piped conversion to FILE instead of stdout\n'
  printf '  -t, --type     input type for piped content: csv, sql, yaml, yml, or toml\n'
  printf '  -h, --help     show this help message\n'
}

fail() {
  printf 'convert-to-json: %s\n' "$1" >&2
}

trim() {
  local text=$1
  text=${text#"${text%%[!$' \t\r\n']*}"}
  text=${text%"${text##*[!$' \t\r\n']}"}
  printf '%s' "$text"
}

json_escape() {
  local text=$1
  local out= char i

  for ((i = 0; i < ${#text}; i++)); do
    char=${text:i:1}
    case $char in
      '"') out+='\\"' ;;
      '\\') out+='\\\\' ;;
      $'\b') out+='\\b' ;;
      $'\f') out+='\\f' ;;
      $'\n') out+='\\n' ;;
      $'\r') out+='\\r' ;;
      $'\t') out+='\\t' ;;
      *) out+="$char" ;;
    esac
  done

  printf '%s' "$out"
}

json_string() {
  printf '"%s"' "$(json_escape "$1")"
}

parse_csv_line() {
  local line=$1
  local field= char next in_quotes=false
  local i

  CSV_FIELDS=()
  for ((i = 0; i < ${#line}; i++)); do
    char=${line:i:1}
    if [[ $in_quotes == true ]]; then
      if [[ $char == '"' ]]; then
        next=${line:i+1:1}
        if [[ $next == '"' ]]; then
          field+='"'
          i=$((i + 1))
        else
          in_quotes=false
        fi
      else
        field+="$char"
      fi
    else
      case $char in
        '"') in_quotes=true ;;
        ',') CSV_FIELDS+=("$field"); field= ;;
        *) field+="$char" ;;
      esac
    fi
  done

  if [[ $in_quotes == true ]]; then
    return 1
  fi

  CSV_FIELDS+=("$field")
}

json_value() {
  local raw
  raw=$(trim "$1")

  if [[ -z $raw || $raw == null || $raw == NULL || $raw == Null || $raw == '~' ]]; then
    printf 'null'
  elif [[ $raw == true || $raw == false ]]; then
    printf '%s' "$raw"
  elif [[ $raw == TRUE || $raw == True ]]; then
    printf 'true'
  elif [[ $raw == FALSE || $raw == False ]]; then
    printf 'false'
  elif [[ $raw =~ ^-?[0-9]+([.][0-9]+)?([eE][+-]?[0-9]+)?$ ]]; then
    printf '%s' "$raw"
  elif [[ ${raw:0:1} == '"' && ${raw: -1} == '"' && ${#raw} -ge 2 ]]; then
    raw=${raw:1:${#raw}-2}
    raw=${raw//\\"/"}
    json_string "$raw"
  elif [[ ${raw:0:1} == "'" && ${raw: -1} == "'" && ${#raw} -ge 2 ]]; then
    json_string "${raw:1:${#raw}-2}"
  elif [[ ${raw:0:1} == '[' && ${raw: -1} == ']' ]]; then
    json_inline_array "${raw:1:${#raw}-2}"
  else
    json_string "$raw"
  fi
}

json_inline_array() {
  local inner=$1
  local i

  if ! parse_csv_line "$inner"; then
    json_string "[$inner]"
    return
  fi

  printf '['
  for ((i = 0; i < ${#CSV_FIELDS[@]}; i++)); do
    ((i > 0)) && printf ','
    json_value "${CSV_FIELDS[$i]}"
  done
  printf ']'
}

add_record() {
  record_paths+=("$1")
  record_values+=("$2")
  record_arrays+=("${3:-false}")
}

join_path() {
  local prefix=$1
  local key=$2
  if [[ -z $prefix ]]; then
    printf '%s' "$key"
  else
    printf '%s.%s' "$prefix" "$key"
  fi
}

path_parent() {
  local path=$1
  if [[ $path == *.* ]]; then
    printf '%s' "${path%.*}"
  else
    printf ''
  fi
}

path_key() {
  local path=$1
  printf '%s' "${path##*.}"
}

has_child_named() {
  local name=$1
  local item
  shift
  for item in "$@"; do
    [[ $item == "$name" ]] && return 0
  done
  return 1
}

has_scalar_record() {
  local path=$1
  local i
  for ((i = 0; i < ${#record_paths[@]}; i++)); do
    [[ ${record_paths[$i]} == "$path" && ${record_arrays[$i]} != true ]] && return 0
  done
  return 1
}

emit_indent() {
  local level=$1
  local i
  for ((i = 0; i < level; i++)); do
    printf '  '
  done
}

emit_array_records() {
  local path=$1
  local level=$2
  local i first=true

  printf '['
  for ((i = 0; i < ${#record_paths[@]}; i++)); do
    if [[ ${record_paths[$i]} == "$path" && ${record_arrays[$i]} == true ]]; then
      if [[ $first == true ]]; then
        printf '\n'
        first=false
      else
        printf ',\n'
      fi
      emit_indent $((level + 1))
      printf '%s' "${record_values[$i]}"
    fi
  done
  if [[ $first == false ]]; then
    printf '\n'
    emit_indent "$level"
  fi
  printf ']'
}

emit_object() {
  local prefix=$1
  local level=$2
  local i parent key child child_path first=true
  local children=()
  local array_children=()

  for ((i = 0; i < ${#record_paths[@]}; i++)); do
    parent=$(path_parent "${record_paths[$i]}")
    key=$(path_key "${record_paths[$i]}")
    if [[ $parent == "$prefix" && ${record_arrays[$i]} == true ]]; then
      has_child_named "$key" ${array_children[@]+"${array_children[@]}"} || array_children+=("$key")
    elif [[ $parent == "$prefix" && ${record_arrays[$i]} != true ]]; then
      :
    elif [[ -z $prefix && ${record_paths[$i]} == *.* ]]; then
      child=${record_paths[$i]%%.*}
      has_scalar_record "$child" || has_child_named "$child" ${children[@]+"${children[@]}"} || children+=("$child")
    elif [[ -n $prefix && ${record_paths[$i]} == "$prefix".*.* ]]; then
      child=${record_paths[$i]#"$prefix".}
      child=${child%%.*}
      child_path=$(join_path "$prefix" "$child")
      has_scalar_record "$child_path" || has_child_named "$child" ${children[@]+"${children[@]}"} || children+=("$child")
    fi
  done

  printf '{'

  for ((i = 0; i < ${#record_paths[@]}; i++)); do
    parent=$(path_parent "${record_paths[$i]}")
    key=$(path_key "${record_paths[$i]}")
    if [[ $parent == "$prefix" && ${record_arrays[$i]} != true ]]; then
      if [[ $first == true ]]; then printf '\n'; first=false; else printf ',\n'; fi
      emit_indent $((level + 1))
      json_string "$key"
      printf ': %s' "${record_values[$i]}"
    fi
  done

  for child in ${array_children[@]+"${array_children[@]}"}; do
    if [[ $first == true ]]; then printf '\n'; first=false; else printf ',\n'; fi
    emit_indent $((level + 1))
    json_string "$child"
    printf ': '
    emit_array_records "$(join_path "$prefix" "$child")" $((level + 1))
  done

  for child in ${children[@]+"${children[@]}"}; do
    if [[ $first == true ]]; then printf '\n'; first=false; else printf ',\n'; fi
    emit_indent $((level + 1))
    json_string "$child"
    printf ': '
    emit_object "$(join_path "$prefix" "$child")" $((level + 1))
  done

  if [[ $first == false ]]; then
    printf '\n'
    emit_indent "$level"
  fi
  printf '}'
}

convert_csv() {
  local input=$1
  local output=$2
  local line first=true row=0 i
  local headers=()

  : > "$output"
  printf '[' >> "$output"

  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    [[ -z $line ]] && continue
    if ! parse_csv_line "$line"; then
      fail "unterminated quoted CSV field on row $((row + 1))"
      return 1
    fi

    if ((row == 0)); then
      headers=("${CSV_FIELDS[@]}")
      row=$((row + 1))
      continue
    fi

    if [[ $first == true ]]; then
      printf '\n' >> "$output"
      first=false
    else
      printf ',\n' >> "$output"
    fi

    printf '  {' >> "$output"
    for ((i = 0; i < ${#headers[@]}; i++)); do
      ((i > 0)) && printf ',' >> "$output"
      printf '\n    ' >> "$output"
      json_string "$(trim "${headers[$i]}")" >> "$output"
      printf ': ' >> "$output"
      json_value "${CSV_FIELDS[$i]:-}" >> "$output"
    done
    printf '\n  }' >> "$output"
    row=$((row + 1))
  done < "$input"

  if ((row == 0)); then
    fail "CSV input is missing a header row"
    return 1
  fi

  [[ $first == false ]] && printf '\n' >> "$output"
  printf ']\n' >> "$output"
}

yaml_prefix_for_indent() {
  local indent=$1
  local prefix= key level

  for ((level = 0; level < indent; level += 2)); do
    key=${yaml_keys[$level]:-}
    [[ -n $key ]] || continue
    prefix=$(join_path "$prefix" "$key")
  done
  printf '%s' "$prefix"
}

convert_yaml() {
  local input=$1
  local output=$2
  local line raw indent content key value prefix path level

  record_paths=()
  record_values=()
  record_arrays=()
  yaml_keys=()

  while IFS= read -r raw || [[ -n $raw ]]; do
    raw=${raw%$'\r'}
    line=$(trim "$raw")
    [[ -z $line || ${line:0:1} == '#' ]] && continue
    [[ $raw =~ ^([[:space:]]*) ]] || return 1
    indent=${#BASH_REMATCH[1]}
    content=${raw:$indent}

    if ((indent % 2 != 0)); then
      fail "YAML indentation must use two-space levels: $raw"
      return 1
    fi

    for ((level = indent + 2; level < ${#yaml_keys[@]}; level += 2)); do
      yaml_keys[$level]=
    done

    if [[ $content == '- '* ]]; then
      prefix=$(yaml_prefix_for_indent "$indent")
      if [[ -z $prefix ]]; then
        fail "top-level YAML arrays are not supported"
        return 1
      fi
      value=${content:2}
      add_record "$prefix" "$(json_value "$value")" true
    elif [[ $content == *:* ]]; then
      key=${content%%:*}
      value=${content#*:}
      key=$(trim "$key")
      value=$(trim "$value")
      if [[ -z $key ]]; then
        fail "empty YAML key: $raw"
        return 1
      fi
      prefix=$(yaml_prefix_for_indent "$indent")
      path=$(join_path "$prefix" "$key")
      if [[ -z $value ]]; then
        yaml_keys[$indent]=$key
      else
        add_record "$path" "$(json_value "$value")" false
      fi
    else
      fail "unsupported YAML line: $raw"
      return 1
    fi
  done < "$input"

  emit_object '' 0 > "$output"
  printf '\n' >> "$output"
}

convert_toml() {
  local input=$1
  local output=$2
  local raw line section key value path

  record_paths=()
  record_values=()
  record_arrays=()
  section=

  while IFS= read -r raw || [[ -n $raw ]]; do
    raw=${raw%$'\r'}
    line=$(trim "$raw")
    [[ -z $line || ${line:0:1} == '#' ]] && continue

    if [[ ${line:0:1} == '[' && ${line: -1} == ']' ]]; then
      section=$(trim "${line:1:${#line}-2}")
      continue
    fi

    if [[ $line != *=* ]]; then
      fail "unsupported TOML line: $raw"
      return 1
    fi

    key=$(trim "${line%%=*}")
    value=$(trim "${line#*=}")
    [[ -n $key ]] || { fail "empty TOML key: $raw"; return 1; }
    path=$(join_path "$section" "$key")
    add_record "$path" "$(json_value "$value")" false
  done < "$input"

  emit_object '' 0 > "$output"
  printf '\n' >> "$output"
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
  output="$base.json"

  if [[ $input == "$base" ]]; then
    fail "missing file extension: $input"
    return 1
  fi

  if [[ -e $output && $force != true ]]; then
    fail "refusing to overwrite existing file: $output (use -f to overwrite)"
    return 1
  fi

  case $ext in
    [Cc][Ss][Vv]|[Ss][Qq][Ll]) convert_csv "$input" "$output" ;;
    [Yy][Aa][Mm][Ll]|[Yy][Mm][Ll]) convert_yaml "$input" "$output" ;;
    [Tt][Oo][Mm][Ll]) convert_toml "$input" "$output" ;;
    *) fail "unsupported file extension: .$ext ($input)"; return 1 ;;
  esac

  printf 'Wrote %s\n' "$output"
}

convert_by_type() {
  local type=$1
  local input=$2
  local output=$3

  case $type in
    [Cc][Ss][Vv]|[Ss][Qq][Ll]) convert_csv "$input" "$output" ;;
    [Yy][Aa][Mm][Ll]|[Yy][Mm][Ll]) convert_yaml "$input" "$output" ;;
    [Tt][Oo][Mm][Ll]) convert_toml "$input" "$output" ;;
    *) fail "unsupported input type for piped input: $type"; return 1 ;;
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
    fail "piped input requires --type csv, --type sql, --type yaml, --type yml, or --type toml"
    return 2
  fi

  if [[ -n $output_file && -e $output_file && $force != true ]]; then
    fail "refusing to overwrite existing file: $output_file (use -f to overwrite)"
    return 1
  fi

  stdin_input="${TMPDIR:-/tmp}/convert-to-json-input.$$"
  stdin_output="${TMPDIR:-/tmp}/convert-to-json-output.$$"
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
    -f|--force) force=true; shift ;;
    -o|--output)
      if (($# < 2)); then fail "$1 requires an output file"; exit 2; fi
      output_file=$2
      shift 2
      ;;
    -t|--type|--format)
      if (($# < 2)); then fail "$1 requires an input type"; exit 2; fi
      input_type=$2
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    --)
      shift
      while (($#)); do files+=("$1"); shift; done
      ;;
    -*) fail "unknown option: $1"; usage >&2; exit 2 ;;
    *) files+=("$1"); shift ;;
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
