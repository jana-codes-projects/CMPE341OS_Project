#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
LOGS_DIR="$OUTPUT_DIR/logs"
REPORTS_DIR="$OUTPUT_DIR/reports"
ARCHIVES_DIR="$OUTPUT_DIR/archives"
SNAPSHOT_FILE="$OUTPUT_DIR/last_employees.csv"
LOG_FILE="$LOGS_DIR/lifecycle_sync.log"
TEMP_DIR="$SCRIPT_DIR/temp"

# CSV file path (can be passed as argument)
EMPLOYEES_CSV="${1:-$SCRIPT_DIR/employees.csv}"

# Counters for reporting
ADDED_COUNT=0
REMOVED_COUNT=0
TERMINATED_COUNT=0

# Temporary files for change detection
TEMP_CURRENT="$TEMP_DIR/current_sorted.csv"
TEMP_PREVIOUS="$TEMP_DIR/previous_sorted.csv"
TEMP_ADDED="$TEMP_DIR/added.csv"
TEMP_REMOVED="$TEMP_DIR/removed.csv"

# Manager email (can be configured)
MANAGER_EMAIL="${MANAGER_EMAIL:-janabarazi@stu.khas.edu.tr}"


# LOGGING FUNCTIONS

log() {
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    printf "%s | [INFO]  | %s\n" "$ts" "$1" | tee -a "$LOG_FILE"
}

log_command() {
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    printf "%s | [RUN]   | %s\n" "$ts" "$1" | tee -a "$LOG_FILE"
}

log_success() {
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    printf "%s | [OK]    | %s\n" "$ts" "$1" | tee -a "$LOG_FILE"
}

log_warning() {
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    printf "%s | [WARN]  | %s\n" "$ts" "$1" | tee -a "$LOG_FILE"
}

log_error() {
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    printf "%s | [ERROR] | %s\n" "$ts" "$1" | tee -a "$LOG_FILE"
}



# SETUP FUNCTIONS

setup_directory_structure() {
    log "Setting up directory structure..."
    
    # Create directories with -p flag (creates parents if needed, doesn't fail if exists)
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$LOGS_DIR"
    mkdir -p "$REPORTS_DIR"
    mkdir -p "$ARCHIVES_DIR"
    mkdir -p "$TEMP_DIR"
    
    log_success "Directory structure created"
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        echo -e "${RED}Please run: sudo $0${NC}"
        exit 1
    fi
    
    # Check if CSV file exists
    if [[ ! -f "$EMPLOYEES_CSV" ]]; then
        log_error "Employee CSV file not found: $EMPLOYEES_CSV"
        exit 1
    fi
    
    # Check required commands
    local required_commands="awk sort comm tar mail useradd groupadd usermod getent"
    for cmd in $required_commands; do
        if ! command -v $cmd &> /dev/null; then
            log_warning "Command not found: $cmd (may need to install)"
        fi
    done
    
    log_success "Prerequisites checked"
    log ""
}


# CSV PARSING AND NORMALIZATION

normalize_csv() {
    local input_file="$1"
    local output_file="$2"

    log "Normalizing CSV: $input_file"

    awk -F',' '
    BEGIN { OFS="," }

    # Skip header ONLY if first column is not numeric
    NR==1 {
        if ($1 ~ /^[0-9]+$/) {
            process = 1
        } else {
            next
        }
    }

    {
        gsub(/^[ \t]+|[ \t]+$/, "", $1)
        gsub(/^[ \t]+|[ \t]+$/, "", $2)
        gsub(/^[ \t]+|[ \t]+$/, "", $3)
        gsub(/^[ \t]+|[ \t]+$/, "", $4)
        gsub(/^[ \t]+|[ \t]+$/, "", $5)

        $2 = tolower($2)
        $4 = tolower($4)
        $5 = tolower($5)

        print $1,$2,$3,$4,$5
    }
    ' "$input_file" | sort -t',' -k1,1n > "$output_file"

    log_success "CSV normalized and sorted"
}


# CHANGE DETECTION

