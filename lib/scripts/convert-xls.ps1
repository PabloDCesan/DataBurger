param(
  [Parameter(Mandatory=$true)][string]$InputPath,
  [Parameter(Mandatory=$true)][string]$OutputPath
)

# 51 = xlOpenXMLWorkbook (.xlsx)
$xlFixedFormat = 51

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

try {
  $wb = $excel.Workbooks.Open($InputPath)
  $wb.SaveAs($OutputPath, $xlFixedFormat)
  $wb.Close($false)
  Write-Output "OK"
} catch {
  Write-Error $_.Exception.Message
  exit 1
} finally {
  $excel.Quit() | Out-Null
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
}
