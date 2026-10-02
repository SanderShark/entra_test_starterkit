# ============================================================
# Create 100 Fake Employees in a Test Entra ID Tenant
# Using Microsoft Graph PowerShell
# ============================================================

# ---------- CONFIGURATION ----------
$NumberOfUsers   = 100
$Domain          = "inertme.onmicrosoft.com"   # <-- CHANGE THIS
$DefaultPassword = "P@ssw0rd123!"                 # Temporary password
$UsageLocation   = "US"                           # Required for licensing later
$ForceChangePwd  = $true                          # Force password change on first sign-in

# Optional: Add more realistic attributes
$Departments = @("Engineering", "Sales", "Marketing", "HR", "Finance", "IT", "Operations", "Support", "Legal", "Product")
$JobTitles   = @("Software Engineer", "Account Manager", "Marketing Specialist", "HR Business Partner",
                 "Financial Analyst", "Systems Administrator", "Operations Manager", "Support Engineer",
                 "Legal Counsel", "Product Manager", "Data Analyst", "Sales Representative")

# Common first & last names for realistic fake data
$FirstNames = @(
    "James","Mary","John","Patricia","Robert","Jennifer","Michael","Linda","William","Elizabeth",
    "David","Barbara","Richard","Susan","Joseph","Jessica","Thomas","Sarah","Charles","Karen",
    "Christopher","Nancy","Daniel","Lisa","Matthew","Betty","Anthony","Margaret","Mark","Sandra",
    "Donald","Ashley","Steven","Kimberly","Paul","Emily","Andrew","Donna","Joshua","Michelle",
    "Kenneth","Dorothy","Kevin","Carol","Brian","Amanda","George","Melissa","Timothy","Deborah",
    "Ronald","Stephanie","Jason","Rebecca","Edward","Sharon","Jeffrey","Laura","Ryan","Cynthia",
    "Jacob","Kathleen","Gary","Amy","Nicholas","Angela","Eric","Shirley","Jonathan","Anna",
    "Stephen","Brenda","Larry","Pamela","Justin","Emma","Scott","Nicole","Brandon","Helen",
    "Benjamin","Samantha","Samuel","Katherine","Raymond","Christine","Gregory","Debra","Frank","Rachel"
)

$LastNames = @(
    "Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis","Rodriguez","Martinez",
    "Hernandez","Lopez","Gonzalez","Wilson","Anderson","Thomas","Taylor","Moore","Jackson","Martin",
    "Lee","Perez","Thompson","White","Harris","Sanchez","Clark","Ramirez","Lewis","Robinson",
    "Walker","Young","Allen","King","Wright","Scott","Torres","Nguyen","Hill","Flores",
    "Green","Adams","Nelson","Baker","Hall","Rivera","Campbell","Mitchell","Carter","Roberts"
)

# ---------- CONNECT ----------
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.ReadWrite.All" -NoWelcome

# Verify connection
$context = Get-MgContext
if (-not $context) {
    Write-Error "Failed to connect to Microsoft Graph."
    exit
}
Write-Host "Connected as: $($context.Account)" -ForegroundColor Green

# ---------- CREATE USERS ----------
$created = 0
$failed  = 0
$results = @()

Write-Host "`nCreating $NumberOfUsers fake employees..." -ForegroundColor Cyan

for ($i = 1; $i -le $NumberOfUsers; $i++) {

    # Generate random name
    $firstName = $FirstNames | Get-Random
    $lastName  = $LastNames  | Get-Random
    $displayName = "$firstName $lastName"

    # Create unique UPN (add number to avoid collisions)
    $mailNickname = ($firstName.Substring(0,1) + $lastName).ToLower() + $i
    $upn = "$mailNickname@$Domain"

    $department = $Departments | Get-Random
    $jobTitle   = $JobTitles   | Get-Random

    $passwordProfile = @{
        Password                      = $DefaultPassword
        ForceChangePasswordNextSignIn = $ForceChangePwd
    }

    $params = @{
        AccountEnabled    = $true
        DisplayName       = $displayName
        GivenName         = $firstName
        Surname           = $lastName
        MailNickname      = $mailNickname
        UserPrincipalName = $upn
        PasswordProfile   = $passwordProfile
        UsageLocation     = $UsageLocation
        Department        = $department
        JobTitle          = $jobTitle
        # Optional extras:
        # OfficeLocation = "Building A"
        # MobilePhone    = "555-01" + ("{0:D2}" -f $i)
    }

    try {
        $newUser = New-MgUser -BodyParameter $params -ErrorAction Stop
        $created++
        Write-Host ("[{0:D3}] Created: {1,-25} | {2}" -f $i, $displayName, $upn) -ForegroundColor Green

        $results += [PSCustomObject]@{
            Status            = "Success"
            DisplayName       = $displayName
            UserPrincipalName = $upn
            Department        = $department
            JobTitle          = $jobTitle
            ObjectId          = $newUser.Id
        }
    }
    catch {
        $failed++
        Write-Host ("[{0:D3}] FAILED:  {1,-25} | {2}" -f $i, $displayName, $_.Exception.Message) -ForegroundColor Red

        $results += [PSCustomObject]@{
            Status            = "Failed"
            DisplayName       = $displayName
            UserPrincipalName = $upn
            Department        = $department
            JobTitle          = $jobTitle
            ObjectId          = $null
            Error             = $_.Exception.Message
        }
    }

    # Small delay to avoid throttling (optional but recommended)
    Start-Sleep -Milliseconds 300
}

# ---------- SUMMARY ----------
Write-Host "`n==================== SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Successfully created : $created" -ForegroundColor Green
Write-Host "Failed               : $failed" -ForegroundColor $(if ($failed -gt 0) {"Red"} else {"Green"})
Write-Host "=================================================" -ForegroundColor Cyan

# Export results to CSV
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$csvPath = ".\FakeEmployees_$timestamp.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "`nResults exported to: $csvPath" -ForegroundColor Yellow

# Optional: Disconnect
# Disconnect-MgGraph
