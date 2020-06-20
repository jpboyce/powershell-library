<#
.SYNOPSIS
  Bulk add Flavor Mappings for VMware's vRealize Automation 8
.DESCRIPTION
  This is a proof of concept script for bulk adding Flavor Mappings to VMware's vRealize Automation 8 (vRA 8) using the REST API available.  It will read a reference file containing mapping for different cloud providers (cloudInstanceTypes.csv) and add them.
  Tested with vSphere/vCenter, AWS, Azure and GCP.
  Assumptions:
    - There is only 1 Cloud Zone per Cloud Account
    - There are no existing Flavor Mappings with the same names
.EXAMPLE
  PS C:\> .\add-flavormappings.ps1 -server <vRAServer> -username <username> -password <password>
  Runs the script on <vRAServer> with specified username and password
.INPUTS
  server: Name or IP address of vRA 8 server
  username: Username to execute the REST calls as
  password: Password of the account used
.OUTPUTS
  Some diagnostic output is created.
#>
[CmdletBinding()]
param (
  [Parameter()]
  [String]
  $Server,
  [Parameter()]
  [String]
  $Username,
  [Parameter()]
  [String]
  $Password
)

#Region SETUP
# Define variables/constants
$cspLoginUri = "https://" + $Server + "/csp/gateway/am/api/login?access_token"
$iaasLoginUri = "https://" + $Server + "/iaas/api/login"
$iaasFlavorProfilesUri = "https://" + $Server + "/iaas/api/flavor-profiles"
$iaasCloudAccountsUri = "https://" + $Server + "/iaas/api/cloud-accounts"
$iaasCloudRegionsUri = "https://" + $Server + "/iaas/api/regions"
$cloudInstanceTypes = Import-Csv -Path 'cloudInstanceTypes.csv' -Delimiter ','

# Diagnostic Output
Write-Verbose "Using server name: $($Server)"
Write-Verbose "Using cspLoginUri: $($cspLoginUri)"
Write-Verbose "Using iaasLoginUri: $($iaasLoginUri)"
Write-Verbose "Using iaasCloudAccountsUri: $($iaasCloudAccountsUri)"
Write-Verbose "Using iaasCloudRegionsUri: $($iaasCloudRegionsUri)"
Write-Verbose "Using iaasFlavorProfilesUri: $($iaasFlavorProfilesUri)"
Write-Verbose "Using user name: $($Username)"

# Do a basic network test to ensure we can connect to it
Write-Output "Testing network path to server $($server)"
$testResult = (Test-NetConnection -ComputerName $server -Port 443).TcpTestSucceeded

if ($testResult -eq $true) {
  Write-Output "Network path test successful!"
} else {
  # If there was a problem contacting the server, we want to exit now
  throw "There was a problem contacting server $($server)"
}
#EndRegion SETUP

#Region FUNCTIONS
Function Get-CSPRefreshToken {
  # This function acquires an API Token from the vRealize Automation Identity Service API, as part of the authentication process
  # This is the first step of the authentication process
  [CmdletBinding()]
  param (
    [Parameter()]
    [String]
    $Username,
    [Parameter()]
    [String]
    $Password
)
$Body = @{
  username = $Username
  password = $Password
}
$jsonBody = $Body | ConvertTo-Json
$refreshToken = (Invoke-RestMethod -Method POST -Uri $cspLoginUri -ContentType "application/json" -Body $jsonBody).refresh_token

return $refreshToken
}

Function Get-iaasAccessToken {
  # This function acquires a token from the vRealize Automation IaaS API, as part of the authentication process
  # This is the second step of the authentication process
  [CmdletBinding()]
  param (
    [Parameter()]
    [String]
    $refreshToken
)
$Body = @{
  refreshToken = $refreshToken
}
$jsonBody = $Body | ConvertTo-Json
$accessToken = (Invoke-RestMethod -Method POST -Uri $iaasLoginUri -ContentType "application/json" -Body $jsonBody).token
return $accessToken
}