detect_changes() {
    log "Detecting changes between current and previous employee data..."

    # Normalize current CSV
    normalize_csv "$EMPLOYEES_CSV" "$TEMP_CURRENT"

    # FIRST RUN
    if [[ ! -f "$SNAPSHOT_FILE" ]]; then
        log_warning "No previous snapshot found - treating all employees as new"
        cp "$TEMP_CURRENT" "$TEMP_ADDED"
        : > "$TEMP_REMOVED"
        return 0
    fi

    # Normalize snapshot
    normalize_csv "$SNAPSHOT_FILE" "$TEMP_PREVIOUS"

    # Prepare empty outputs
    : > "$TEMP_ADDED"
    : > "$TEMP_REMOVED"

    # -----------------------------
    # ADDED = ID in current but NOT in snapshot
    # -----------------------------
    while IFS=',' read -r curr_id _; do
        if ! grep -q "^$curr_id," "$TEMP_PREVIOUS"; then
            grep "^$curr_id," "$TEMP_CURRENT" >> "$TEMP_ADDED"
        fi
    done < "$TEMP_CURRENT"

    # -----------------------------
    # REMOVED = ID in snapshot but NOT in current
    # -----------------------------
    while IFS=',' read -r prev_id _; do
        if ! grep -q "^$prev_id," "$TEMP_CURRENT"; then
            grep "^$prev_id," "$TEMP_PREVIOUS" >> "$TEMP_REMOVED"
        fi
    done < "$TEMP_PREVIOUS"

    log_success "Change detection complete"
}


# USER AND GROUP MANAGEMENT

ensure_group_exists() {
    local group_name="$1"
    
    # Check if group exists
    if getent group "$group_name" > /dev/null 2>&1; then
        return 0
    fi
    
    # Create group
    log_command "groupadd \"$group_name\""
    if groupadd "$group_name"; then
        log_success "Group created: $group_name"
        return 0
    else
        log_error "Failed to create group: $group_name"
        return 1
    fi
}

create_user_account() {
    local username="$1"
    local department="$2"
    
    # Check if user already exists
    if id "$username" &>/dev/null; then
        log_warning "User already exists: $username"
        return 0
    fi
    
    # Create user with home directory
    log_command "useradd -m \"$username\""
    if useradd -m "$username"; then
        log_success "User created: $username"
        return 0
    else
        log_error "Failed to create user: $username"
        return 1
    fi
}

add_user_to_group() {
    local username="$1"
    local group_name="$2"
    
    # Check if user is already in group
    if id -nG "$username" 2>/dev/null | grep -qw "$group_name"; then
        log_warning "User $username already in group $group_name"
        return 0
    fi
    
    # Add user to group
    log_command "usermod -aG \"$group_name\" \"$username\""
    if usermod -aG "$group_name" "$username"; then
        log_success "Added $username to group $group_name"
        return 0
    else
        log_error "Failed to add $username to group $group_name"
        return 1
    fi
}


# ONBOARDING

onboard_employee() {
    local employee_id="$1"
    local username="$2"
    local name_surname="$3"
    local department="$4"
    local status="$5"
    
    log "Ensuring user exists: $username ($name_surname)"

    # Ensure department group exists
    ensure_group_exists "$department"

    # ALWAYS create user if missing
    if ! id "$username" &>/dev/null; then
        create_user_account "$username"
        log_success "Created: $username"
    else
        log "User already exists: $username"
    fi

    # Ensure group membership
    add_user_to_group "$username" "$department"

    # Count only active users as onboarding
    if [[ "$status" == "active" ]]; then
        log "Onboarding employee: $username ($name_surname) - Department: $department"
        ((ADDED_COUNT++))
        log_success "Onboarded: $username"
    else
        log_warning "User created but status is $status: $username"
    fi
}

process_onboarding() {
    log "Processing onboarding for new employees..."
    
    if [[ ! -s "$TEMP_ADDED" ]]; then
        log "No new employees to onboard"
        return 0
    fi
    
    # Read each added employee and onboard
    while IFS=',' read -r employee_id username name_surname department status; do
        onboard_employee "$employee_id" "$username" "$name_surname" "$department" "$status"
    done < "$TEMP_ADDED"
    
    log_success "Onboarding processing complete"
}


