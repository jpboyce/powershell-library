Param(
  [Parameter(Mandatory = $true)]
  [String[]]
  $nexposeHost,

  [Parameter(Mandatory = $false)]
  $nexposePort,

  [Parameter(Mandatory = $true)]
  $assetId,

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
$scanUri = "https://$($nexposeHost):$($nexposePort)/api/3/assets/$($assetId)/vulnerabilities"

# Set the headers
$headers = @{
  'Authorization' = $basicAuth
  'Content-Type'  = 'application/json'
}

# Call the REST cmdlet
$response = Invoke-RestMethod -Uri $scanUri -Method Get -Body $jsonPayload -Headers $headers -ContentType 'application/json'
  
# Output the vulnerabilities of the asset
write-output $response.resources