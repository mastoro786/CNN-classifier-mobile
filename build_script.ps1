$ErrorActionPreference = "Continue"
$output = & flutter build apk --debug 2>&1 | Out-String
$output | Set-Content -Path "C:\Users\IKINAI\.gemini\full_build_output.txt" -Encoding ASCII
Write-Output $output
