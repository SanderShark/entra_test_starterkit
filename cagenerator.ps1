# ============================================================
# Create Conditional Access Policies + OCONUS Named Location
# Excludes Global Administrator role by default
# All policies start in Report-only mode
# ============================================================

# ---------- CONFIG ----------
$GlobalAdminRoleId = "62e90394-69f5-4237-9190-012177145e10"   # Global Administrator
$State             = "enabledForReportingButNotEnforced"      # Report-only. Change to "enabled" later

# Optional: Add your break-glass account Object IDs here
$BreakGlassUserIds = @(
    # "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
)

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
# Uncomment if needed:
# Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess","Policy.Read.All","Application.Read.All","Directory.Read.All"

# ---------- Helper function ----------
function Get-CommonUserConditions {
    return @{
        includeUsers = @("All")
        excludeRoles = @($GlobalAdminRoleId)
        excludeUsers = $BreakGlassUserIds
    }
}

# ---------- 1. Create or Reuse OCONUS Named Location ----------
Write-Host "`n=== Creating / Finding OCONUS Named Location ===" -ForegroundColor Cyan

$locationName = "OCONUS - All countries except United States"

$existingLocation = Get-MgIdentityConditionalAccessNamedLocation -All | 
    Where-Object { $_.DisplayName -eq $locationName }

if ($existingLocation) {
    $OconusLocationId = $existingLocation.Id
    Write-Host "Using existing Named Location: $locationName" -ForegroundColor Yellow
    Write-Host "ID: $OconusLocationId" -ForegroundColor Yellow
}
else {
    $oconusParams = @{
        "@odata.type" = "#microsoft.graph.countryNamedLocation"
        displayName   = $locationName
        countriesAndRegions = @(
            "AD","AE","AF","AG","AI","AL","AM","AO","AQ","AR","AS","AT","AU","AW","AX","AZ",
            "BA","BB","BD","BE","BF","BG","BH","BI","BJ","BL","BM","BN","BO","BQ","BR","BS","BT","BV","BW","BY","BZ",
            "CA","CC","CD","CF","CG","CH","CI","CK","CL","CM","CN","CO","CR","CU","CV","CW","CX","CY","CZ",
            "DE","DJ","DK","DM","DO","DZ","EC","EE","EG","EH","ER","ES","ET","FI","FJ","FK","FM","FO","FR",
            "GA","GB","GD","GE","GF","GG","GH","GI","GL","GM","GN","GP","GQ","GR","GS","GT","GU","GW","GY",
            "HK","HM","HN","HR","HT","HU","ID","IE","IL","IM","IN","IO","IQ","IR","IS","IT","JE","JM","JO","JP",
            "KE","KG","KH","KI","KM","KN","KP","KR","KW","KY","KZ","LA","LB","LC","LI","LK","LR","LS","LT","LU","LV","LY",
            "MA","MC","MD","ME","MF","MG","MH","MK","ML","MM","MN","MO","MP","MQ","MR","MS","MT","MU","MV","MW","MX","MY","MZ",
            "NA","NC","NE","NF","NG","NI","NL","NO","NP","NR","NU","NZ","OM","PA","PE","PF","PG","PH","PK","PL","PM","PN","PR","PS","PT","PW","PY",
            "QA","RE","RO","RS","RU","RW","SA","SB","SC","SD","SE","SG","SH","SI","SJ","SK","SL","SM","SN","SO","SR","SS","ST","SV","SX","SY","SZ",
            "TC","TD","TF","TG","TH","TJ","TK","TL","TM","TN","TO","TR","TT","TV","TW","TZ","UA","UG","UM","UY","UZ",
            "VA","VC","VE","VG","VI","VN","VU","WF","WS","XK","YE","YT","ZA","ZM","ZW"
        )
        includeUnknownCountriesAndRegions = $true
    }

    try {
        $oconusLocation = New-MgIdentityConditionalAccessNamedLocation -BodyParameter $oconusParams
        $OconusLocationId = $oconusLocation.Id
        Write-Host "Created Named Location: $locationName" -ForegroundColor Green
        Write-Host "ID: $OconusLocationId" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create Named Location: $($_.Exception.Message)"
        return
    }
}

