# load_pg_dump staging
# load_pg_dump
load_pg_dump() {
  ENV="production"
  if [[ $1 == "staging" ]] ;then
    ENV="staging"
  fi
  APP_NAME=$(basename $(pwd) | sed 's/neeto-//; s/-web//')
  DB_NAME=$(grep -A 5 '^development:' config/database.yml | grep 'database:' | head -1 | sed 's/.*database: *//')
  USER=$(whoami)
  FILE_PATH=$(echo "/Users/"$USER"/Downloads/neeto/"$APP_NAME"_"$ENV".dump")

  # Define steps
  local step1="Check if file exists"
  local step2="Check if file is readable"
  local step3="Reset database"
  local step4="Load DB dump"
  local step5="Reset passwords"

  # Function to display current status
  show_status() {
    local current_step=$1
    local failed_step=$2

    # Clear screen and move cursor to top
    printf "\033[2J\033[H"

    echo "Loading DB dump for $ENV environment..."
    echo "Database: $DB_NAME"
    echo "File: $FILE_PATH"
    echo ""

    get_step() {
      case $1 in
        1) echo "$step1" ;;
        2) echo "$step2" ;;
        3) echo "$step3" ;;
        4) echo "$step4" ;;
        5) echo "$step5" ;;
      esac
    }

    for i in {1..5}; do
      local step_text=$(get_step $i)
      if [ -n "$failed_step" ] && [ $i -eq $failed_step ]; then
        echo -e "\033[31m❌ $i. $step_text - FAILED\033[0m"
      elif [ $i -lt $current_step ]; then
        echo "✅ $i. $step_text"
      elif [ $i -eq $current_step ]; then
        echo "-> $i. $step_text"
      else
        echo "☑️ $i. $step_text"
      fi
    done
    echo ""
  }

  # Show initial status
  show_status 1

  # Step 1: Check if file exists
  if ! [ -f $FILE_PATH ]; then
    show_status 1 1
    echo "File not found: $FILE_PATH"
    return 1
  fi
  show_status 2

  # Step 2: Check if file is readable
  if ! [ -r $FILE_PATH ]; then
    show_status 2 2
    echo "File is not readable: $FILE_PATH"
    echo "If this is your new Mac, open \"System Preferences -> Privacy & Security -> Full Disk Access\" and add \"Terminal\" to the list of allowed applications."
    return 1
  fi
  show_status 3

  # Step 3: Reset database
  db_reset_output=$(DISABLE_DATABASE_ENVIRONMENT_CHECK=1 rails db:drop db:create 2>&1 >/dev/null)
  if [ $? -ne 0 ]; then
    if echo "$db_reset_output" | grep -q "PG::ObjectInUse"; then
      echo "Database is in use. Terminating connections..."
      psql -U $USER -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();" >/dev/null 2>&1
      db_reset_output=$(DISABLE_DATABASE_ENVIRONMENT_CHECK=1 rails db:drop db:create 2>&1 >/dev/null)
      if [ $? -ne 0 ]; then
        show_status 3 3
        echo "Database reset failed even after terminating connections"
        return 1
      fi
    else
      show_status 3 3
      echo "Database reset failed"
      return 1
    fi
  fi
  show_status 4

  # Step 4: Load DB dump
  # Run pg_restore without --clean to avoid "relation does not exist" errors
  pg_output=$(pg_restore --no-acl --no-owner -h localhost -U $USER -d $DB_NAME $FILE_PATH 2>&1)
  exit_code=$?

  # Check for actual errors (not just "does not exist" warnings)
  if [ $exit_code -ne 0 ]; then
    # Filter out "does not exist" errors which are expected on fresh databases
    actual_errors=$(echo "$pg_output" | grep -v "does not exist" | grep -v "WARNING" | grep -v 'schema "public" already exists' | grep "ERROR")

    if [ -n "$actual_errors" ]; then
      show_status 4 4
      echo "DB dump load failed with actual errors:"
      echo "$actual_errors"
      return 1
    fi
  fi
  show_status 5

  # Step 5: Reset passwords
  if ! rails runner 'User.update_all(encrypted_password: "$2a$11$ez.gaxniFuxFbpnGjHzqAeqC08S74faeyBt3OTS1UAxDbqkTiZVyy")' >/dev/null 2>&1; then
    show_status 5 5
    echo "Password reset failed"
    return 1
  fi

  # Optional: Clear meeting passwords for cal if present
  if [[ "$APP_NAME" == "cal" ]]; then
    if ! rails runner 'Meeting.update_all(password: nil, is_password_protected: false)' >/dev/null 2>&1; then
      show_status 5 5
      echo "Meeting password clear failed"
      return 1
    fi
  fi

  # Show final success status
  show_status 6
}