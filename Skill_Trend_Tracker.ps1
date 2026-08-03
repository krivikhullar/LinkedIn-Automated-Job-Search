# =============================================================================
# Skill_Trend_Tracker.ps1
# Automated Job Market Skill Trend Tracker
#
# What it does each time it runs (weekly via Task Scheduler):
#   1. Reads your LinkedIn Job Matches file for skill keyword counts
#   2. Tries to fetch fresh data from LinkedIn job search pages
#   3. Counts how often each skill appears across all job descriptions
#   4. Appends results to Skill_Trend_Data.csv (builds week-over-week history)
#   5. Generates a plain-text trend report comparing this week vs last week
#   6. Emails the report to you via Resend API
#
# Resume talking point:
#   "I built an automated ETL pipeline that extracts skill demand data from
#    LinkedIn weekly, tracks frequency trends over time in a CSV data store,
#    and delivers a ranked insight report to my inbox every Monday."
# =============================================================================

# --- CONFIGURATION ---
$apiKey        = "re_Y3qNUyMF_HYcGUYLoGququB1NJ3a84z5k"
$fromEmail     = "onboarding@resend.dev"
$toEmail       = "krivikhullar@gmail.com"
$workspace     = "C:\Users\krivi\Desktop\Claude_Workspace"
$logFile       = "$workspace\SkillTracker_Log.txt"
$csvFile       = "$workspace\Skill_Trend_Data.csv"
$matchFile     = "$workspace\LinkedIn Job_Matches_With_Resume.txt"
$weekLabel     = Get-Date -Format "yyyy-MM-dd"
$reportFile    = "$workspace\Skill_Trend_Report_$weekLabel.txt"

# --- SKILLS TO TRACK ---
# Edit this list anytime to add or remove skills
$skills = @(
    "SQL", "Power BI", "Tableau", "Python", "ETL", "Informatica",
    "R", "SAS", "Alteryx", "AWS", "Excel", "REST API"
)

# --- LINKEDIN SEARCH URLS (same ones in your job matches file) ---
$searchURLs = @(
    "https://www.linkedin.com/jobs/search/?keywords=Junior+Data+Analyst+ETL+SQL&f_E=1%2C2&location=United+States",
    "https://www.linkedin.com/jobs/search/?keywords=Entry+Level+ETL+Developer+Informatica&f_E=1%2C2&location=United+States",
    "https://www.linkedin.com/jobs/search/?keywords=Business+Intelligence+Analyst+Entry+Level+Tableau&f_E=1%2C2&location=United+States",
    "https://www.linkedin.com/jobs/search/?keywords=Junior+BI+Developer+Power+BI&f_E=1%2C2&location=United+States",
    "https://www.linkedin.com/jobs/search/?keywords=Junior+Data+Engineer+ETL+SQL&f_E=1%2C2&location=United+States"
)

# --- LOGGING HELPER ---
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

# --- COUNT SKILL MENTIONS IN A TEXT BLOCK ---
function Count-Skills {
    param([string]$Text)
    $counts = @{}
    $upperText = $Text.ToUpper()
    foreach ($skill in $skills) {
        $upperSkill = $skill.ToUpper()
        $count = 0
        $pos = 0
        while (($pos = $upperText.IndexOf($upperSkill, $pos)) -ge 0) {
            $count++
            $pos += $upperSkill.Length
        }
        $counts[$skill] = $count
    }
    return $counts
}

# =============================================================================
# STEP 1 - START
# =============================================================================
Write-Log "=== Skill Trend Tracker started ==="

# =============================================================================
# STEP 2 - READ LOCAL JOB MATCHES FILE
# =============================================================================
$allText = ""

if (Test-Path $matchFile) {
    $allText += [System.IO.File]::ReadAllText($matchFile)
    Write-Log "Loaded local job matches file ($($allText.Length) chars)"
} else {
    Write-Log "WARNING: Job matches file not found at $matchFile"
}

# =============================================================================
# STEP 3 - FETCH FRESH LINKEDIN DATA (best-effort, skips if blocked)
# =============================================================================
$fetchedPages = 0
$headers = @{
    "User-Agent"      = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    "Accept-Language" = "en-US,en;q=0.9"
    "Accept"          = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
}

