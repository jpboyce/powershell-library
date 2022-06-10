<#
.SYNOPSIS
Purges the cache for a specified site.

.DESCRIPTION
Purges the CDN cache fully for a specified site.

.PARAMETER apiId
The API ID value.  A numeric value

.PARAMETER apiKey
The API Key value.  In a pseudo-GUID format (ie 12345678-abcd-efgh-1234-1a2b3c4d5e6f)

.PARAMETER siteId
The Site ID value.  A numeric value

.INPUTS
None

.OUTPUTS
System.Array

.EXAMPLE
PS> .\Clear-ImpervaCache.ps1 -apiId 40123 -apiKey 12345678-abcd-efgh-1234-1a2b3c4d5e6f -siteId 12345

.LINK
https://docs.imperva.com/bundle/cloud-application-security/page/api/sites-api.htm#Purge

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
    HelpMessage="Enter the Site ID value")]
    [Int32]
    $siteId
)

# Define post parameters
$postParams=@{api_id=$apiId; api_key=$apiKey; site_id=$siteId}

# Invoke-webrequest defaults to TLS 1.0 which often doesn't work.  So we are manually forcing TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Invoke-webrequest on the URL and extract the content (in JSON format)
try {
    
    $response = Invoke-WebRequest -Uri https://my.imperva.com/api/prov/v1/sites/cache/purge -Method POST -Body $postParams
    if ($response.statusCode -eq 200) {
        Write-Output "Cache was succesfully purged!"
    }
}
catch {
    Write-Host "There was an issue executing the web request!"
    Write-Host $_
}
