# Entra ID Test Environment Kickstarter

A set of PowerShell scripts to quickly build a realistic **Microsoft Entra ID** lab/test tenant.

These scripts help you create:

* 100+ fake employees
* A realistic organizational structure with Business Units, Departments, and Teams
* Role-based and organizational groups
* Baseline Conditional Access policies
* OCONUS blocking
* A populated environment for testing identity and security features

Perfect for learning and testing **Conditional Access, group-based licensing, dynamic groups, access reviews, identity governance**, or just having a realistic tenant to experiment with.

> **⚠️ Intended for test and lab environments only.** Review all scripts carefully before running them in a production tenant.

---

## 📜 Scripts Included

| Script            | Purpose                                                                     |
| ----------------- | --------------------------------------------------------------------------- |
| `users.ps1`       | Creates ~100 realistic fake users with departments and job titles           |
| `groups.ps1`      | Creates Business Units, Departments, Teams, and assigns users to them       |
| `cagenerator.ps1` | Creates baseline Conditional Access policies, initially in Report-only mode |

---

## 📋 Prerequisites

Before running the scripts, you'll need:

* A Microsoft Entra ID tenant

  * A free, trial, developer, or dedicated test tenant is recommended
* PowerShell 7+
* Microsoft Graph PowerShell SDK

Install the Microsoft Graph PowerShell SDK:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

### Required Permissions / Roles

Depending on which scripts you run, you will need appropriate Microsoft Graph permissions and Entra ID administrative roles.

Common roles include:

* **Global Administrator**
* **Privileged Role Administrator** + **Conditional Access Administrator**
* Or an equivalent custom role with sufficient permissions

The scripts request the Graph permissions they need when connecting to Microsoft Graph.

---

## 🚀 Recommended Order of Execution

For the best results, run the scripts in the following order:

```text
1. users.ps1
       ↓
2. groups.ps1
       ↓
3. cagenerator.ps1
```

The user and group scripts create the foundation that the Conditional Access policies can then operate against.

---

## 1. Create Fake Users

