# Manages Status columns of a GitHub project (create / reorder / recolor)
#
# Usage:
#   create_project_column    PROJECT=<url> NAME="M68 (Jul27 - Aug09)" [COLOR=BLUE] [AFTER="Backlogs"|BEFORE="In Progress"]
#   move_project_column      PROJECT=<url> COLUMN="M67" AFTER="Done"
#   set_project_column_color PROJECT=<url> COLUMN="M67" COLOR=PURPLE
#   create_next_milestone    PROJECT=<url> [COLOR=GREEN]
#   deprecate_old_milestone  PROJECT=<url>
#
# Milestone columns are "M<n> (MonDD - MonDD)" and rank by <n>. The two helpers
# drive a two-week cycle:
#   create_next_milestone   inserts the upcoming milestone (GREEN) directly
#                           before the newest existing one.
#   deprecate_old_milestone retires the previous milestone (PURPLE, parked after
#                           "Done") and promotes the newest to active (BLUE).
#
# All accept DRY_RUN=true to preview and YES=true to skip confirmation.

_PC_COLORS="GRAY BLUE GREEN YELLOW ORANGE RED PINK PURPLE"

_pc_quiet() {
  trap '' DEBUG 2>/dev/null || true
  if typeset -f TRAPDEBUG >/dev/null 2>&1; then
    unfunction TRAPDEBUG 2>/dev/null || true
  fi
  if [[ -o xtrace ]] 2>/dev/null; then
    unsetopt xtrace 2>/dev/null || true
  fi
  set +x 2>/dev/null || true
}

_pc_arg() {
  local key="$1"
  shift
  for arg in "$@"; do
    if [[ "$arg" == "$key="* ]]; then
      echo "${arg#$key=}"
      return 0
    fi
  done
  echo ""
}

# Splits a project URL into "OWNER_TYPE OWNER NUMBER"
_pc_parse_url() {
  local url="$1" kind owner number
  local pattern='github\.com/(orgs|users)/([^/]+)/projects/([0-9]+)'
  if [[ "$url" =~ $pattern ]]; then
    if [[ -n "${match[1]}" ]]; then
      kind="${match[1]}"; owner="${match[2]}"; number="${match[3]}"
    else
      kind="${BASH_REMATCH[1]}"; owner="${BASH_REMATCH[2]}"; number="${BASH_REMATCH[3]}"
    fi
  else
    return 1
  fi
  [[ "$kind" == "orgs" ]] && echo "organization $owner $number" || echo "user $owner $number"
}

# Fetches project id, Status field id and its options; echoes a JSON blob
_pc_resolve() {
  local url="$1" parsed root owner number query data
  parsed=$(_pc_parse_url "$url") || {
    echo "❌ Error: Invalid project URL. Expected https://github.com/orgs/<org>/projects/<n> or .../users/<user>/projects/<n>" >&2
    return 1
  }
  root="${parsed%% *}"; parsed="${parsed#* }"
  owner="${parsed%% *}"; number="${parsed#* }"

  query="query(\$owner: String!, \$number: Int!) {
    $root(login: \$owner) {
      projectV2(number: \$number) {
        id
        title
        field(name: \"Status\") {
          ... on ProjectV2SingleSelectField {
            id
            options { id name color description }
          }
        }
      }
    }
  }"

  local body_file=$(mktemp)
  jq -n --arg q "$query" --arg owner "$owner" --argjson number "$number" \
    '{query: $q, variables: {owner: $owner, number: $number}}' > "$body_file"
  data=$(gh api graphql --input "$body_file" 2>&1)
  local exit_code=$?
  rm -f "$body_file"

  local err=$(echo "$data" | jq -r '.errors[0].message' 2>/dev/null)
  if [[ -n "$err" && "$err" != "null" ]]; then
    echo "❌ Error: $err" >&2
    return 1
  fi

  if [[ $exit_code -ne 0 ]]; then
    echo "❌ Error: GraphQL request failed: ${data:0:300}" >&2
    return 1
  fi

  local blob=$(echo "$data" | jq -c ".data.$root.projectV2 | {id, title, fieldId: .field.id, options: .field.options}" 2>/dev/null)
  if [[ -z "$blob" || "$(echo "$blob" | jq -r '.id')" == "null" ]]; then
    echo "❌ Error: Could not find project $number for $owner" >&2
    return 1
  fi
  if [[ "$(echo "$blob" | jq -r '.fieldId')" == "null" ]]; then
    echo "❌ Error: Project has no single-select 'Status' field" >&2
    return 1
  fi
  echo "$blob"
}

