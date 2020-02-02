Param(
  [Parameter(Mandatory = $true)]
  [String[]]
  $nexposeHost,

  [Parameter(Mandatory = $false)]
  $nexposePort,

  [Parameter(Mandatory = $true)]
  $scanId,

  [Parameter(Mandatory = $false)]
  [ValidateSet("critical", "moderate", "severe", "total")]
  $vulnerabilityType,

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
$scanUri = "https://$($nexposeHost):$($nexposePort)/api/3/scans/$($scanId)"

# Set the headers
$headers = @{
  'Authorization' = $basicAuth
  'Content-Type'  = 'application/json'
}

# Call the REST cmdlet
$response = Invoke-RestMethod -Uri $scanUri -Method Get -Headers $headers -verbose

# output depending on vulnerabilityType value
switch ($vulnerabilityType) {
  "critical" {
    Write-Output $response.vulnerabilities.critical
  }
  "moderate" {
    Write-Output $response.vulnerabilities.moderate
  }
  "severe" {
    Write-Output $response.vulnerabilities.severe
  }
  "total" {
    Write-Output $response.vulnerabilities.total
  }
  # On default, write out the entire response
  default { Write-Output $response }
}
