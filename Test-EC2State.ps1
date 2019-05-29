Function Test-EC2State() {
    # Tests whether the system running the script is an EC2 instance or not
    # https://gallery.technet.microsoft.com/scriptcenter/Detects-if-a-Host-is-3088cf2c
    $error.clear()
    $request = [System.Net.WebRequest]::Create('http://169.254.169.254')
    $request.Timeout = 900
    try {
        $response = $request.GetResponse()
        $response.close()
    }
    catch {
        $false
    }
    if (!$error) {
        $true
    }
}