# Finds an option index by name: case-insensitive exact match, then substring
_pc_find_index() {
  local col_opts="$1" pattern="$2"
  local lower=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')
  local idx=$(echo "$col_opts" | jq --arg p "$lower" 'map(.name | ascii_downcase) | index($p) // empty')
  if [[ -z "$idx" ]]; then
    idx=$(echo "$col_opts" | jq --arg p "$lower" \
      'to_entries | map(select(.value.name | ascii_downcase | contains($p))) | first | .key // empty')
  fi
  [[ -z "$idx" ]] && return 1
  echo "$idx"
}

_pc_validate_color() {
  local color=$(echo "$1" | tr '[:lower:]' '[:upper:]')
  if [[ " $_PC_COLORS " != *" $color "* ]]; then
    echo "❌ Error: Invalid color '$1'. Valid: $_PC_COLORS" >&2
    return 1
  fi
  echo "$color"
}

_pc_print_columns() {
  echo "$1" | jq -r 'to_entries[] | "   \(.key + 1). \(.value.name) [\(.value.color)]\(if .value.id then "" else "  ← new" end)"'
}

# Writes the option list back; refuses to drop any existing option
_pc_write() {
  local field_id="$1" before="$2" after="$3" dry_run="$4" assume_yes="$5"

  if ! echo "$after" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1; then
    echo "❌ Error: refusing to write — computed column list is empty or malformed" >&2
    return 1
  fi

  local missing
  missing=$(jq -rn --argjson before "$before" --argjson after "$after" \
    '[$before[].id] - [$after[] | select(.id) | .id] | join(", ")') || {
    echo "❌ Error: refusing to write — could not verify column list integrity" >&2
    return 1
  }
  if [[ -n "$missing" ]]; then
    echo "❌ Error: refusing to write — payload would delete existing column(s): $missing" >&2
    return 1
  fi

  echo ""
  echo "📐 Resulting column order:"
  _pc_print_columns "$after"
  echo ""

  if [[ "$dry_run" == "true" ]]; then
    echo "🔎 DRY_RUN=true — no changes written."
    return 0
  fi

  if [[ "$assume_yes" != "true" ]]; then
    echo -n "Apply these changes? [y/N] "
    local answer
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
      echo "🚫 Aborted."
      return 1
    fi
  fi

  local mutation='mutation($fieldId: ID!, $options: [ProjectV2SingleSelectFieldOptionInput!]) {
    updateProjectV2Field(input: {fieldId: $fieldId, singleSelectOptions: $options}) {
      projectV2Field { ... on ProjectV2SingleSelectField { options { id name color } } }
    }
  }'

  local body_file=$(mktemp)
  jq -n --arg q "$mutation" --arg fieldId "$field_id" --argjson options "$after" \
    '{query: $q, variables: {fieldId: $fieldId, options: $options}}' > "$body_file"
  local result exit_code
  result=$(gh api graphql --input "$body_file" 2>&1)
  exit_code=$?
  rm -f "$body_file"

  local err=$(echo "$result" | jq -r '.errors[0].message' 2>/dev/null)
  if [[ -n "$err" && "$err" != "null" ]]; then
    echo "❌ Error: $err" >&2
    return 1
  fi
  if [[ $exit_code -ne 0 ]]; then
    echo "❌ Error: mutation failed: ${result:0:300}" >&2
    return 1
  fi

  echo "✨ Columns updated."
}

# Computes the destination index from AFTER=/BEFORE=, defaulting to end of list
_pc_target_index() {
  local col_opts="$1" after="$2" before="$3" idx
  if [[ -n "$after" ]]; then
    idx=$(_pc_find_index "$col_opts" "$after") || {
      echo "❌ Error: Could not find column matching AFTER='$after'" >&2
      return 1
    }
    echo $((idx + 1))
  elif [[ -n "$before" ]]; then
    idx=$(_pc_find_index "$col_opts" "$before") || {
      echo "❌ Error: Could not find column matching BEFORE='$before'" >&2
      return 1
    }
    echo "$idx"
  else
    echo "$col_opts" | jq 'length'
  fi
}

