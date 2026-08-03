# LinkedIn Job Search Automation

A two-part personal automation pipeline: one component generates and delivers a resume-matched job search report, the other tracks how in-demand skills trend week over week across those same job postings. Both run unattended and email their output.

What This Project Is

Two independent but linked automations, each with a data file and a delivery script:

Component	Data File	Script
Job Matcher	LinkedIn_Job_Matches_With_Resume.txt	LinkedIn_Job_Match_Code.ps1
Skill Trend Tracker	Skill_Trend_Weekly_Basis.txt (+ Skill_Trend_Data.csv, generated)	Skill_Trend_Tracker_Code.ps1

The Job Matcher is the source-of-truth report: resume snapshot, ranked target job titles with LinkedIn search filters, confidence-scored fit analysis per title, and a curated list of specific open postings with strategic recommendations.

The Skill Trend Tracker reads that same report (plus, best-effort, live LinkedIn search result pages) and counts how often each tracked skill (SQL, Power BI, Tableau, Python, ETL, Informatica, R, SAS, Alteryx, AWS, Excel, REST API) appears. It logs those counts to a running CSV, compares them to the prior week, and flags any high-frequency skill missing from the resume's skill list.

Both scripts send their output via email using the Resend API, so the reports land in an inbox without manually running anything.

How It Works

LinkedIn_Job_Matches_With_Resume.txt (source report)
             
   LinkedIn_Job_Match_Code.ps1:
   
   • Reads the .txt report  • Base64-encodes it   • Emails it as an attachment via  • Logs to EmailSend_Log.txt              
   
   Skill_Trend_Tracker_Code.ps1:
   
   • Reads the .txt report   • Fetches live LinkedIn pages (best-effort, skips on block) • Counts skill keyword frequency • Compares vs. prior week • Flags resume gaps (skills with 5+ mentions not on resume)
    • Writes Skill_Trend_Report_<date>.txt • Emails report + logs to SkillTracker_Log.txt

Trigger: Both scripts are designed for Windows Task Scheduler — the Job Matcher on login (push the latest report whenever the machine is used), the Skill Trend Tracker weekly (build a week-over-week trend line).

Delivery: Both POST to https://api.resend.com/emails with a Bearer-token API key, attaching the relevant .txt file and a short HTML summary in the email body.

Logging: Each script writes its own timestamped log (EmailSend_Log.txt, SkillTracker_Log.txt) so a silent failure — missing file, expired key, blocked request — is diagnosable after the fact.


What It's Achieving
Turns a one-time resume match into a living search strategy. The Job Matcher isn't a static list — it explains why each title fits, what's missing, and gives the exact search filters to reproduce the results.

Converts market demand into a resume feedback loop. The Skill Trend Tracker's core value proposition is telling the candidate which skills are trending up in real postings and not yet on the resume — closing the loop from "what's in demand" to "what to add."

Removes manual repetition. Both reports arrive automatically instead of requiring a recurring manual search-and-compile session.

File Overview

File	                                      Purpose
LinkedIn_Job_Match_Code.ps1:                Emails the job matches report via Resend API
LinkedIn_Job_Matches_With_Resume.txt:	      The resume-matched job search report (source data for both components)
Skill_Trend_Tracker_Code.ps1:	              Counts skill mentions, tracks week-over-week trend, emails the trend report
Skill_Trend_Weekly_Basis.txt:	              Generated weekly output of the skill trend tracker
