<#
.SYNOPSIS
Adds or removes an IP address in an Imperva Policy

.DESCRIPTION
Adds or removes an IP address in an Imperva Policy

.PARAMETER apiId
The API ID value.  A numeric value

.PARAMETER apiKey
The API Key value.  In a pseudo-GUID format (ie 12345678-abcd-efgh-1234-1a2b3c4d5e6f)

.PARAMETER policyId
The ID of the policy requested.

.PARAMETER addIpAddress
The IP address to add to the policy

.PARAMETER removeIpAddress
The IP address to remove from the policy

.INPUTS
None

.OUTPUTS
None?

.EXAMPLE
PS> .\Set-ImpervaPolicyRule.ps1 -apiId 40123 -apiKey 12345678-abcd-efgh-1234-1a2b3c4d5e6f -policyId 12345 -addIPAddress 10.10.0.22

.EXAMPLE
PS> .\Set-ImpervaPolicyRule.ps1 -apiId 40123 -apiKey 12345678-abcd-efgh-1234-1a2b3c4d5e6f -policyId 12345 -removeIPAddress 10.10.0.22

.LINK
https://docs.imperva.com/bundle/cloud-application-security/page/policies-api-definition.htm

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true,
    HelpMessage="Enter the API ID value")]
    [string]
    $apiId,
    [Parameter(Mandatory=$true,
    HelpMessage="Enter the API key value")]
    [string]
    $apiKey,
    [Parameter(Mandatory=$true,
    HelpMessage="Enter the Policy ID value")]
    [Int32]
    $policyId,

    [Parameter(ParameterSetName = "addIP", Mandatory=$false,HelpMessage="Enter a valid IP address")]
    [ValidatePattern("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$")]
    [string]
    $addIPAddress,
    [Parameter(ParameterSetName = "delIP", Mandatory=$false,HelpMessage="Enter a valid IP address")]
    [ValidatePattern("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$")]
    [string]
    $removeIPAddress,

    [Parameter(Mandatory=$true,
    HelpMessage="Policy data object returned by running Get-ImpervaPolcyDetails.ps1 script")]
    [PSCustomObject]
    $policyData
)

# Define new IPs array
$newIpAddresses = @()

# Invoke-webrequest defaults to TLS 1.0 which often doesn't work.  So we are manually forcing TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


# Populate variables to use in payload construction
$policyName = $policyData.name
$policyDesc = $policyData.description
$policyAccountId = $policyData.accountId
$policySettingId = $policyData.policySettings.id
$ipaddresses = $policyData.policySettings.data.ips

# Output current count for some sanity checking and to show there has been some change
Write-Output "There are currently $($ipaddresses.count) IPs in the Policy: $($ipaddresses)"

# Manage IP data based on parameter
switch ($PSCmdlet.ParameterSetName)
{
    "addIP" { 
        Write-Output "We are adding an IP."
        # Because Powershell is dumb and won't let us simply add to an array, we need to iterate and add the values to a new array
        foreach ($ip in $ipaddresses) {
            $newIpAddresses = $newIpAddresses += $ip
        }
        # Append the new IP to the end of the new array
        $newIpAddresses = $newIpAddresses += $addIPAddress

    }
    "delIP" { 
        Write-Output "We are removing an IP" 
        # Because Powershell is dumb and won't let us simply remove from an array, we need to iterate and add the values to a new array, minus the IP to remove
        foreach ($ip in $ipaddresses) {
            if ($ip -ne $removeIPAddress) {
                # We want to keep all the other IP addresses, so we check for all that don't match $removeIPAddress
                $newIpAddresses = $newIpAddresses += $ip
            }
        }
    }
}

# Write out IP count for sanity checking
Write-Output "IP Array now has $($newIpAddresses.Count) IPs"

# Convert new IP array to a format that can be used in the payload
$payloadIPAddresses = ($newIpAddresses | ForEach-Object{'"{0}"' -f $_}) -join ','


# Construct payload for request
$payload = @"
{
    "name": "$policyName",
    "description": "$policyDesc",
    "enabled": true,
    "accountId": $policyAccountId,
    "policyType": "WHITELIST",
    "policySettings": [
        {
            "id": "$policySettingId",
            "policyId": $policyId,
            "settingsAction": "ALLOW",
            "policySettingType": "IP",
            "data": {
                "ips": [
                    $payloadIPAddresses
                ]
            }
        }
    ]
}
"@

# Headers for the REST API call
$headers = @{
    "Accept"="application/json"
    "Content-Type"="application/json"
}

# Output payload
Write-Output "The payload is below:"
$payload

# Invoke-webrequest on the URL and extract the content (in JSON format)
Write-Output "Attempting update..."
try {
    $response = Invoke-WebRequest -Uri "https://api.imperva.com/policies/v2/policies/$($policyId)?api_id=$apiId&api_key=$apiKey" -Method PUT -Body $payload -Headers $headers  -UseBasicParsing
    if ($response.statusCode -eq 200) {
        # Recieved a valid HTTP 200 response, so extract content
        Write-Output "A HTTP 200 OK code was returned, so we can assume the change was successful.  The response data is below"
        Write-Output $response
        # $jsonData = $response.content
    }
}
catch {
    Write-Output "There was an issue executing the web request!"
    Write-Output $_
    throw
}