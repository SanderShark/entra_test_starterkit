# ============================================================
# Create realistic company groups + assign fake employees
# ============================================================

# ---------- CONFIGURATION ----------
$CsvPath = ".\FakeEmployees_*.csv"          # Will pick the newest matching file
$Domain  = "inertme.onmicrosoft.com"     # Not strictly needed, but good to have

# ---------- CONNECT ----------
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "Directory.ReadWrite.All" -NoWelcome

# ---------- FIND THE LATEST CSV ----------
$latestCsv = Get-ChildItem -Path . -Filter "FakeEmployees_*.csv" | 
             Sort-Object LastWriteTime -Descending | 
             Select-Object -First 1

if (-not $latestCsv) {
    Write-Error "No FakeEmployees_*.csv file found in the current directory."
    exit
}

Write-Host "Using CSV: $($latestCsv.FullName)" -ForegroundColor Green
$users = Import-Csv -Path $latestCsv.FullName | Where-Object { $_.Status -eq "Success" }

if ($users.Count -eq 0) {
    Write-Error "No successfully created users found in the CSV."
    exit
}

Write-Host "Loaded $($users.Count) users." -ForegroundColor Green

# ---------- DEFINE COMPANY STRUCTURE ----------
# Business Units (top level)
$businessUnits = @(
    "Corporate",
    "Product & Engineering",
    "Go-to-Market",
    "Customer Success",
    "Operations"
)

# Departments (map to Business Units)
$departments = @{
    "Engineering"   = "Product & Engineering"
    "Product"       = "Product & Engineering"
    "Sales"         = "Go-to-Market"
    "Marketing"     = "Go-to-Market"
    "Support"       = "Customer Success"
    "Customer Success" = "Customer Success"
    "HR"            = "Corporate"
    "Finance"       = "Corporate"
    "Legal"         = "Corporate"
    "IT"            = "Operations"
    "Operations"    = "Operations"
}

# Teams (sub-groups under departments)
$teams = @{
    "Engineering" = @("Platform", "Frontend", "Backend", "DevOps", "Data Engineering", "Security Engineering")
    "Product"     = @("Product Management", "Design", "Research")
    "Sales"       = @("Enterprise Sales", "SMB Sales", "Sales Engineering", "Account Management")
    "Marketing"   = @("Demand Gen", "Product Marketing", "Content", "Events")
    "Support"     = @("Technical Support", "Customer Onboarding", "Success Managers")
    "IT"          = @("Infrastructure", "Endpoint Management", "Identity & Access")
    "Finance"     = @("Accounting", "FP&A", "Procurement")
    "HR"          = @("Talent Acquisition", "People Ops", "Learning & Development")
}

# Extra role / security groups
$roleGroups = @(
    "All Employees",
    "Managers",
    "All Engineering",
    "All Sales",
    "All Marketing",
    "Remote Workers",
    "Office Based",
    "VPN Users",
    "Sensitive Data Access",
    "Intune Pilot"
)