create_project_column() {
  _pc_quiet
  local project=$(_pc_arg PROJECT "$@")
  local name=$(_pc_arg NAME "$@")
  local color=$(_pc_arg COLOR "$@")
  local after=$(_pc_arg AFTER "$@")
  local before=$(_pc_arg BEFORE "$@")
  local dry_run=$(_pc_arg DRY_RUN "$@")
  local assume_yes=$(_pc_arg YES "$@")

  if [[ -z "$project" || -z "$name" ]]; then
    echo "❌ Error: Missing required arguments"
    echo "Usage: create_project_column PROJECT=<url> NAME=\"<column>\" [COLOR=BLUE] [AFTER=\"<column>\"|BEFORE=\"<column>\"]"
    return 1
  fi

  color=$(_pc_validate_color "${color:-GRAY}") || return 1

  local blob
  blob=$(_pc_resolve "$project") || return 1
  local field_id=$(echo "$blob" | jq -r '.fieldId')
  local col_opts=$(echo "$blob" | jq -c '.options')
  echo "✅ Found project: $(echo "$blob" | jq -r '.title')"

  if echo "$col_opts" | jq -e --arg n "$name" 'any(.name == $n)' >/dev/null; then
    echo "❌ Error: A column named '$name' already exists"
    return 1
  fi

  local at
  at=$(_pc_target_index "$col_opts" "$after" "$before") || return 1

  local updated=$(jq -n --argjson o "$col_opts" --argjson at "$at" \
    --arg name "$name" --arg color "$color" \
    '$o[:$at] + [{name: $name, color: $color, description: ""}] + $o[$at:]')

  echo "➕ Creating column '$name' [$color] at position $((at + 1))"
  _pc_write "$field_id" "$col_opts" "$updated" "$dry_run" "$assume_yes"
}

move_project_column() {
  _pc_quiet
  local project=$(_pc_arg PROJECT "$@")
  local column=$(_pc_arg COLUMN "$@")
  local after=$(_pc_arg AFTER "$@")
  local before=$(_pc_arg BEFORE "$@")
  local dry_run=$(_pc_arg DRY_RUN "$@")
  local assume_yes=$(_pc_arg YES "$@")

  if [[ -z "$project" || -z "$column" ]] || [[ -z "$after" && -z "$before" ]]; then
    echo "❌ Error: Missing required arguments"
    echo "Usage: move_project_column PROJECT=<url> COLUMN=\"<column>\" AFTER=\"<column>\"|BEFORE=\"<column>\""
    return 1
  fi

  local blob
  blob=$(_pc_resolve "$project") || return 1
  local field_id=$(echo "$blob" | jq -r '.fieldId')
  local col_opts=$(echo "$blob" | jq -c '.options')
  echo "✅ Found project: $(echo "$blob" | jq -r '.title')"

  local from
  from=$(_pc_find_index "$col_opts" "$column") || {
    echo "❌ Error: Could not find column matching '$column'"
    return 1
  }
  local moved_name=$(echo "$col_opts" | jq -r ".[$from].name")

  # Resolve the anchor against the list without the moved column, so the
  # target index is not skewed by its own removal.
  local remaining=$(echo "$col_opts" | jq -c "del(.[$from])")
  local at
  at=$(_pc_target_index "$remaining" "$after" "$before") || return 1

  local updated=$(jq -n --argjson o "$col_opts" --argjson from "$from" --argjson at "$at" \
    '($o[$from]) as $item | ($o | del(.[$from])) as $rest | $rest[:$at] + [$item] + $rest[$at:]')

  echo "🔀 Moving column '$moved_name' to position $((at + 1))"
  _pc_write "$field_id" "$col_opts" "$updated" "$dry_run" "$assume_yes"
}

