# Employee Lifecycle Management Automation

**CMPE341 – Operating Systems (Linux Mini Project)**

---

## Project Overview

This project implements an automated employee lifecycle management system using Bash scripting on Linux.

The script, `employee_lifecycle_sync.sh`, synchronizes Linux system user accounts with an HR-maintained CSV file and automatically manages:

* Employee onboarding
* Employee offboarding
* Account termination handling
* Home directory archiving
* Logging and reporting
* Email notifications to management

The solution is idempotent, supports change detection between runs, and maintains a snapshot of the previous employee state to reliably detect additions, removals, and status changes.

---

## Project Structure

```
CMPE341OS_Project/
├── employee_lifecycle_sync.sh
├── employees.csv
├── README.md
├── temp/
└── output/
    ├── archives/
    ├── logs/
    │   └── lifecycle_sync.log
    ├── reports/
    │   └── manager_update_<timestamp>.txt
    └── last_employees.csv
```

Notes:

* The `output/` and `temp/` directories are automatically created by the script.
* Old reports are deleted at the start of every run.
* Temporary files are removed at the end of execution.

---

## Input File: `employees.csv`

The input CSV must contain **exactly five fields** in the following order:

```
employee_id,username,full_name,department,status
```

### Example CSV

```csv
Employee_id,Username,Full_Name,Department,Status
10001,ayse.aydin,Ayşe Aydın,Data,Active
10002,mehmet.kaya,Mehmet Kaya,Dev,Terminated
10003,elif.demir,Elif Demir,HR,Active
```

### Field Descriptions

| Field       | Description                                 |
| ----------- | ------------------------------------------- |
| employee_id | Unique numeric employee identifier          |
| username    | Linux system username                       |
| full_name   | Employee full name                          |
| department  | Department name (used as Linux group name)  |
| status      | `active` or `terminated` (case-insensitive) |

---

## Script Features

### CSV Normalization

Before any processing, the script normalizes the CSV:

* Skips the header row automatically
* Trims leading and trailing whitespace
* Converts usernames, departments, and status fields to lowercase
* Sorts records by employee ID

This guarantees consistent and reliable change detection across runs.

---

### Snapshot-Based Change Detection

The script stores the previous normalized state in:

```
output/last_employees.csv
```

Each execution compares the current CSV against this snapshot to detect:

* Newly added employees (new employee IDs)
* Removed employees (missing employee IDs)
* Employees whose status is `terminated`

On the **first run**, all employees are treated as new.

---

## Onboarding Logic (Active Employees)

For newly added employees with `status=active`, the script:

* Creates the department group if it does not exist
* Creates the Linux user account if it does not exist
* Adds the user to the department group
* Logs every action

Employees with `status=terminated` are skipped during onboarding.

---

## Offboarding Logic

Offboarding occurs in two cases.

### 1. Removed Employees

If an employee ID existed in the previous snapshot but is missing from the current CSV:

* The user account is created if it does not exist (to allow cleanup)
* The user’s home directory is archived as a `.tar.gz` file
* The user account is locked
* The action is logged and reported

### 2. Terminated Employees

If an employee exists in the CSV but has `status=terminated`:

* The user account is created if it does not exist
* The home directory is archived
* The account is locked
* The termination is reported separately

This design ensures termination is always processed correctly, even if onboarding was previously skipped.

---

## Logging

All actions are logged to:

```
output/logs/lifecycle_sync.log
```

### Log Levels Used

* INFO   – General progress messages
* RUN    – System commands executed
* OK     – Successful operations
* WARN   – Skipped or non-fatal issues
* ERROR  – Critical failures

### Example Log Entries

```
2025-12-20 14:44:20 | [OK]    | User created: ahmet.yilmaz
2025-12-20 14:44:21 | [OK]    | Added ahmet.yilmaz to group dev
2025-12-20 14:44:22 | [OK]    | Locked account: mehmet.kaya
```

The log file is cleared automatically at the start of every run.

---

## Manager Report

After each execution, a manager report is generated in:

```
output/reports/manager_update_<timestamp>.txt
```

### Report Contents

* Summary counts:

  * Added employees (active)
  * Removed employees
  * Offboarded by status
* Lists of affected users and departments
* Locations of logs, archives, and snapshot files

Old reports are removed automatically before generating a new one.

---

## Email Notification

The manager report is emailed using `mailutils`.

### Email Command Used

```bash
mail -s "Employee Lifecycle Update" "$MANAGER_EMAIL" < report.txt
```

### Important Notes (Instructor Clarification)

* Installing `bsd-mailx` / `mailutils` is sufficient
* Full SMTP configuration is not required
* In containerized or lab environments, emails may be queued but not delivered
* Successful execution without runtime errors is acceptable for grading

---

## How to Run the Project

### Make the script executable

```bash
chmod +x employee_lifecycle_sync.sh
```

### Run the script (requires root privileges)

```bash
sudo ./employee_lifecycle_sync.sh
```

### Specify a custom CSV file

```bash
sudo ./employee_lifecycle_sync.sh custom_employees.csv
```

---

## Updating Employees Without Opening the CSV

### Add a new employee

```bash
echo "10011,ahmet.yilmaz,Ahmet Yılmaz,Dev,Active" >> employees.csv
```

### Mark an employee as terminated

```bash
sed -i 's/,mehmet.kaya,Mehmet Kaya,Dev,Active/,mehmet.kaya,Mehmet Kaya,Dev,Terminated/' employees.csv
```

### Remove an employee

```bash
sed -i '/,can.ozkan,/d' employees.csv
```

Then rerun the script:

```bash
sudo ./employee_lifecycle_sync.sh
```

---

## Known Limitations

* Email delivery may not reach inboxes in restricted or containerized environments
* The script must be run with root privileges
* User accounts are locked instead of deleted for safety and auditability
* Department names are used directly as Linux group names

---

## Conclusion

This project fulfills all requirements of the CMPE341 Linux Mini Project:

* Process automation using Bash
* File and directory management
* User and group administration
* Snapshot-based state comparison
* Logging, reporting, and email notification

The solution is safe, repeatable, and suitable for real-world employee lifecycle automation scenarios.