# ---------- HELPER: Create a group if it doesn't exist ----------
function New-CompanyGroup {
    param(
        [string]$DisplayName,
        [string]$Description = "",
        [string]$MailNickname = $null
    )

    if (-not $MailNickname) {
        $MailNickname = ($DisplayName -replace '[^a-zA-Z0-9]', '').ToLower()
    }

    # Check if group already exists
    $existing = Get-MgGroup -Filter "displayName eq '$DisplayName'" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "  Group already exists: $DisplayName" -ForegroundColor DarkGray
        return $existing
    }

    $params = @{
        DisplayName     = $DisplayName
        Description     = $Description
        MailEnabled     = $false
        MailNickname    = $MailNickname
        SecurityEnabled = $true
        GroupTypes      = @()          # Security group
    }

    try {
        $group = New-MgGroup -BodyParameter $params
        Write-Host "  Created group: $DisplayName" -ForegroundColor Green
        return $group
    }
    catch {
        Write-Host "  FAILED to create $DisplayName : $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# ---------- CREATE ALL GROUPS ----------
Write-Host "`n=== Creating Business Units ===" -ForegroundColor Cyan
$buGroups = @{}
foreach ($bu in $businessUnits) {
    $g = New-CompanyGroup -DisplayName "BU - $bu" -Description "Business Unit: $bu"
    if ($g) { $buGroups[$bu] = $g }
}

Write-Host "`n=== Creating Departments ===" -ForegroundColor Cyan
$deptGroups = @{}
foreach ($dept in $departments.Keys) {
    $g = New-CompanyGroup -DisplayName "Dept - $dept" -Description "Department: $dept"
    if ($g) { $deptGroups[$dept] = $g }
}

Write-Host "`n=== Creating Teams ===" -ForegroundColor Cyan
$teamGroups = @{}
foreach ($dept in $teams.Keys) {
    foreach ($team in $teams[$dept]) {
        $displayName = "Team - $dept - $team"
        $g = New-CompanyGroup -DisplayName $displayName -Description "Team under $dept"
        if ($g) { $teamGroups["$dept|$team"] = $g }
    }
}

Write-Host "`n=== Creating Role / Security Groups ===" -ForegroundColor Cyan
$roleGroupObjects = @{}
foreach ($rg in $roleGroups) {
    $g = New-CompanyGroup -DisplayName $rg -Description "Role / Security group"
    if ($g) { $roleGroupObjects[$rg] = $g }
}

# ---------- ASSIGN USERS TO GROUPS ----------
Write-Host "`n=== Assigning users to groups ===" -ForegroundColor Cyan

$assignmentCount = 0

foreach ($user in $users) {
    $upn = $user.UserPrincipalName
    $dept = $user.Department
    $job  = $user.JobTitle

    # Resolve the user object
    $mgUser = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue
    if (-not $mgUser) {
        Write-Host "  User not found in tenant: $upn" -ForegroundColor Yellow
        continue
    }

    $userId = $mgUser.Id

    # 1. Always add to "All Employees"
    if ($roleGroupObjects["All Employees"]) {
        try {
            New-MgGroupMember -GroupId $roleGroupObjects["All Employees"].Id -DirectoryObjectId $userId -ErrorAction Stop
            $assignmentCount++
        } catch {}
    }

    # 2. Department group
    if ($deptGroups.ContainsKey($dept)) {
        try {
            New-MgGroupMember -GroupId $deptGroups[$dept].Id -DirectoryObjectId $userId -ErrorAction Stop
            $assignmentCount++
        } catch {}
    }

    # 3. Business Unit (via department mapping)
    if ($departments.ContainsKey($dept)) {
        $buName = $departments[$dept]
        if ($buGroups.ContainsKey($buName)) {
            try {
                New-MgGroupMember -GroupId $buGroups[$buName].Id -DirectoryObjectId $userId -ErrorAction Stop
                $assignmentCount++
            } catch {}
        }
    }

    # 4. Random team under their department (if teams exist)
    if ($teams.ContainsKey($dept)) {
        $possibleTeams = $teams[$dept]
        $chosenTeam = $possibleTeams | Get-Random
        $key = "$dept|$chosenTeam"
        if ($teamGroups.ContainsKey($key)) {
            try {
                New-MgGroupMember -GroupId $teamGroups[$key].Id -DirectoryObjectId $userId -ErrorAction Stop
                $assignmentCount++
            } catch {}
        }
    }

    # 5. Role groups based on simple rules
    if ($job -match "Manager|Lead|Director|VP|Head") {
        if ($roleGroupObjects["Managers"]) {
            try {
                New-MgGroupMember -GroupId $roleGroupObjects["Managers"].Id -DirectoryObjectId $userId -ErrorAction Stop
                $assignmentCount++
            } catch {}
        }
    }

    if ($dept -eq "Engineering") {
        if ($roleGroupObjects["All Engineering"]) {
            try {
                New-MgGroupMember -GroupId $roleGroupObjects["All Engineering"].Id -DirectoryObjectId $userId -ErrorAction Stop
                $assignmentCount++
            } catch {}
        }
    }

    if ($dept -eq "Sales") {
        if ($roleGroupObjects["All Sales"]) {
            try {
                New-MgGroupMember -GroupId $roleGroupObjects["All Sales"].Id -DirectoryObjectId $userId -ErrorAction Stop
                $assignmentCount++
            } catch {}
        }
    }

    if ($dept -eq "Marketing") {
        if ($roleGroupObjects["All Marketing"]) {
            try {
                New-MgGroupMember -GroupId $roleGroupObjects["All Marketing"].Id -DirectoryObjectId $userId -ErrorAction Stop
                $assignmentCount++
            } catch {}
        }
    }

    # Randomly put ~40% in Remote Workers, rest in Office Based
    if ((Get-Random -Minimum 1 -Maximum 100) -le 40) {
        if ($roleGroupObjects["Remote Workers"]) {
            try {
                New-MgGroupMember -GroupId $roleGroupObjects["Remote Workers"].Id -DirectoryObjectId $userId -ErrorAction Stop
                $assignmentCount++
            } catch {}
        }
    } else {
        if ($roleGroupObjects["Office Based"]) {
            try {
                New-MgGroupMember -GroupId $roleGroupObjects["Office Based"].Id -DirectoryObjectId $userId -ErrorAction Stop
                $assignmentCount++
            } catch {}
        }
    }

    # Small chance for extra groups
    if ((Get-Random -Minimum 1 -Maximum 100) -le 15) {
        if ($roleGroupObjects["VPN Users"]) {
            try {
                New-MgGroupMember -GroupId $roleGroupObjects["VPN Users"].Id -DirectoryObjectId $userId -ErrorAction Stop
                $assignmentCount++
            } catch {}
        }
    }
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan
Write-Host "Approximate membership assignments made: $assignmentCount" -ForegroundColor Green
Write-Host "Note: Some 'already exists' errors are normal and were suppressed." -ForegroundColor DarkGray
