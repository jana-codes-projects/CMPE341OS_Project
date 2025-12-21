# Employee Lifecycle Sync Script

## Overview

`employee_lifecycle_sync.sh` is a Bash automation script designed to manage the **employee lifecycle on a Linux system** based on a CSV file.
It synchronizes system users with employee records by handling:

* Onboarding of new active employees
* Offboarding of removed employees
* Offboarding of employees whose status changes to `terminated`
* Group management based on departments
* Home directory archiving
* Logging, reporting, and email notifications

The script is intended for system administration and OS coursework environments.

---

## Features

* Parses and normalizes employee CSV files
* Detects added and removed employees using employee IDs
* Creates Linux users and department groups
* Skips onboarding for non-active employees
* Ensures terminated users are offboarded even if they were never onboarded
* Archives home directories before locking accounts
* Generates detailed reports for managers
* Sends email summaries using `mail`
* Maintains a snapshot of the previous run
* Cleans logs and reports on each run

---

## CSV File Format

The script expects a CSV file with the following columns:

```
Employee_id,Username,Full_Name,Department,Status
```

### Example

```
10012,pheobe.buffay,Pheobe Buffay,Massuse,Active
```

### Notes

* Header row is optional
* `Employee_id` must be numeric
* `Username`, `Department`, and `Status` are case-insensitive
* Valid statuses:

  * `active`
  * `terminated`

---

## Directory Structure

The script automatically creates the following structure:

```
.
├── employee_lifecycle_sync.sh
├── employees.csv
├── output/
│   ├── logs/
│   │   └── lifecycle_sync.log
│   ├── reports/
│   │   └── manager_update_YYYYMMDD_HHMMSS.txt
│   ├── archives/
│   │   └── username_timestamp.tar.gz
│   └── last_employees.csv
└── temp/
```

* `last_employees.csv` is the snapshot used for change detection
* `temp/` is removed at the end of each run

---

## Prerequisites

### System Requirements

* Linux (Ubuntu recommended)
* Root or sudo privileges

### Required Commands

The script checks for the following tools:

* awk
* sort
* comm
* tar
* mail
* useradd
* groupadd
* usermod
* getent

### Email Support

To enable email reports:

```bash
sudo apt update
sudo apt install bsd-mailx
```

Postfix can be left in default configuration for demo purposes.

---

## Usage

### Basic Run

```bash
sudo bash employee_lifecycle_sync.sh
```

### Specify a CSV File

```bash
sudo bash employee_lifecycle_sync.sh /path/to/employees.csv
```

### Environment Variables

You can override the manager email:

```bash
export MANAGER_EMAIL="manager@example.com"
sudo bash employee_lifecycle_sync.sh
```

---

## How the Script Works

### 1. Setup Phase

* Creates output, logs, reports, archives, and temp directories
* Clears the log file
* Deletes old report files

### 2. Normalization

* Trims whitespace
* Converts usernames, departments, and statuses to lowercase
* Sorts entries by `Employee_id`

### 3. Change Detection

* **Added employees**: IDs present in current CSV but not in snapshot
* **Removed employees**: IDs present in snapshot but not in current CSV
* First run treats all employees as new

### 4. Onboarding Logic

* Only employees with `status=active` are onboarded
* Actions:

  * Create department group if missing
  * Create user account if missing
  * Add user to department group

### 5. Offboarding Logic

Offboarding happens in two cases:

#### A. Removed Employees

Employees missing from the current CSV:

* User is created if missing (to allow cleanup)
* Home directory archived
* Account locked

#### B. Terminated Employees

Employees still in CSV but with `status=terminated`:

* User is created if missing
* Home directory archived
* Account locked

This guarantees termination always works, even if onboarding was skipped.

---

## Reports

Each run generates a manager report containing:

* Summary counts
* Added employees (active only)
* Removed employees
* Terminated employees processed
* Artifact locations (logs, archives, snapshot)

Reports are stored in:

```
output/reports/
```

---

## Logging

All actions are logged with timestamps and severity levels:

```
output/logs/lifecycle_sync.log
```

Log levels:

* INFO
* RUN
* OK
* WARN
* ERROR

The log file is cleared at the start of every run.

---

## Snapshot Behavior

* The script stores the normalized CSV as `last_employees.csv`
* This file is used to detect changes in the next run
* Snapshot is updated only after successful processing

---

## Safety Notes

* Users are **locked**, not deleted
* Home directories are archived before locking
* Script must be run with sudo/root
* Designed for lab, demo, and educational use

---

## Example Output

```
Added employees (active)  : 1
Removed employees         : 0
Offboarded by status      : 2
```
