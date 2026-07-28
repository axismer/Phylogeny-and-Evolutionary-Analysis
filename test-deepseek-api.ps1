# Test DeepSeek API
$body = @{
    model = "deepseek-chat"
    messages = @(
        @{role="system"; content="You are a helpful assistant."},
        @{role="user"; content="Hello, this is a test message from Phylogeny platform."}
    )
    temperature = 0.7
} | ConvertTo-Json

$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer sk-7f13ae6f73994bd7a2622eead1a94a5d"
}

$uri = "https://api.deepseek.com/v1/chat/completions"
Write-Host "Testing DeepSeek API: $uri" -ForegroundColor Cyan
Write-Host "Request Body:" -ForegroundColor Yellow
Write-Host $body
Write-Host ""

try {
    $response = Invoke-WebRequest -Uri $uri -Method Post -Body $body -Headers $headers -UseBasicParsing -TimeoutSec 30
    Write-Host "=== Response Status ===" -ForegroundColor Green
    Write-Host "StatusCode: $($response.StatusCode)"
    Write-Host "ContentType: $($response.Headers.'Content-Type')"
    Write-Host ""
    Write-Host "=== Response Body ===" -ForegroundColor Green
    Write-Host $response.Content
    
    # Parse and show answer
    $jsonResponse = $response.Content | ConvertFrom-Json
    if ($jsonResponse.choices -and $jsonResponse.choices[0].message) {
        Write-Host ""
        Write-Host "=== AI Response ===" -ForegroundColor Magenta
        Write-Host $jsonResponse.choices[0].message.content
    }
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
    }
}