# Wait until the Named Location is fully available
Write-Host "`nWaiting for Named Location to fully propagate..." -ForegroundColor Yellow
$maxAttempts = 8
$attempt = 0
$locationReady = $false

do {
    $attempt++
    Start-Sleep -Seconds 8

    try {
        $check = Get-MgIdentityConditionalAccessNamedLocation -NamedLocationId $OconusLocationId -ErrorAction Stop
        if ($check) {
            $locationReady = $true
            Write-Host "Named Location is ready (attempt $attempt)." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Attempt $attempt : Not ready yet..." -ForegroundColor DarkYellow
    }
} while (-not $locationReady -and $attempt -lt $maxAttempts)

if (-not $locationReady) {
    Write-Error "Named Location still not available after waiting. Please try again in a couple of minutes."
    return
}

# ---------- 2. Define Policies ----------

# CA001 - Block OCONUS
$ca001 = @{
    displayName = "CA001 - Block OCONUS Access"
    state       = $State
    conditions  = @{
        clientAppTypes = @("all")
        applications   = @{ includeApplications = @("All") }
        users          = Get-CommonUserConditions
        locations      = @{
            includeLocations = @($OconusLocationId)
        }
    }
    grantControls = @{
        operator        = "OR"
        builtInControls = @("block")
    }
}

# CA002 - Block Legacy Authentication
$ca002 = @{
    displayName = "CA002 - Block Legacy Authentication"
    state       = $State
    conditions  = @{
        clientAppTypes = @("exchangeActiveSync", "other")
        applications   = @{ includeApplications = @("All") }
        users          = Get-CommonUserConditions
    }
    grantControls = @{
        operator        = "OR"
        builtInControls = @("block")
    }
}

# CA003 - Require MFA for All Users
$ca003 = @{
    displayName = "CA003 - Require MFA for All Users"
    state       = $State
    conditions  = @{
        clientAppTypes = @("all")
        applications   = @{ includeApplications = @("All") }
        users          = Get-CommonUserConditions
    }
    grantControls = @{
        operator        = "OR"
        builtInControls = @("mfa")
    }
}

# CA004 - Require MFA for Privileged Roles
$adminRoles = @(
    "194ae4cb-b126-40b2-bd5b-6091b380977d", # Security Administrator
    "f28a1f50-f6e7-4571-818b-6a12f2af6b6c", # SharePoint Administrator
    "fe930be7-5e62-47db-91af-98c3a49a38b1", # User Administrator
    "729827e3-9c14-49f7-bb1b-9608f156bbb8"  # Helpdesk Administrator
)

$ca004 = @{
    displayName = "CA004 - Require MFA for Privileged Roles"
    state       = $State
    conditions  = @{
        clientAppTypes = @("all")
        applications   = @{ includeApplications = @("All") }
        users          = @{
            includeRoles = $adminRoles
            excludeRoles = @($GlobalAdminRoleId)
            excludeUsers = $BreakGlassUserIds
        }
    }
    grantControls = @{
        operator        = "OR"
        builtInControls = @("mfa")
    }
}

# ---------- 3. Create the policies ----------
Write-Host "`n=== Creating Conditional Access Policies ===" -ForegroundColor Cyan

$policies = @($ca001, $ca002, $ca003, $ca004)

foreach ($policy in $policies) {
    try {
        $result = New-MgIdentityConditionalAccessPolicy -BodyParameter $policy
        Write-Host "Created: $($result.DisplayName)  |  State: $($result.State)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create $($policy.displayName):" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

Write-Host "`nDone!" -ForegroundColor Cyan
Write-Host "All policies are in Report-only mode." -ForegroundColor Cyan
Write-Host "Review them in the Entra portal → Conditional Access → Policies." -ForegroundColor Cyan
Write-Host "When ready, change the state to 'enabled'." -ForegroundColor Yellow
