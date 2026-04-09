# Creates a pull request with automatic issue linking and opens it in browser
sendpr() {
  REPO_NAME=$(basename $(pwd))
  ISSUE=$(git branch --show-current | cut -d "-" -f 1)
  BODY=" "
  if [[ $ISSUE =~ '^[0-9]+$' ]] ;then
    BODY="fixes #${ISSUE}"
  fi
  ggp --no-verify
  if [[ "$REPO_NAME" != *web* ]]; then
    gh pr create --fill-first --body "$BODY" --label "patch"
  else
    gh pr create --fill-first --body "$BODY"
  fi
  gh pr view --web
  commitlog
}

# Generates and displays a formatted commit log for the current branch
commitlog() {
  ISSUE=$(git branch --show-current | cut -d "-" -f 1)
  if [[ $ISSUE == 'main' || $ISSUE == 'production' ]]; then
    return 42
  fi

  REPO_NAME=$(basename $(pwd))
  COMMITLOG=$(git shortlog --no-merges main..$(git branch --show-current) | sed 1d)
  COMMITLOG=$(echo $COMMITLOG | sed 's/^[[:space:]]*/- /')
  COLOR="\033[1;33m"
  echo "\n"
  echo "${COLOR}NeetoInvoice logs:\n"

  if [[ $ISSUE =~ '^[0-9]+$' ]]; then
    echo "${COLOR}${REPO_NAME} - #${ISSUE}"
  fi
  echo "${COLOR}${COMMITLOG}"
  echo "\n\n"
}