set_project_column_color() {
  _pc_quiet
  local project=$(_pc_arg PROJECT "$@")
  local column=$(_pc_arg COLUMN "$@")
  local color=$(_pc_arg COLOR "$@")
  local dry_run=$(_pc_arg DRY_RUN "$@")
  local assume_yes=$(_pc_arg YES "$@")

  if [[ -z "$project" || -z "$column" || -z "$color" ]]; then
    echo "❌ Error: Missing required arguments"
    echo "Usage: set_project_column_color PROJECT=<url> COLUMN=\"<column>\" COLOR=<$(echo $_PC_COLORS | tr ' ' '|')>"
    return 1
  fi

  color=$(_pc_validate_color "$color") || return 1

  local blob
  blob=$(_pc_resolve "$project") || return 1
  local field_id=$(echo "$blob" | jq -r '.fieldId')
  local col_opts=$(echo "$blob" | jq -c '.options')
  echo "✅ Found project: $(echo "$blob" | jq -r '.title')"

  local idx
  idx=$(_pc_find_index "$col_opts" "$column") || {
    echo "❌ Error: Could not find column matching '$column'"
    return 1
  }
  local target_name=$(echo "$col_opts" | jq -r ".[$idx].name")

  local updated=$(echo "$col_opts" | jq -c --arg c "$color" "[.[] | .] | .[$idx].color = \$c")

  echo "🎨 Recoloring '$target_name' → $color"
  _pc_write "$field_id" "$col_opts" "$updated" "$dry_run" "$assume_yes"
}

# Derives the milestone that follows "M67 (Jul13 - Jul26)" → "M68 (Jul27 - Aug09)"
_pc_next_milestone() {
  local current="$1" num start_md end_md
  local pattern='^M([0-9]+)[[:space:]]*\(([A-Za-z]{3}[0-9]{2})[[:space:]]*-[[:space:]]*([A-Za-z]{3}[0-9]{2})\)$'
  if [[ "$current" =~ $pattern ]]; then
    if [[ -n "${match[1]}" ]]; then
      num="${match[1]}"; start_md="${match[2]}"; end_md="${match[3]}"
    else
      num="${BASH_REMATCH[1]}"; start_md="${BASH_REMATCH[2]}"; end_md="${BASH_REMATCH[3]}"
    fi
  else
    echo "❌ Error: '$current' does not match the expected 'M<n> (MonDD - MonDD)' pattern" >&2
    return 1
  fi

  # The name carries no year, so anchor the end date to whichever candidate
  # year lands nearest today; that also covers Dec→Jan spans.
  local today=$(date "+%Y-%m-%d")
  local this_year=$(date "+%Y")
  local best="" best_delta=""
  local y candidate delta
  for y in $((this_year - 1)) "$this_year" $((this_year + 1)); do
    candidate=$(date -j -f "%Y %b%d %H:%M:%S" "$y $end_md 00:00:00" "+%Y-%m-%d" 2>/dev/null) || continue
    delta=$(( ($(date -j -f "%Y-%m-%d %H:%M:%S" "$candidate 00:00:00" "+%s") - $(date -j -f "%Y-%m-%d %H:%M:%S" "$today 00:00:00" "+%s")) ))
    [[ $delta -lt 0 ]] && delta=$((-delta))
    if [[ -z "$best_delta" || $delta -lt $best_delta ]]; then
      best="$candidate"; best_delta=$delta
    fi
  done

  if [[ -z "$best" ]]; then
    echo "❌ Error: Could not parse date '$end_md' from '$current'" >&2
    return 1
  fi

  local new_start=$(date -j -v+1d -f "%Y-%m-%d %H:%M:%S" "$best 00:00:00" "+%b%d")
  local new_end=$(date -j -v+14d -f "%Y-%m-%d %H:%M:%S" "$best 00:00:00" "+%b%d")
  echo "M$((num + 1)) ($new_start - $new_end)"
}

