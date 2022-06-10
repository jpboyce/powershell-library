<#
.SYNOPSIS
Gets detailed settings of a specific policy

.DESCRIPTION
Queries the Imperva REST API for detailed settings of a specific policy

.PARAMETER apiId
The API ID value.  A numeric value

.PARAMETER apiKey
The API Key value.  In a pseudo-GUID format (ie 12345678-abcd-efgh-1234-1a2b3c4d5e6f)

.PARAMETER policyId
The ID of the policy requested.

.INPUTS
None

.OUTPUTS
System.Array

.EXAMPLE
PS> .\Get-ImpervaPolicyDetails.ps1 -apiId 40123 -apiKey 12345678-abcd-efgh-1234-1a2b3c4d5e6f -policyId 12345

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
    $policyId
)
# Define post parameters
$postParams=@{api_id=$apiId; api_key=$apiKey}

# Invoke-webrequest defaults to TLS 1.0 which often doesn't work.  So we are manually forcing TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Invoke-webrequest on the URL and extract the content (in JSON format)
try {
    $response = Invoke-WebRequest -Uri "https://api.imperva.com/policies/v2/policies/$($policyId)?extended=true" -Method GET -Body $postParams  -UseBasicParsing
    if ($response.statusCode -eq 200) {
        # Recieved a valid HTTP 200 response, so extract content
        $jsonData = $response.content
        # Convert to a useful format
        $data = (ConvertFrom-Json -InputObject $jsonData).value
    }
}
catch {
    Write-Error "There was an issue executing the web request!"
}
return $data