foreach ($url in $searchURLs) {
    try {
        $response = Invoke-WebRequest -Uri $url -Headers $headers -TimeoutSec 15 -UseBasicParsing -ErrorAction Stop
        $pageText = $response.Content
        # Strip HTML tags to get plain text
        $plainText = [System.Text.RegularExpressions.Regex]::Replace($pageText, "<[^>]+>", " ")
        $allText += " " + $plainText
        $fetchedPages++
        Write-Log "Fetched LinkedIn page ($($plainText.Length) chars): $($url.Substring(0,60))..."
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Log "INFO: Could not fetch LinkedIn page (may require login) - using local data only"
        break
    }
}

Write-Log "Total text collected: $($allText.Length) chars from local file + $fetchedPages LinkedIn pages"

# =============================================================================
# STEP 4 - COUNT SKILL FREQUENCIES
# =============================================================================
Write-Log "Counting skill keyword frequencies..."
$currentCounts = Count-Skills -Text $allText

# =============================================================================
# STEP 5 - LOAD PREVIOUS WEEK DATA FROM CSV (if it exists)
# =============================================================================
$previousCounts = @{}
$previousWeekLabel = "none"

if (Test-Path $csvFile) {
    $csvData = Import-Csv -Path $csvFile
    # Get the most recent week that is NOT today
    $weeks = $csvData | Select-Object -ExpandProperty Week | Sort-Object -Unique | Where-Object { $_ -ne $weekLabel }
    if ($weeks.Count -gt 0) {
        $previousWeekLabel = $weeks[-1]
        $prevRows = $csvData | Where-Object { $_.Week -eq $previousWeekLabel }
        foreach ($row in $prevRows) {
            $previousCounts[$row.Skill] = [int]$row.Count
        }
        Write-Log "Loaded previous week data from: $previousWeekLabel ($($previousCounts.Count) skills)"
    } else {
        Write-Log "No previous week data found - this is the baseline run"
    }
} else {
    Write-Log "No CSV found - creating new Skill_Trend_Data.csv"
    # Write CSV header
    "Week,Skill,Count" | Set-Content -Path $csvFile -Encoding UTF8
}

# =============================================================================
# STEP 6 - APPEND CURRENT WEEK TO CSV
# =============================================================================
# Remove any existing rows for today (allows re-running same day)
if (Test-Path $csvFile) {
    $existing = Import-Csv -Path $csvFile | Where-Object { $_.Week -ne $weekLabel }
    if ($existing) {
        $existing | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
    } else {
        "Week,Skill,Count" | Set-Content -Path $csvFile -Encoding UTF8
    }
}

foreach ($skill in $skills) {
    $count = $currentCounts[$skill]
    "$weekLabel,$skill,$count" | Add-Content -Path $csvFile -Encoding UTF8
}
Write-Log "Appended this week's data to $csvFile"

# =============================================================================
# STEP 7 - BUILD THE TREND REPORT
# =============================================================================
Write-Log "Building trend report..."

# Sort skills by current count descending
$ranked = $skills | Sort-Object { $currentCounts[$_] } -Descending

$lines = @()
$lines += "==============================================================="
$lines += "  JOB MARKET SKILL TREND REPORT - Krivi Khullar"
$lines += "  Week of: $weekLabel"
$lines += "  Data sources: Local job matches file + $fetchedPages live LinkedIn pages"
$lines += "==============================================================="
$lines += ""
$lines += "SKILL FREQUENCY RANKINGS (mentions across all job descriptions)"
$lines += "---------------------------------------------------------------"
$lines += ""

$rank = 1
foreach ($skill in $ranked) {
    $cur = $currentCounts[$skill]
    if ($cur -eq 0) { continue }

    $changeStr = ""
    if ($previousCounts.ContainsKey($skill) -and $previousWeekLabel -ne "none") {
        $prev = $previousCounts[$skill]
        $diff = $cur - $prev
        if ($diff -gt 0)      { $changeStr = "  [+$diff vs $previousWeekLabel - RISING]" }
        elseif ($diff -lt 0)  { $changeStr = "  [$diff vs $previousWeekLabel - falling]" }
        else                  { $changeStr = "  [no change vs $previousWeekLabel]" }
    } elseif ($previousWeekLabel -eq "none") {
        $changeStr = "  [baseline - no prior week yet]"
    }

    $lines += "  #$rank  $skill : $cur mentions$changeStr"
    $rank++
}