create_next_milestone() {
  _pc_quiet
  local project=$(_pc_arg PROJECT "$@")
  local color=$(_pc_arg COLOR "$@")
  local dry_run=$(_pc_arg DRY_RUN "$@")
  local assume_yes=$(_pc_arg YES "$@")

  if [[ -z "$project" ]]; then
    echo "❌ Error: Missing required arguments"
    echo "Usage: create_next_milestone PROJECT=<url> [COLOR=GREEN] [DRY_RUN=true] [YES=true]"
    return 1
  fi

  if [[ -n "$color" ]]; then
    color=$(_pc_validate_color "$color") || return 1
  fi

  local blob
  blob=$(_pc_resolve "$project") || return 1
  local field_id=$(echo "$blob" | jq -r '.fieldId')
  local col_opts=$(echo "$blob" | jq -c '.options')
  echo "✅ Found project: $(echo "$blob" | jq -r '.title')"

  # The latest milestone is the highest-numbered M<n> column, wherever it sits.
  local at=$(echo "$col_opts" | jq 'to_entries
    | map(select(.value.name | test("^M[0-9]+ ")))
    | max_by(.value.name | capture("^M(?<n>[0-9]+) ") | .n | tonumber)
    | .key // empty')
  if [[ -z "$at" ]]; then
    echo "❌ Error: No milestone column matching 'M<n> (MonDD - MonDD)' found"
    return 1
  fi

  local current_name=$(echo "$col_opts" | jq -r ".[$at].name")
  local next_name
  next_name=$(_pc_next_milestone "$current_name") || return 1

  if echo "$col_opts" | jq -e --arg n "$next_name" 'any(.name == $n)' >/dev/null; then
    echo "❌ Error: '$next_name' already exists"
    return 1
  fi

  : ${color:=GREEN}

  echo "➕ Creating '$next_name' [$color] before '$current_name' at position $((at + 1))"

  local updated=$(jq -n --argjson o "$col_opts" --argjson at "$at" \
    --arg newName "$next_name" --arg color "$color" \
    '$o[:$at] + [{name: $newName, color: $color, description: ""}] + $o[$at:]')

  _pc_write "$field_id" "$col_opts" "$updated" "$dry_run" "$assume_yes"
}

deprecate_old_milestone() {
  _pc_quiet
  local project=$(_pc_arg PROJECT "$@")
  local dry_run=$(_pc_arg DRY_RUN "$@")
  local assume_yes=$(_pc_arg YES "$@")

  if [[ -z "$project" ]]; then
    echo "❌ Error: Missing required arguments"
    echo "Usage: deprecate_old_milestone PROJECT=<url> [DRY_RUN=true] [YES=true]"
    return 1
  fi

  local blob
  blob=$(_pc_resolve "$project") || return 1
  local field_id=$(echo "$blob" | jq -r '.fieldId')
  local col_opts=$(echo "$blob" | jq -c '.options')
  echo "✅ Found project: $(echo "$blob" | jq -r '.title')"

  # Milestone columns ranked by number, newest first: [0] is current, [1] is the
  # one it supersedes.
  local ranked=$(echo "$col_opts" | jq -c 'to_entries
    | map(select(.value.name | test("^M[0-9]+ ")))
    | sort_by(.value.name | capture("^M(?<n>[0-9]+) ") | .n | tonumber)
    | reverse')
  local milestone_count=$(echo "$ranked" | jq 'length')
  if [[ "$milestone_count" -lt 2 ]]; then
    echo "❌ Error: need at least 2 milestone columns to deprecate one, found $milestone_count"
    return 1
  fi

  local cur_idx=$(echo "$ranked" | jq '.[0].key')
  local old_idx=$(echo "$ranked" | jq '.[1].key')
  local cur_name=$(echo "$ranked" | jq -r '.[0].value.name')
  local old_name=$(echo "$ranked" | jq -r '.[1].value.name')

  # Locate Done on the list with the retired column already removed, so the
  # index matches the one jq splices against below.
  local remaining=$(echo "$col_opts" | jq -c "del(.[$old_idx])")
  local done_idx
  done_idx=$(_pc_find_index "$remaining" "Done") || {
    echo "❌ Error: Could not find a 'Done' column to park '$old_name' after"
    return 1
  }

  echo "📦 Deprecating '$old_name' → PURPLE, parked after 'Done'"
  echo "🔵 Promoting '$cur_name' → BLUE"

  local updated=$(jq -n --argjson o "$col_opts" --argjson curIdx "$cur_idx" \
    --argjson oldIdx "$old_idx" --argjson doneIdx "$done_idx" \
    '($o | .[$curIdx].color = "BLUE") as $promoted
     | ($promoted[$oldIdx] | .color = "PURPLE") as $aged
     | ($promoted | del(.[$oldIdx])) as $rest
     | $rest[:$doneIdx + 1] + [$aged] + $rest[$doneIdx + 1:]')

  _pc_write "$field_id" "$col_opts" "$updated" "$dry_run" "$assume_yes"
}
