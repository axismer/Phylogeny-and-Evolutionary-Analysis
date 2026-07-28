# Test AI API with /v1/chat/completions path
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

$uri = "https://tokenn.online/v1/chat/completions"
Write-Host "Testing: $uri" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri $uri -Method Post -Body $body -Headers $headers -UseBasicParsing -TimeoutSec 30
    Write-Host "=== Response Status ===" -ForegroundColor Green
    Write-Host "StatusCode: $($response.StatusCode)"
    Write-Host "ContentType: $($response.Headers.'Content-Type')"
    Write-Host ""
    Write-Host "=== Response Body (first 800 chars) ===" -ForegroundColor Green
    $contentLength = [Math]::Min(800, $response.Content.Length)
    Write-Host ($response.Content.Substring(0, $contentLength))
} catch {
    Write-Host "=== Error ===" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Yellow
    if ($_.Exception.Response) {
        Write-Host "Error Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
        $reader = $_.Exception.Response.GetResponseStream()
        $streamReader = New-Object System.IO.StreamReader($reader)
        $errorBody = $streamReader.ReadToEnd()
        Write-Host "Error Body:" -ForegroundColor Yellow
        Write-Host $errorBody
        
        # Show Content-Type of error response
        Write-Host ""
        Write-Host "Error ContentType: $($_.Exception.Response.ContentType)" -ForegroundColor Yellow
    }
}
