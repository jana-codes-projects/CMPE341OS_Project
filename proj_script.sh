#!/bin/bash

# ============================= Paths & Global Variables =============================

INPUT_CSV="./employees.csv"

OUTPUT_DIR="./output"
ARCHIVES_DIR="$OUTPUT_DIR/archives"
LOGS_DIR="$OUTPUT_DIR/logs"
REPORTS_DIR="$OUTPUT_DIR/reports"

SNAPSHOT="$OUTPUT_DIR/last_employees.csv"

TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
LOG_FILE="$LOGS_DIR/lifecycle_sync.log"
REPORT_FILE="$REPORTS_DIR/manager_update_$TIMESTAMP.txt"

MANAGER_EMAIL="janabarazi@stu.khas.edu.tr"

# ============================= Log Function =============================

log() {
    echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

# ============================= Project Structure =============================

ensure_project_structure() {
    mkdir -p "$ARCHIVES_DIR" "$LOGS_DIR" "$REPORTS_DIR"
    touch "$LOG_FILE"
}

# ============================= CSV Normalization =============================
# Output format (sorted):
# employee_id,username,full_name,department,status

normalize_csv() {
    awk -F',' '
    NR > 1 {
        for (i=1; i<=5; i++)
            gsub(/^[ \t]+|[ \t]+$/, "", $i)
        print $1","$2","$3","$4","tolower($5)
    }' "$1" | sort
}

# ============================= Onboarding =============================

ensure_department_group() {
    local dept="$1"
    if ! getent group "$dept" >/dev/null; then
        groupadd "$dept"
        log "Created department group: $dept"
    fi
}

onboard_user() {
    local username="$1"
    local full_name="$2"
    local department="$3"

    ensure_department_group "$department"

    if ! id "$username" &>/dev/null; then
        useradd -m "$username"
        log "Created user account: $full_name ($username)"
    fi

    usermod -aG "$department" "$username"
    log "Added $full_name ($username) to group $department"
}

# ============================= Offboarding =============================

offboard_user() {
    local username="$1"
    local full_name="$2"

    if getent passwd "$username" >/dev/null; then
        home_dir=$(getent passwd "$username" | cut -d: -f6)
        archive_file="$ARCHIVES_DIR/${username}_${TIMESTAMP}.tar.gz"

        tar -czf "$archive_file" "$home_dir" 2>/dev/null
        usermod -L "$username"

        log "Archived home directory of $full_name ($username) to $archive_file"
        log "Locked account for user: $full_name ($username)"
    fi
}

# ============================= Reporting =============================

generate_report() {
    local added="$1"
    local removed="$2"
    local terminated="$3"

    {
        echo "Manager Update Report"
        echo "Timestamp: $(date)"
        echo "=================================="
        echo ""
        echo "New Employees:"
        echo "${added:-None}"
        echo ""
        echo "Removed Employees:"
        echo "${removed:-None}"
        echo ""
        echo "Terminated Employees:"
        echo "${terminated:-None}"
    } > "$REPORT_FILE"
}

# ============================= Main Workflow =============================

main() {
    ensure_project_structure
    log "Employee lifecycle sync started"

    CURRENT_NORM=$(normalize_csv "$INPUT_CSV")

    # ---------------------- FIRST RUN ----------------------
    if [ ! -f "$SNAPSHOT" ]; then
        log "First run detected – onboarding all active employees"

        echo "$CURRENT_NORM" > "$SNAPSHOT"

        while IFS=',' read -r emp_id username full_name department status; do
            if [ "$status" = "active" ]; then
                onboard_user "$username" "$full_name" "$department"
            fi
        done <<< "$CURRENT_NORM"

        log "Initial snapshot saved to reports/last_employees.csv"
        log "Employee lifecycle sync completed successfully"
        exit 0
    fi

    # ---------------------- CHANGE DETECTION ----------------------

    OLD_NORM=$(cat "$SNAPSHOT")

    ADDED=$(comm -13 <(echo "$OLD_NORM") <(echo "$CURRENT_NORM"))
    REMOVED=$(comm -23 <(echo "$OLD_NORM") <(echo "$CURRENT_NORM"))
    TERMINATED=$(echo "$CURRENT_NORM" | awk -F',' '$5=="terminated"')

    # ---------------------- PROCESS ADDED ----------------------

    while IFS=',' read -r emp_id username full_name department status; do
        [ -z "$username" ] && continue
        onboard_user "$username" "$full_name" "$department"
    done <<< "$ADDED"

    # ---------------------- PROCESS REMOVED ----------------------

    while IFS=',' read -r emp_id username full_name department status; do
        [ -z "$username" ] && continue
        offboard_user "$username" "$full_name"
    done <<< "$REMOVED"

    # ---------------------- PROCESS TERMINATED ----------------------

    while IFS=',' read -r emp_id username full_name department status; do
        [ -z "$username" ] && continue
        offboard_user "$username" "$full_name"
    done <<< "$TERMINATED"

    # ---------------------- REPORT & EMAIL ----------------------

    generate_report "$ADDED" "$REMOVED" "$TERMINATED"
    mail -s "Employee Lifecycle Update" "$MANAGER_EMAIL" < "$REPORT_FILE"

    # ---------------------- SAVE SNAPSHOT ----------------------

    echo "$CURRENT_NORM" > "$SNAPSHOT"
    log "Snapshot updated"
    log "Employee lifecycle sync completed successfully"
}

main
