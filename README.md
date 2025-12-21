# Employee Lifecycle Management Automation

**CMPE341 – Operating Systems (Linux Mini Project)**

---

## Project Overview

This project implements an automated employee lifecycle management system using Bash scripting on Linux.

The script synchronizes Linux system user accounts with an HR-maintained CSV file and automatically manages:

* Employee onboarding
* Employee offboarding
* Account termination
* Home directory archiving
* Logging and reporting
* Email notifications to management

The solution is idempotent, supports change detection between runs, and maintains a snapshot of the previous employee state.

---

## Project Structure

```
CMPE341OS_Project/
├── employees.csv
├── proj_script.sh
├── README.md
└── output/
    ├── archives/
    ├── logs/
    │   └── lifecycle_sync.log
    ├── reports/
    │   └── manager_update_<timestamp>.txt
    └── last_employees.csv
```

Note:
The `output/` directory and all required subdirectories are automatically created by the script if they do not exist.

---

## Input File: `employees.csv`

The input CSV must contain exactly five fields in the following order:

```
employee_id,username,full_name,department,status
```

### Example CSV

```csv
employee_id,username,full_name,department,status
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

The script automatically:

* Skips CSV headers
* Trims leading and trailing whitespace
* Converts usernames, departments, and status fields to lowercase
* Sorts records by employee ID

This ensures reliable change detection across script executions.

---

### Onboarding (Active Employees)

For new employees marked as `active`, the script:

* Creates the department group if it does not exist
* Creates the user account if it does not exist
* Adds the user to the department group
* Logs all actions

---

### Offboarding (Removed Employees)

If an employee is removed from the CSV file, the script:

* Archives the user’s home directory as a `.tar.gz` file
* Locks the user account
* Preserves system data for auditing purposes

---

### Termination Handling

If an employee exists in the CSV but has a status of `terminated`, the script:

* Archives the user’s home directory
* Locks the user account
* Reports the termination separately

---

### Snapshot-Based Change Detection

The script stores the previous normalized employee state in:

```
output/last_employees.csv
```

Each execution compares the current CSV with the previous snapshot to detect:

* Newly added employees
* Removed employees
* Terminated employees

---

## Logging

All script actions are logged to:

```
output/logs/lifecycle_sync.log
```

### Example Log Entries

```
2025-12-20 14:44:20 | [OK]    | User created: ahmet.yilmaz
2025-12-20 14:44:21 | [OK]    | Added ahmet.yilmaz to group dev
2025-12-20 14:44:22 | [OK]    | Locked account: mehmet.kaya
```

---

## Manager Report

After each run, a detailed manager report is generated at:

```
output/reports/manager_update_<timestamp>.txt
```

### Report Contents

* Number of added employees
* Number of removed employees
* Number of terminated employees
* Lists of affected users and departments
* Locations of logs, archives, and snapshot files

Old reports are automatically cleared before each execution.

---

## Email Notification

The manager report is emailed using `mailutils`.

### Email Command Used

```bash
mail -s "Employee Lifecycle Update" "$MANAGER_EMAIL" < report.txt
```

### Important Notes (Instructor Clarification)

* Installing `mailutils` is sufficient
* SMTP server configuration is not required
* In containerized environments, emails may be queued but not delivered
* Successful execution without errors is acceptable for grading

---

## How to Run the Project

### Make the script executable

```bash
chmod +x proj_script.sh
```

### Run the script (requires root privileges)

```bash
sudo ./proj_script.sh
```

### Optional: Specify a custom CSV file

```bash
sudo ./proj_script.sh custom_employees.csv
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
sudo ./proj_script.sh
```

---

## Known Limitations

* Email delivery may not reach inboxes in restricted or containerized environments
* The script must be run with root privileges
* `mailutils` must be installed for email support
* User accounts are locked instead of deleted for safety reasons

---

## Conclusion

This project fulfills all requirements of the CMPE341 Linux Mini Project:

* Process automation
* File and directory management
* User and group administration
* Logging and reporting
* Email notification as specified

The solution is safe, repeatable, and suitable for real-world HR automation scenarios.
