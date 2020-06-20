
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
  throw "There was a problem contacting server $($server)"
}

Function Get-CSPRefreshToken {
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

$CSPRefreshToken = Get-CSPRefreshToken -Username $Username -Password $Password
$iaasAccessToken = Get-iaasAccessToken -refreshToken $CSPRefreshToken
$cloudAccounts = (Get-CloudAccounts -accessToken $iaasAccessToken).content

foreach ($item in $cloudAccounts) {
  $cloudAccountType = $item.cloudAccountType
  $cloudAccountId = $item.id
  Write-Output "Account Type: $($cloudAccountType)"
  Write-Output "Account ID: $($cloudAccountId)"
  $cloudAccountRegionId = Get-CloudAccountRegions -accessToken $iaasAccessToken -cloudAccountId $cloudAccountId

  $tempFlavorMapping = @{}

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
    $Body = @{
      regionId = $cloudAccountRegionId
       name = "flavormapping"
       flavorMapping = $tempFlavorMapping
    }
    $jsonBody = $Body | ConvertTo-Json
    Add-FlavorMappingForRegion -accessToken $iaasAccessToken -Body $jsonBody
    #Invoke-RestMethod -Method POST -Uri $iaasFlavorProfilesUri -ContentType "application/json" -Body $jsonBody -Headers @{Authorization="Bearer $($iaasAccessToken)"}

}

