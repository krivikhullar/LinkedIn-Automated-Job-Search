# =============================================================================
# Powershell_Send_File.ps1
# Sends LinkedIn Job Matches file via Resend API on login.
# Log file is written to the same folder so Task Scheduler failures are visible.
# =============================================================================

# --- 1. CONFIGURATION ---
$apiKey    = "re_Y3qNUyMF_HYcGUYLoGququB1NJ3a84z5k"
$fromEmail = "onboarding@resend.dev"
$toEmail   = "lakhesh@yahoo.com"
# $ccEmail = "lakhesh@yahoo.com"  # CC disabled: onboarding@resend.dev only delivers to your own account email.
# To re-enable CC, verify a domain at resend.com/domains and update $fromEmail below.
$filePath  = "C:\Users\krivi\Desktop\Claude_Workspace\LinkedIn Job_Matches_With_Resume.txt"
$logFile   = "C:\Users\krivi\Desktop\Claude_Workspace\EmailSend_Log.txt"

# --- LOGGING HELPER ---
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

Write-Log "Script started."

# --- 2. VERIFY FILE EXISTS ---
if (-not (Test-Path $filePath)) {
    Write-Log "ERROR: File not found: $filePath"
    exit 1
}

# --- 3. PREPARE THE FILE ATTACHMENT ---
$fileName  = [System.IO.Path]::GetFileName($filePath)
$fileBytes = [System.IO.File]::ReadAllBytes($filePath)
$base64    = [System.Convert]::ToBase64String($fileBytes)
Write-Log "File prepared: $fileName ($($fileBytes.Length) bytes)"

# --- 4. BUILD THE JSON PAYLOAD ---
$payload = @{
    from        = $fromEmail
    to          = @($toEmail)
    subject     = "Claude Cowork: LinkedIn Job Matches - Updated File"
    html        = "<p><strong>Your LinkedIn Job Matches file has been updated.</strong></p><p>The latest version is attached.</p>"
    attachments = @(
        @{
            content  = $base64
            filename = $fileName
        }
    )
}

$bodyJson  = $payload | ConvertTo-Json -Depth 10
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyJson)

# --- 5. SEND THE REQUEST ---
$headers = @{
    "Authorization" = "Bearer $apiKey"
    "Content-Type"  = "application/json"
    "User-Agent"    = "PowerShellAutomation/1.0"
}

Write-Log "Sending email to $toEmail via Resend API..."

try {
    $response = Invoke-RestMethod `
        -Method      Post `
        -Uri         "https://api.resend.com/emails" `
        -Headers     $headers `
        -Body        $bodyBytes `
        -ContentType "application/json"

    Write-Log "SUCCESS: Email sent. Resend message ID: $($response.id)"
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $errorBody  = ""
    try {
        $stream    = $_.Exception.Response.GetResponseStream()
        $reader    = New-Object System.IO.StreamReader($stream)
        $errorBody = $reader.ReadToEnd()
    }
    catch { }

    Write-Log "ERROR: HTTP $statusCode - $($_.Exception.Message)"
    Write-Log "API Response: $errorBody"
    Write-Log "Exception: $($_.ToString())"
}