$lines += ""
$lines += "---------------------------------------------------------------"
$lines += "SKILLS NOT MENTIONED THIS WEEK (consider removing from resume)"
$lines += "---------------------------------------------------------------"
$zeroSkills = $skills | Where-Object { $currentCounts[$_] -eq 0 }
if ($zeroSkills.Count -gt 0) {
    foreach ($s in $zeroSkills) { $lines += "  - $s" }
} else {
    $lines += "  (all tracked skills found in job descriptions)"
}

$lines += ""
$lines += "---------------------------------------------------------------"
$lines += "YOUR RESUME SKILL GAP ALERTS"
$lines += "---------------------------------------------------------------"
$resumeSkills = @("SQL", "Power BI", "Tableau", "Python", "ETL", "Informatica", "REST API", "SQL Server", "Alteryx", "R", "SAS")
$notOnResume  = $ranked | Where-Object { $currentCounts[$_] -gt 5 -and $resumeSkills -notcontains $_ }
if ($notOnResume.Count -gt 0) {
    $lines += "These skills appear 5+ times in job postings but are NOT on"
    $lines += "your resume - consider adding them if you have any exposure:"
    $lines += ""
    foreach ($s in $notOnResume) {
        $lines += "  * $s ($($currentCounts[$s]) mentions)"
    }
} else {
    $lines += "  Great - your resume covers all high-frequency skills found."
}

$lines += ""
$lines += "---------------------------------------------------------------"
$lines += "CSV DATA FILE (for Tableau / Power BI import)"
$lines += "---------------------------------------------------------------"
$lines += "  $csvFile"
$lines += "  Import this into Tableau or Power BI to visualize your"
$lines += "  personal skill demand trend chart over time."
$lines += ""
$lines += "==============================================================="
$lines += "  Generated by Skill_Trend_Tracker.ps1 | $weekLabel"
$lines += "==============================================================="

$reportContent = $lines -join "`r`n"
[System.IO.File]::WriteAllText($reportFile, $reportContent, [System.Text.Encoding]::UTF8)
Write-Log "Report written to $reportFile"

# =============================================================================
# STEP 8 - EMAIL THE REPORT VIA RESEND API
# =============================================================================
$fileName  = [System.IO.Path]::GetFileName($reportFile)
$fileBytes = [System.IO.File]::ReadAllBytes($reportFile)
$base64    = [System.Convert]::ToBase64String($fileBytes)

# Build HTML summary of top 5 skills for the email body
$top5 = $ranked | Select-Object -First 5
$htmlRows = ""
foreach ($s in $top5) {
    $c = $currentCounts[$s]
    $htmlRows += "<tr><td style='padding:4px 12px;'><strong>$s</strong></td><td style='padding:4px 12px;'>$c mentions</td></tr>"
}
$htmlBody = "<h2>Weekly Skill Trend Report - $weekLabel</h2><p>Your automated job market tracker has run. Top 5 in-demand skills this week:</p><table border='1' cellpadding='0' cellspacing='0' style='border-collapse:collapse;'>$htmlRows</table><p>Full report with trend comparisons and gap analysis is attached.</p><p><em>Sent by Skill_Trend_Tracker.ps1 - Task Scheduler automation</em></p>"

$payload = @{
    from        = $fromEmail
    to          = @($toEmail)
    subject     = "Skill Trend Report - Week of $weekLabel"
    html        = $htmlBody
    attachments = @(
        @{
            content  = $base64
            filename = $fileName
        }
    )
}

$bodyJson  = $payload | ConvertTo-Json -Depth 10
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyJson)

$reqHeaders = @{
    "Authorization" = "Bearer $apiKey"
    "Content-Type"  = "application/json"
    "User-Agent"    = "PowerShellAutomation/1.0"
}

Write-Log "Sending trend report email to $toEmail..."

try {
    $response = Invoke-RestMethod `
        -Method      Post `
        -Uri         "https://api.resend.com/emails" `
        -Headers     $reqHeaders `
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
}

Write-Log "=== Skill Trend Tracker finished ==="
