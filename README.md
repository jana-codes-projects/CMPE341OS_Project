# Employee Lifecycle Management Automation

**CMPE341 – Operating Systems (Linux Mini Project)**

## 📌 Project Overview

This project implements an **automated employee lifecycle management system** using **Bash scripting** on Linux.
The script synchronizes system user accounts with an HR-maintained CSV file, handling:

* ✅ Employee onboarding
* ❌ Employee offboarding
* 🔒 Account termination
* 🗂 Home directory archiving
* 📄 Reporting and logging
* 📧 Emailing manager updates

The solution is **idempotent**, tracks changes between runs, and maintains historical snapshots.

---

## 📁 Project Structure

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

---

## 📄 Input File: `employees.csv`

The input CSV **must use exactly 5 fields**:

```
employee_id,username,full_name,department,status
```

### Example:

```csv
10001,ayse.aydin,Ayşe Aydın,Data,Active
10002,mehmet.kaya,Mehmet Kaya,Dev,Terminated
10003,elif.demir,Elif Demir,HR,Active
```

### Field Description:

| Field       | Description                      |
| ----------- | -------------------------------- |
| employee_id | Unique employee identifier       |
| username    | Linux system username            |
| full_name   | Employee full name               |
| department  | Department (used as Linux group) |
| status      | Active or Terminated             |

---

## ⚙️ Script Features

### 🔹 CSV Normalization

* Removes headers
* Trims whitespace
* Sorts records
* Output format:

```
employee_id,username,full_name,department,status

```

---

### 🔹 Onboarding (Active Employees)

For employees marked as **Active**:

* Creates department group if missing
* Creates user account if missing
* Adds user to department group
* Logs full name and username

---

### 🔹 Offboarding / Termination

For employees:

* Removed from CSV **or**
* Marked as **Terminated**

The script:

* Archives home directory (`.tar.gz`)
* Locks the user account
* Logs actions with full name and username

---

### 🔹 Snapshot-Based Change Detection

* `output/reports/last_employees.csv` stores previous state
* Differences are detected using `comm`
* Supports:

  * New employees
  * Removed employees
  * Status changes

---

## 📝 Logging

All actions are logged to:

```
output/logs/lifecycle_sync.log
```

### Example log entries:

```
[2025-12-20 14:44:20] Created user account: Ahmet Yılmaz (ahmet.yilmaz)
[2025-12-20 14:44:20] Added Ahmet Yılmaz (ahmet.yilmaz) to group Dev
[2025-12-20 14:44:21] Locked account for user: Mehmet Kaya (mehmet.kaya)
```

---

## 📊 Manager Report

After each run, a report is generated:

```
output/reports/manager_update_<timestamp>.txt
```

### Report Contents:

* New Employees
* Removed Employees
* Terminated Employees
* Timestamp

---

## 📧 Emailing the Manager Report (Part 9)

The report is emailed using **mailutils**:

```bash
mail -s "Employee Lifecycle Update" "$MANAGER_EMAIL" < "$REPORT_FILE"
```

### Important Note (Per Instructor Clarification)

* Sending the email via **mailutils** is **sufficient**
* SMTP server configuration is **NOT required**
* In containerized environments (e.g., GitHub Codespaces), emails may be **queued but not delivered**
* Successful execution and queuing (`postqueue -p`) is acceptable for full credit

---

## ▶️ How to Run the Project

### 1️⃣ Make script executable

```bash
chmod +x proj_script.sh
```

### 2️⃣ Run the script

```bash
./proj_script.sh
```

> ⚠️ User and group creation requires elevated privileges:

```bash
sudo ./proj_script.sh
```

---

## ✏️ Updating Employees Without Opening the CSV

### ➕ Add a new employee

```bash
echo "10011,ahmet.yilmaz,Ahmet Yılmaz,Dev,Active" >> employees.csv
```

### 🔁 Mark an employee as terminated

```bash
sed -i 's/,mehmet.kaya,Mehmet Kaya,Dev,Active/,mehmet.kaya,Mehmet Kaya,Dev,Terminated/' employees.csv
```

### ❌ Remove an employee

```bash
sed -i '/,can.ozkan,/d' employees.csv
```

Then rerun:

```bash
sudo ./proj_script.sh
```

---

## ⚠️ Known Limitations

* Email delivery may not reach inboxes in restricted environments
* Turkish characters require UTF-8 CSV encoding (supported)
* `mail` command must be installed (`mailutils`)

---

## ✅ Conclusion

This project fulfills all required components of the CMPE341 Linux Mini Project:

* Process management
* File handling
* User/group administration
* Logging
* Reporting
* Email notification (as specified by instructor)

Optional SMTP-based email delivery is **not required** and considered a bonus.

---