Connect to Microsoft Graph with the required permissions:

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"
```

Then run:

```powershell
.\users.ps1
```

### What It Does

The script:

* Creates approximately 100 fake employees
* Generates realistic names
* Assigns departments
* Assigns job titles
* Creates user accounts in your tenant
* Exports the generated employee information to a CSV

### Configuration

Before running the script, edit the `$Domain` variable near the top of `users.ps1`:

```powershell
$Domain = "yourtenant.onmicrosoft.com"
```

The script will generate a CSV similar to:

```text
FakeEmployees_2026-10-01.csv
```

This CSV is used by the group-generation script.

---

## 2. Create Groups & Assign Users

Connect to Microsoft Graph:

```powershell
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "Directory.ReadWrite.All"
```

Then run:

```powershell
.\groups.ps1
```

### Groups Created

The script creates an organizational structure including:

* Business Units
* Departments
* Teams
* All Employees
* Managers
* Remote Workers
* Other role-based groups

Users are automatically assigned to appropriate groups based on attributes such as their **Department**.

This provides a realistic foundation for testing group-based identity and access scenarios.

---

## 3. Create Conditional Access Policies

Connect to Microsoft Graph:

```powershell
Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess", "Policy.Read.All", "Directory.Read.All"
```

Then run:

```powershell
.\cagenerator.ps1
```

The script creates a baseline set of Conditional Access policies.

### Policies Created

All policies start in **Report-only** mode.

| Policy                                     | Purpose                                         |
| ------------------------------------------ | ----------------------------------------------- |
| `CA001 - Block OCONUS Access`              | Blocks sign-ins from outside the United States  |
| `CA002 - Block Legacy Authentication`      | Blocks legacy/basic authentication clients      |
| `CA003 - Require MFA for All Users`        | Establishes a baseline MFA requirement          |
| `CA004 - Require MFA for Privileged Roles` | Adds additional protection for privileged roles |

> **Note:** The Global Administrator role is excluded from the policies by default.

---

## 🌎 Named Locations & OCONUS Blocking

The Conditional Access script attempts to create a country-based Named Location:

```text
OCONUS - All countries except United States
```

This location is used by the OCONUS Conditional Access policy.

If the Named Location cannot be created automatically, you can:

1. Create the policy without the location condition.
2. Create the Named Location manually in the Microsoft Entra admin center.
3. Update the Conditional Access policy to use the new Named Location.

---

## 🛡️ Safety Considerations

### Conditional Access Policies Start in Report-only Mode

The Conditional Access policies generated by this project are intentionally created in:

```text
Report-only
```

This allows you to evaluate their impact before enforcing them.

**Do not immediately switch policies to `On` without testing them.**

Before enabling Conditional Access policies:

* Review the affected users and groups.
* Check sign-in logs.
* Test expected access scenarios.
* Validate exclusions.
* Verify emergency access accounts.
* Confirm administrative access paths.

### Break-Glass Accounts

It is strongly recommended that your test tenant have one or more emergency access/break-glass accounts.

These accounts should be carefully excluded from Conditional Access policies where appropriate so that a policy configuration mistake does not lock you out of the tenant.

---

## 🧹 Cleaning Up

The scripts create users, groups, and Conditional Access policies in your tenant.

These resources can be removed later through the Microsoft Entra admin center or with additional PowerShell/Graph cleanup scripts.

If you are using a dedicated lab tenant, you can also reset or recreate the tenant when finished experimenting.

> A cleanup script may be added to this project in the future.

---

## 🧪 Suggested Experiments

Once the tenant is populated, you have a realistic environment for experimenting with Microsoft Entra features.

### Identity & Groups

* Dynamic membership groups
* Group-based licensing
* Role-based groups
* Department-based access
* Manager-based group membership

### Identity Governance

* Access Reviews
* Entitlement Management
* Access Packages
* Privileged Identity Management (PIM)

### Conditional Access

* Conditional Access What If
* Authentication Strengths
* Device-based Conditional Access
* Location-based policies
* Risk-based policies
* Application-specific policies
* User/group exclusions

### Authentication

* MFA
* Passwordless authentication
* Windows Hello for Business
* Certificate-Based Authentication (CBA)
* Authentication methods policies

### Devices

* Device registration
* Microsoft Intune
* Compliant device requirements
* Device-based Conditional Access

---

## 🗂️ Example Lab Architecture

The scripts are designed to produce an environment roughly following this structure:

```text
Microsoft Entra ID Tenant
│
├── Users
│   ├── Business Unit
│   │   ├── Department
│   │   │   ├── Teams
│   │   │   └── Employees
│   │   └── Department
│   │       └── Employees
│   │
│   └── Other Business Unit
│       └── Departments
│
├── Groups
│   ├── All Employees
│   ├── Managers
│   ├── Remote Workers
│   ├── Business Units
│   ├── Departments
│   └── Teams
│
└── Conditional Access
    ├── CA001 - Block OCONUS Access
    ├── CA002 - Block Legacy Authentication
    ├── CA003 - Require MFA for All Users
    └── CA004 - Require MFA for Privileged Roles
```

---

## ⚠️ Disclaimer

These scripts are intended for **test, lab, educational, and learning environments**.

They create and modify resources in Microsoft Entra ID.

**Do not run these scripts in a production tenant without thoroughly reviewing the code and understanding the changes they will make.**

The author is not responsible for account lockouts, access issues, configuration changes, or other consequences resulting from the use of these scripts.

---

## 🤝 Contributing

Contributions are welcome!

Ideas for future improvements include:

* Additional organizational structures
* More realistic user data
* Additional Conditional Access policies
* Device creation
* Application registrations
* Enterprise applications
* Dynamic group examples
* Authentication method configuration
* Automated cleanup
* Microsoft Graph SDK improvements
* Azure Automation support
* CI/CD support

To contribute:

1. Fork the repository.

2. Create a feature branch.

   ```bash
   git checkout -b feature/add-new-test-scenario
   ```

3. Commit your changes.

   ```bash
   git commit -m "Add new test scenario"
   ```

4. Push your branch.

   ```bash
   git push origin feature/add-new-test-scenario
   ```

5. Open a Pull Request.

---

## 📄 License

If this project is distributed under the MIT License, see [`LICENSE`](LICENSE) for details.
