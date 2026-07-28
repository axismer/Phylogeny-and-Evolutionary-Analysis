# Test AI API connectivity
$body = @{
    model = "gpt-3.5-turbo"
    messages = @(
        @{role="user"; content="Test message"}
    )
    temperature = 0.7
} | ConvertTo-Json

$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer sk-ALNs0Ne3sJIhMtcAzY9fzStbWU5SVyTyXHK1SMeTqFi8eWYq"
}

try {
    $response = Invoke-WebRequest -Uri "https://tokenn.online/" -Method Post -Body $body -Headers $headers -UseBasicParsing -TimeoutSec 30
    Write-Host "=== Response Status ==="
    Write-Host "StatusCode: $($response.StatusCode)"
    Write-Host "ContentType: $($response.Headers.'Content-Type')"
    Write-Host ""
    Write-Host "=== Response Body (first 500 chars) ==="
    Write-Host ($response.Content.Substring(0, [Math]::Min(500, $response.Content.Length)))
} catch {
    Write-Host "=== Error ==="
    Write-Host $_.Exception.Message
    if ($_.Exception.Response) {
        Write-Host "Error Status: $($_.Exception.Response.StatusCode)"
        $reader = $_.Exception.Response.GetResponseStream()
        $streamReader = New-Object System.IO.StreamReader($reader)
        $errorBody = $streamReader.ReadToEnd()
        Write-Host "Error Body:"
        Write-Host $errorBody
    }
}