# OFFBOARDING

archive_user_home() {
    local username="$1"
    
    # Get user's home directory
    local home_dir=$(getent passwd "$username" | cut -d: -f6)
    
    if [[ -z "$home_dir" || ! -d "$home_dir" ]]; then
        log_warning "Home directory not found for $username"
        return 0
    fi
    
    # Create archive filename with timestamp
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local archive_name="${username}_${timestamp}.tar.gz"
    local archive_path="$ARCHIVES_DIR/$archive_name"
    
    # Create archive
    log_command "tar -czf \"$archive_path\" \"$home_dir\""
    if tar -czf "$archive_path" -C "$(dirname "$home_dir")" "$(basename "$home_dir")" 2>/dev/null; then
        log_success "Archived home for $username to $archive_path"
        return 0
    else
        log_error "Failed to archive home for $username"
        return 1
    fi
}

lock_user_account() {
    local username="$1"
    
    # Check if user exists
    if ! id "$username" &>/dev/null; then
        log_warning "User does not exist: $username"
        return 0
    fi
    
    # Lock account
    log_command "usermod -L \"$username\""
    if usermod -L "$username"; then
        log_success "Locked account: $username"
        return 0
    else
        log_error "Failed to lock account: $username"
        return 1
    fi
}

offboard_employee() {
    local employee_id="$1"
    local username="$2"
    local name_surname="$3"
    local department="$4"
    
    # Check if user exists before offboarding
    if ! id "$username" &>/dev/null; then
        log_warning "Offboard skip (user not found): $username"
        return 0
    fi
    
    log "Offboarding employee: $username ($name_surname)"
    
    # Archive home directory
    archive_user_home "$username"
    
    # Lock account
    lock_user_account "$username"
    
    ((REMOVED_COUNT++))
    log_success "Offboarding complete for $username"
}

process_offboarding() {
    log "Processing offboarding for removed employees..."
    
    if [[ ! -s "$TEMP_REMOVED" ]]; then
        log "No employees to offboard (removed)"
        return 0
    fi
    
    # Read each removed employee and offboard
    while IFS=',' read -r employee_id username name_surname department status; do
        offboard_employee "$employee_id" "$username" "$name_surname" "$department"
    done < "$TEMP_REMOVED"
    
    log_success "Offboarding processing complete"
}

process_terminated_status() {
    log "Processing employees with terminated status..."
    
    # Find employees in current CSV with status=terminated
    local terminated_file="$TEMP_DIR/terminated.csv"
    awk -F',' '$5 == "terminated"' "$TEMP_CURRENT" > "$terminated_file"
    
    if [[ ! -s "$terminated_file" ]]; then
        log "No employees with terminated status"
        return 0
    fi
    
    # Read each terminated employee and offboard
    while IFS=',' read -r employee_id username name_surname department status; do
        log "Processing terminated status for: $username"
        offboard_employee "$employee_id" "$username" "$name_surname" "$department"
        ((TERMINATED_COUNT++))
    done < "$terminated_file"
    
    log_success "Terminated status processing complete"
}


# REPORTING