# Moves all issues from one column to another in a GitHub project
# Usage: move_project_items PROJECT=https://github.com/orgs/neetozone/projects/17 SOURCE="Done" DESTINATION="M54"
move_project_items() {
  # Disable DEBUG trap and tracing to suppress debug output
  # DEBUG traps in zsh can cause trace-like output even when set -x is disabled
  trap '' DEBUG 2>/dev/null || true
  if typeset -f TRAPDEBUG >/dev/null 2>&1; then
    unfunction TRAPDEBUG 2>/dev/null || true
  fi
  
  # Disable zsh tracing options
  if [[ -o xtrace ]] 2>/dev/null; then
    unsetopt xtrace 2>/dev/null || true
  fi
  set +x 2>/dev/null || true
  
  # Parse arguments
  local PROJECT=""
  local SOURCE=""
  local DESTINATION=""
  
  for arg in "$@"; do
    case $arg in
      PROJECT=*)
        PROJECT="${arg#PROJECT=}"
        ;;
      SOURCE=*)
        SOURCE="${arg#SOURCE=}"
        ;;
      DESTINATION=*)
        DESTINATION="${arg#DESTINATION=}"
        ;;
    esac
  done
  
  # Validate required arguments
  if [[ -z "$PROJECT" || -z "$SOURCE" || -z "$DESTINATION" ]]; then
    echo "❌ Error: Missing required arguments"
    echo "Usage: move_project_items PROJECT=<url> SOURCE=\"<column_name>\" DESTINATION=\"<column_name>\""
    return 1
  fi
  
  # Extract organization and project number from URL
  # URL format: https://github.com/orgs/neetozone/projects/17
  if [[ "$PROJECT" =~ github\.com/orgs/([^/]+)/projects/([0-9]+) ]]; then
    # zsh uses $match, bash uses $BASH_REMATCH
    if [[ -n "${match[1]}" ]]; then
      local ORG="${match[1]}"
      local PROJECT_NUMBER="${match[2]}"
    else
      local ORG="${BASH_REMATCH[1]}"
      local PROJECT_NUMBER="${BASH_REMATCH[2]}"
    fi
  else
    echo "❌ Error: Invalid project URL format. Expected: https://github.com/orgs/<org>/projects/<number>"
    return 1
  fi
  
  echo "📋 Moving items from '$SOURCE' to '$DESTINATION' in project #$PROJECT_NUMBER ($ORG)"
  
  # Get project ID using GraphQL
  local PROJECT_QUERY=$(cat <<EOF
query {
  organization(login: "$ORG") {
    projectV2(number: $PROJECT_NUMBER) {
      id
      title
      fields(first: 20) {
        nodes {
          ... on ProjectV2Field {
            id
            name
          }
          ... on ProjectV2SingleSelectField {
            id
            name
            options {
              id
              name
            }
          }
        }
      }
    }
  }
}
EOF
)
  
  local PROJECT_DATA=$(gh api graphql -f query="$PROJECT_QUERY")
  local PROJECT_ID=$(echo "$PROJECT_DATA" | jq -r '.data.organization.projectV2.id')
  
  if [[ "$PROJECT_ID" == "null" || -z "$PROJECT_ID" ]]; then
    echo "❌ Error: Could not find project #$PROJECT_NUMBER in organization $ORG"
    return 1
  fi
  
  local PROJECT_TITLE=$(echo "$PROJECT_DATA" | jq -r '.data.organization.projectV2.title')
  echo "✅ Found project: $PROJECT_TITLE"
  
  # Find the status field and get source/destination option IDs
  local STATUS_FIELD_ID=$(echo "$PROJECT_DATA" | jq -r '.data.organization.projectV2.fields.nodes[] | select(.name == "Status") | .id')
  
  if [[ "$STATUS_FIELD_ID" == "null" || -z "$STATUS_FIELD_ID" ]]; then
    echo "❌ Error: Could not find 'Status' field in project"
    return 1
  fi
  
  # Helper function to find column option ID with case-insensitive and regex matching
  # Returns: "OPTION_ID|ACTUAL_COLUMN_NAME" or empty string if not found
  find_column_option() {
    local search_pattern="$1"
    local options_json=$(echo "$PROJECT_DATA" | jq -c ".data.organization.projectV2.fields.nodes[] | select(.name == \"Status\") | .options[]")
    
    # Convert search pattern to lowercase for comparison
    local search_lower=$(echo "$search_pattern" | tr '[:upper:]' '[:lower:]')
    
    # First, try case-insensitive exact match
    while IFS= read -r option; do
      local option_name=$(echo "$option" | jq -r '.name')
      local option_id=$(echo "$option" | jq -r '.id')
      local option_lower=$(echo "$option_name" | tr '[:upper:]' '[:lower:]')
      
      # Case-insensitive exact match
      if [[ "$option_lower" == "$search_lower" ]]; then
        echo "${option_id}|${option_name}"
        return 0
      fi
    done <<< "$options_json"
    
    # If no exact match, try case-insensitive regex match
    while IFS= read -r option; do
      local option_name=$(echo "$option" | jq -r '.name')
      local option_id=$(echo "$option" | jq -r '.id')
      local option_lower=$(echo "$option_name" | tr '[:upper:]' '[:lower:]')
      
      # Case-insensitive regex match
      if [[ "$option_lower" =~ $search_lower ]]; then
        echo "${option_id}|${option_name}"
        return 0
      fi
    done <<< "$options_json"
    
    # Not found
    return 1
  }
  
  # Find source column
  local SOURCE_MATCH=$(find_column_option "$SOURCE")
  if [[ -z "$SOURCE_MATCH" ]]; then
    echo "❌ Error: Could not find source column matching '$SOURCE'"
    return 1
  fi
  local SOURCE_OPTION_ID="${SOURCE_MATCH%%|*}"
  local SOURCE_ACTUAL_NAME="${SOURCE_MATCH#*|}"
  echo "✅ Found source column: '$SOURCE_ACTUAL_NAME' (matched pattern: '$SOURCE')"
  
  # Find destination column
  local DEST_MATCH=$(find_column_option "$DESTINATION")
  if [[ -z "$DEST_MATCH" ]]; then
    echo "❌ Error: Could not find destination column matching '$DESTINATION'"
    return 1
  fi
  local DEST_OPTION_ID="${DEST_MATCH%%|*}"
  local DEST_ACTUAL_NAME="${DEST_MATCH#*|}"
  echo "✅ Found destination column: '$DEST_ACTUAL_NAME' (matched pattern: '$DESTINATION')"
  
  # Get all items in the project to find source column items
  # Note: GitHub Projects v2 API doesn't support filtering by status in queries,
  # so we must fetch all items and filter client-side
  # Note: If shell tracing (set -x) is enabled, you'll see ITEMS_QUERY trace output.
  #       This cannot be suppressed from within the function. To avoid it, run:
  #       (set +x; move_project_items PROJECT=... SOURCE="..." DESTINATION="...")
  local ITEMS_IN_SOURCE=""
  local HAS_NEXT_PAGE=true
  local CURSOR=""
  local PAGE_COUNT=0
  local MAX_PAGES=50  # Safety limit: 50 pages = 5,000 items max (100 items per page)
  
  echo -n "🔍 Searching for items in column '$SOURCE_ACTUAL_NAME': "
  
  while [[ "$HAS_NEXT_PAGE" == "true" ]]; do
    ((PAGE_COUNT++))
    if [[ $PAGE_COUNT -gt $MAX_PAGES ]]; then
      echo ""
      echo "⚠️  Warning: Reached maximum page limit ($MAX_PAGES pages = $((MAX_PAGES * 100)) items)."
      echo "   Some items may not have been checked. Consider increasing MAX_PAGES if needed."
      break
    fi
    
    # Show progress dot for each page
    echo -n "."
    
    # Build GraphQL query in temporary file to avoid trace output
    local QUERY_FILE=$(mktemp)
    if [[ -n "$CURSOR" ]]; then
      cat > "$QUERY_FILE" <<EOF
