Param(
  [Parameter(Mandatory = $true)]
  [String[]]
  $nexposeHost,

  [Parameter(Mandatory = $false)]
  $nexposePort,

  [Parameter(Mandatory = $true)]
  $assetSearchValue,

  [Parameter(Mandatory = $false)]
  $assetSearchField = "ip-address",

  [Parameter(Mandatory = $false)]
  $assetSearchMatch = "any",

  [Parameter(Mandatory = $true)]
  $restUser,
  [Parameter(Mandatory = $true)]
  $restPass
)

# Allow self-signed certs
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# Create the Basic authentication from the username and password
$restUserAndPass = "$($restUser):$($restPass)"
$bytesUserAndPass = [System.Text.Encoding]::UTF8.GetBytes($restUserAndPass)
$encodedUserAndPass = [Convert]::ToBase64String($bytesUserAndPass)
$basicAuth = "Basic $($encodedUserAndPass)"

# Set the URI 
$restUri = "https://$($nexposeHost):$($nexposePort)/api/3/assets/search"

# Set the body to be posted
$body = @{
  match   = 'any'
  filters = @( @{field = 'ip-address'
      operator         = 'is'
      value            = $assetSearchValue
    })
}
# Convert body to JSON
$jsonPayload = $body | ConvertTo-Json
# Set the headers
$headers = @{
  'Authorization' = $basicAuth
  'Content-Type'  = 'application/json'
}

# Call the REST cmdlet
$response = Invoke-RestMethod -Uri $restUri -Method Post -Body $jsonPayload -Headers $headers -ContentType 'application/json'
  
# Output the ID of the item that Nexpose uses
write-output $response.resources.id