generate_manager_report() {
    log "Generating manager update report..."
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_filename="manager_update_$(date '+%Y%m%d_%H%M%S').txt"
    local report_path="$REPORTS_DIR/$report_filename"
    
    # Create report content
    cat > "$report_path" << EOF
================================================================================
                            Manager Employee Update
================================================================================
Timestamp: $timestamp
Mode: LIVE

Summary
-------
Added employees (active)  : $ADDED_COUNT
Removed employees         : $REMOVED_COUNT
Offboarded by status      : $TERMINATED_COUNT

EOF

    # Add details of added employees
    if [[ -s "$TEMP_ADDED" ]]; then
        echo "Added (username, department)" >> "$report_path"
        echo "----------------------------" >> "$report_path"
        while IFS=',' read -r employee_id username name_surname department status; do
            if [[ "$status" == "active" ]]; then
                echo "$username, $department" >> "$report_path"
            fi
        done < "$TEMP_ADDED"
        echo "" >> "$report_path"
    fi
    
    # Add details of removed employees
    if [[ -s "$TEMP_REMOVED" ]]; then
        echo "Removed (username, department)" >> "$report_path"
        echo "------------------------------" >> "$report_path"
        while IFS=',' read -r employee_id username name_surname department status; do
            echo "$username, $department" >> "$report_path"
        done < "$TEMP_REMOVED"
        echo "" >> "$report_path"
    fi
    
    # Add details of terminated employees
    local terminated_file="$TEMP_DIR/terminated.csv"
    if [[ -s "$terminated_file" ]]; then
        echo "Terminated processed (username, department)" >> "$report_path"
        echo "-------------------------------------------" >> "$report_path"
        while IFS=',' read -r employee_id username name_surname department status; do
            echo "$username, $department" >> "$report_path"
        done < "$terminated_file"
        echo "" >> "$report_path"
    fi
    
    # Add artifacts section
    cat >> "$report_path" << EOF

Artifacts
---------
Archives folder: $ARCHIVES_DIR
Snapshot file  : $SNAPSHOT_FILE
Log file       : $LOG_FILE

================================================================================
EOF

    log_success "Manager report generated: $report_path"
    echo "$report_path"
}


# EMAIL FUNCTIONS

send_email_report() {
    local report_path="$1"
    
    log "Sending email report to $MANAGER_EMAIL..."
    
    # Check if mail command is available
    if ! command -v mail &> /dev/null; then
        log_warning "mail command not available - skipping email"
        log_warning "Install mailutils: sudo apt-get install mailutils"
        return 1
    fi
    
    # Send email with report as body
    local subject="Employee Lifecycle Update - $(date '+%Y-%m-%d %H:%M')"
    
    if mail -s "$subject" "$MANAGER_EMAIL" < "$report_path"; then
        log_success "Email sent to $MANAGER_EMAIL"
    else
        log_warning "Email sending may have failed - check mail configuration"
        log_warning "For demo purposes, using mailutils to university email is sufficient"
    fi
}


# CLEANUP AND FINALIZATION

update_snapshot() {
    log "Updating snapshot file..."
    
    # Copy current normalized CSV as new snapshot
    cp "$TEMP_CURRENT" "$SNAPSHOT_FILE"
    
    log_success "Snapshot updated: $SNAPSHOT_FILE"
}

cleanup_temp_files() {
    log "Cleaning up temporary files..."
    
    # Remove temporary directory
    rm -rf "$TEMP_DIR"
    
    log_success "Temporary files cleaned up"
}


# MAIN EXECUTION

main() {
    local dry_run="${DRY_RUN:-0}"
    
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}Employee Lifecycle Sync Script${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo ""
    
    # Setup
    setup_directory_structure
    check_prerequisites

    : > "$LOG_FILE"   # create or clear log file

    rm -f "$REPORTS_DIR"/*.txt 2>/dev/null # clears the reports folder from old report files
    
    log "START lifecycle sync | file=$(basename "$EMPLOYEES_CSV") | dry_run=$dry_run"
    
    # Phase 1: Change Detection
    detect_changes
    
    # Phase 2: Process Changes
    process_onboarding
    process_offboarding
    process_terminated_status
    
    # Phase 3: Reporting
    local report_path=$(generate_manager_report)
    
    # Display report
    echo ""
    echo -e "${GREEN}==================== REPORT ====================${NC}"
    cat "$report_path"
    echo -e "${GREEN}===============================================${NC}"
    echo ""
    
    # Send email
    send_email_report "$report_path"
    
    # Update snapshot
    update_snapshot
    
    # Cleanup
    cleanup_temp_files
    
    log "END lifecycle sync"
    
    echo ""
    echo -e "${GREEN}✓ Script execution completed successfully${NC}"
    echo -e "  Report: $report_path"
    echo -e "  Log:    $LOG_FILE"
    echo ""
}

# Run main function
main "$@"
