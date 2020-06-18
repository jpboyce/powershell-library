
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
# Diagnostic Output
Write-Verbose "Using server name: $($Server)"
Write-Verbose "Using cspLoginUri: $($cspLoginUri)"
Write-Verbose "Using iaasLoginUri: $($iaasLoginUri)"
Write-Verbose "Using iaasCloudAccountsUri: $($iaasCloudAccountsUri)"
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

$CSPRefreshToken = Get-CSPRefreshToken -Username $Username -Password $Password
$iaasAccessToken = Get-iaasAccessToken -refreshToken $CSPRefreshToken
$cloudAccounts = (Get-CloudAccounts -accessToken $iaasAccessToken).content

foreach ($item in $cloudAccounts) {
  Write-Output "Account Type: $($item.cloudAccountType)"
}