Function Get-CloudAccounts {
  # This function retrieves Cloud Accounts from the vRA 8 system
  [CmdletBinding()]
  param (
    [Parameter()]
    [String]
    $accessToken
)
$cloudAccounts = Invoke-RestMethod -Method GET -Uri $iaasCloudAccountsUri -ContentType "application/json" -Headers @{Authorization="Bearer $($accessToken)"}
return $cloudAccounts
}

Function Get-CloudAccountRegions {
  # This function retrives the Regions/Cloud Zones associated with a particular Cloud Account ID
  [CmdletBinding()]
  param (
    [Parameter()]
    [String]
    $accessToken,
    [Parameter()]
    [String]
    $cloudAccountId
)
$queryUri = $iaasCloudRegionsUri + '/?$filter=cloudAccountId eq ' + $cloudAccountId

$cloudAccountRegions = Invoke-RestMethod -Method GET -Uri $queryUri -ContentType "application/json" -Headers @{Authorization="Bearer $($accessToken)"}
return ($cloudAccountRegions).content.id
}

Function Add-FlavorMappingForRegion {
  # This function will create a Flavor Mapping using the supplied Body
  [CmdletBinding()]
  param (
    [Parameter()]
    [String]
    $accessToken,
    [Parameter()]
    [String]
    $Body
)
$mappingResult = Invoke-RestMethod -Method POST -Uri $iaasFlavorProfilesUri -ContentType "application/json" -Body $jsonBody -Headers @{Authorization="Bearer $($accessToken)"}
return $mappingResult
}
#EndRegion FUNCTIONS

#Region AUTHENTICATION
# Get Refresh Token
$CSPRefreshToken = Get-CSPRefreshToken -Username $Username -Password $Password
# Get IaaS Token
$iaasAccessToken = Get-iaasAccessToken -refreshToken $CSPRefreshToken
#EndRegion AUTHENTICATION

#Region MAINBODY
# Get the Cloud Accounts
$cloudAccounts = (Get-CloudAccounts -accessToken $iaasAccessToken).content

# Iterate through the Cloud Accounts
foreach ($item in $cloudAccounts) {
  $cloudAccountType = $item.cloudAccountType
  $cloudAccountId = $item.id
  Write-Output "Account Type: $($cloudAccountType)"
  Write-Output "Account ID: $($cloudAccountId)"
  # Get the Region ID for the Cloud Account
  $cloudAccountRegionId = Get-CloudAccountRegions -accessToken $iaasAccessToken -cloudAccountId $cloudAccountId

  $tempFlavorMapping = @{}

  # Construct the Body contents based on the Cloud Account Type, since each has different values/structure
  foreach ($entry in $cloudInstanceTypes) {
    switch ($cloudAccountType) {
      "vsphere" {
        $tempFlavorMappingValues = @{
          cpuCount = $entry.vSphereCPU
          memoryInMB = $entry.vSphereRAM
        }
        $tempFlavorMapping.Add($entry.name, $tempFlavorMappingValues)
        break
      }
      "aws" {
        $tempFlavorMappingValues = @{
          name = $entry.aws
        }
        $tempFlavorMapping.Add($entry.name, $tempFlavorMappingValues)
        break
      }
      "azure" {
        $tempFlavorMappingValues = @{
          name = $entry.azure
        }
        $tempFlavorMapping.Add($entry.name, $tempFlavorMappingValues)
        break
      }
      "gcp" {
        $tempFlavorMappingValues = @{
          name = $entry.gcp
        }
        $tempFlavorMapping.Add($entry.name, $tempFlavorMappingValues)
        break
      }
    }

    }
    # Finish creating the Body Structure
    $Body = @{
      regionId = $cloudAccountRegionId
       name = "flavormapping"
       flavorMapping = $tempFlavorMapping
    }
    # Convert to JSON
    $jsonBody = $Body | ConvertTo-Json
    # Add the Mapping
    Add-FlavorMappingForRegion -accessToken $iaasAccessToken -Body $jsonBody
}
#EndRegion MAINBODY