query {
  node(id: "$PROJECT_ID") {
    ... on ProjectV2 {
      items(first: 100, after: "$CURSOR") {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                field {
                  ... on ProjectV2FieldCommon {
                    name
                  }
                }
                name
              }
            }
          }
        }
      }
    }
  }
}
EOF
    else
      cat > "$QUERY_FILE" <<EOF
query {
  node(id: "$PROJECT_ID") {
    ... on ProjectV2 {
      items(first: 100) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                field {
                  ... on ProjectV2FieldCommon {
                    name
                  }
                }
                name
              }
            }
          }
        }
      }
    }
  }
}
EOF
    fi
    
    # Read query from file and execute gh api
    # Write output to temp file to avoid variable assignment tracing
    local RESPONSE_FILE=$(mktemp)
    local ERROR_FILE=$(mktemp)
    gh api graphql -f query="$(cat "$QUERY_FILE")" > "$RESPONSE_FILE" 2> "$ERROR_FILE"
    local GH_EXIT_CODE=$?
    rm -f "$QUERY_FILE"
    
    # Read response from file line by line to avoid command substitution tracing
    local ITEMS_DATA=""
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ -z "$ITEMS_DATA" ]]; then
        ITEMS_DATA="$line"
      else
        ITEMS_DATA="$ITEMS_DATA"$'\n'"$line"
      fi
    done < "$RESPONSE_FILE"
    
    # If no data in response file, read from error file
    if [[ -z "$ITEMS_DATA" && -s "$ERROR_FILE" ]]; then
      ITEMS_DATA=""
      while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -z "$ITEMS_DATA" ]]; then
          ITEMS_DATA="$line"
        else
          ITEMS_DATA="$ITEMS_DATA"$'\n'"$line"
        fi
      done < "$ERROR_FILE"
    fi
    
    rm -f "$RESPONSE_FILE" "$ERROR_FILE"
    
    if [[ $GH_EXIT_CODE -ne 0 ]]; then
      echo "❌ Error: Failed to fetch items from project"
      echo "   Exit code: $GH_EXIT_CODE"
      echo "   Error output: ${ITEMS_DATA:0:200}"
      return 1
    fi
    
    # Check for GraphQL errors in the response
    local GRAPHQL_ERROR=$(echo "$ITEMS_DATA" | jq -r '.errors[0].message' 2>/dev/null)
    if [[ -n "$GRAPHQL_ERROR" && "$GRAPHQL_ERROR" != "null" ]]; then
      echo "❌ Error: GraphQL error: $GRAPHQL_ERROR"
      return 1
    fi
    
    # Extract items in source column from this page
    local PAGE_ITEMS=$(echo "$ITEMS_DATA" | jq -r ".data.node.items.nodes[] | select(.fieldValues.nodes[]? | select(.field.name == \"Status\" and .name == \"$SOURCE_ACTUAL_NAME\")) | .id" 2>/dev/null)
    local TOTAL_ITEMS_ON_PAGE=$(echo "$ITEMS_DATA" | jq -r '.data.node.items.nodes | length' 2>/dev/null)
    local NEXT_PAGE_VALUE=$(echo "$ITEMS_DATA" | jq -r '.data.node.items.pageInfo.hasNextPage' 2>/dev/null)
    CURSOR=$(echo "$ITEMS_DATA" | jq -r '.data.node.items.pageInfo.endCursor' 2>/dev/null)
    
    # Add items found on this page
    if [[ -n "$PAGE_ITEMS" ]]; then
      if [[ -z "$ITEMS_IN_SOURCE" ]]; then
        ITEMS_IN_SOURCE="$PAGE_ITEMS"
      else
        ITEMS_IN_SOURCE="$ITEMS_IN_SOURCE"$'\n'"$PAGE_ITEMS"
      fi
    fi
    
    # Check pagination status
    if [[ "$CURSOR" == "null" || -z "$CURSOR" ]]; then
      HAS_NEXT_PAGE=false
      break
    fi
    
    if [[ "$NEXT_PAGE_VALUE" == "null" || -z "$NEXT_PAGE_VALUE" || "$NEXT_PAGE_VALUE" != "true" ]]; then
      HAS_NEXT_PAGE=false
      if [[ -z "$PAGE_ITEMS" ]]; then
        break
      fi
    fi
    
    if [[ "$NEXT_PAGE_VALUE" == "true" && -z "$CURSOR" ]]; then
      HAS_NEXT_PAGE=false
      break
    fi
  done
  
  if [[ -z "$ITEMS_IN_SOURCE" ]]; then
    echo "ℹ️  No items found in column '$SOURCE_ACTUAL_NAME'"
    return 0
  fi
  
  local ITEM_COUNT=$(echo "$ITEMS_IN_SOURCE" | wc -l | tr -d ' ')
  echo "📦 Found $ITEM_COUNT item(s) in column '$SOURCE_ACTUAL_NAME'"
  echo -n "🔄 Moving items: "
  
  local MOVED=0
  local FAILED=0
  local FAILED_ITEMS=()
  
  while IFS= read -r item_id; do
    [[ -z "$item_id" || "$item_id" == "null" ]] && continue
    
    local UPDATE_MUTATION=$(cat <<EOF
mutation {
  updateProjectV2ItemFieldValue(
    input: {
      projectId: "$PROJECT_ID"
      itemId: "$item_id"
      fieldId: "$STATUS_FIELD_ID"
      value: {
        singleSelectOptionId: "$DEST_OPTION_ID"
      }
    }
  ) {
    projectV2Item {
      id
    }
  }
}
EOF
)
    
    local UPDATE_RESULT=$(gh api graphql -f query="$UPDATE_MUTATION" 2>&1)
    
    if [[ $? -eq 0 ]]; then
      local ERROR_MSG=$(echo "$UPDATE_RESULT" | jq -r '.errors[0].message' 2>/dev/null)
      if [[ -n "$ERROR_MSG" && "$ERROR_MSG" != "null" ]]; then
        ((FAILED++))
        FAILED_ITEMS+=("$item_id: $ERROR_MSG")
        echo -n "F"
      else
        ((MOVED++))
        echo -n "."
      fi
    else
      ((FAILED++))
      local ERROR_SUMMARY=$(echo "$UPDATE_RESULT" | head -1 | cut -c1-50)
      FAILED_ITEMS+=("$item_id: $ERROR_SUMMARY")
      echo -n "F"
    fi
  done <<< "$ITEMS_IN_SOURCE"
  
  echo ""
  if [[ ${#FAILED_ITEMS[@]} -gt 0 ]]; then
    echo "❌ Failed items:"
    for failed_item in "${FAILED_ITEMS[@]}"; do
      echo "   - $failed_item"
    done
  fi
  echo "✨ Completed: $MOVED moved, $FAILED failed"
}

# Generates a formatted timesheet from issue references and copies it to clipboard
# Usage: timesheet (then paste multiline input, end with empty line)
timesheet() {
  echo "Copy paste timesheet entries:\n"
  local input=""
  vared input

  local output=""
  local remaining="$input"
  while [[ "$remaining" =~ ([a-zA-Z0-9_-]+)[[:space:]]*-[[:space:]]*#([0-9]+) ]]; do
    local repo="${match[1]:-${BASH_REMATCH[1]}}"
    local issue="${match[2]:-${BASH_REMATCH[2]}}"
    local entry="[${repo}/${issue}](https://github.com/neetozone/${repo}/issues/${issue}) - Done - Day 1"
    if [[ -z "$output" ]]; then
      output="$entry"
    else
      output+=$'\n'"$entry"
    fi
    remaining="${remaining#*#${issue}}"
  done

  if [[ -z "$output" ]]; then
    echo "No valid entries found."
    return 1
  fi

  output=$(echo "$output" | sort)
  echo "$output" | pbcopy
  local COLOR="\033[1;33m"
  local RESET="\033[0m"
  echo "\n${COLOR}Copied to clipboard:\n"
  echo "${COLOR}${output}${RESET}"
}