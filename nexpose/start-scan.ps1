Param(
  [Parameter(Mandatory = $true)]
  [String[]]
  $nexposeHost,

  [Parameter(Mandatory = $false)]
  $nexposePort,

  [Parameter(Mandatory = $true)]
  $siteId,

  [Parameter(Mandatory = $false)]
  $scanTarget,

  [Parameter(Mandatory = $true)]
  $restUser,
  [Parameter(Mandatory = $true)]
  $restPass
)
# Allow self-signed certs
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $True }

# Create the Basic authentication from the username and password
$restUserAndPass = "$($restUser):$($restPass)"
$bytesUserAndPass = [System.Text.Encoding]::UTF8.GetBytes($restUserAndPass)
$encodedUserAndPass = [Convert]::ToBase64String($bytesUserAndPass)
$basicAuth = "Basic $($encodedUserAndPass)"

# Set the URI 
$scanUri = "https://$($nexposeHost):$($nexposePort)/api/3/sites/$($siteId)/scans"

# Set the body to be posted
$body = @{
  name       = 'QA scan by API'
  templateId = 'full-audit'
  hosts      = @($scanTarget)
}

# Convert body to JSON
$jsonPayload = $body | ConvertTo-Json

# Set the headers
$headers = @{
  'Authorization' = $basicAuth
  'Content-Type'  = 'application/json'
}

# Call the REST cmdlet
$response = Invoke-RestMethod -Uri $scanUri -Method Post -Body $jsonPayload -Headers $headers -ContentType 'application/json'

# Write the ID of the scan that was created
Write-Output $response.id
