import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Convierte un .xls a .xlsx usando PowerShell + Excel COM en Windows.
/// Requiere Microsoft Excel instalado. Devuelve la ruta del .xlsx.
Future<String> convertXlsToXlsxWindows(String xlsPath) async {
  if (!Platform.isWindows) {
    throw UnsupportedError('Conversión .xls→.xlsx automática solo en Windows.');
  }
  final src = File(xlsPath);
  if (!await src.exists()) {
    throw ArgumentError('No existe el archivo: $xlsPath');
  }

  // Salida en temp
  final tmpDir = await getTemporaryDirectory();
  final outPath = p.join(tmpDir.path, '${p.basenameWithoutExtension(xlsPath)}_conv.xlsx');

  // 1) Intentar con script en carpeta scripts/
  String? scriptPath = await _resolveScriptPath();

  // 2) Si no existe, escribir el script embebido a temp
  scriptPath ??= await _writeEmbeddedScriptToTemp();

  final args = [
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', scriptPath,
    '-InputPath', xlsPath,
    '-OutputPath', outPath,
  ];

  final proc = await Process.run('powershell.exe', args);
  final ok = proc.exitCode == 0 &&
      (proc.stdout.toString().trim().endsWith('OK') || await File(outPath).exists());
  if (!ok) {
    final msg = 'Falló conversión .xls→.xlsx\nSTDOUT:\n${proc.stdout}\nSTDERR:\n${proc.stderr}';
    throw ProcessException('powershell.exe', args, msg, proc.exitCode);
  }
  return outPath;
}

/// Convierte un .xlsx a .csv (primera hoja) usando PowerShell + Excel COM (Windows).
/// Requiere Microsoft Excel instalado. Devuelve la ruta del .csv de salida.
Future<String> convertXlsxToCsvWindows(String xlsxPath) async {
  if (!Platform.isWindows) {
    throw UnsupportedError('La conversión .xlsx→.csv automática solo está soportada en Windows.');
  }
  final src = File(xlsxPath);
  if (!await src.exists()) {
    throw ArgumentError('No existe el archivo: $xlsxPath');
  }

  // Salida en temp
  final tmpDir = await getTemporaryDirectory();
  final outPath = p.join(tmpDir.path, '${p.basenameWithoutExtension(xlsxPath)}_conv.csv');

  // Script embebido: guarda la PRIMERA hoja como CSV
  const ps1 = r'''
param(
  [Parameter(Mandatory=$true)][string]$InputPath,
  [Parameter(Mandatory=$true)][string]$OutputPath
)
$xlCSV = 6
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
try {
  $wb = $excel.Workbooks.Open($InputPath)
  $ws = $wb.Worksheets.Item(1)
  $ws.SaveAs($OutputPath, $xlCSV)
  $wb.Close($false)
  Write-Output "OK"
} catch {
  Write-Error $_.Exception.Message
  exit 1
} finally {
  $excel.Quit() | Out-Null
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
}
''';

  final psFile = File(p.join(tmpDir.path, 'convert-xlsx-to-csv.ps1'));
  await psFile.writeAsString(ps1, encoding: const Utf8Codec());

  final args = [
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', psFile.path,
    '-InputPath', xlsxPath,
    '-OutputPath', outPath,
  ];

  final result = await Process.run('powershell.exe', args);
  final ok = result.exitCode == 0 && await File(outPath).exists();
  if (!ok) {
    throw ProcessException(
      'powershell.exe',
      args,
      'Falló conversión .xlsx→.csv\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}',
      result.exitCode,
    );
  }
  return outPath;
}

// Busca scripts/convert-xls.ps1 cerca del ejecutable o del cwd (dev).
Future<String?> _resolveScriptPath() async {
  // A) al lado del ejecutable (build windows)
  try {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final candidate = File(p.join(exeDir.path, 'scripts', 'convert-xls.ps1'));
    if (await candidate.exists()) return candidate.path;
  } catch (_) {}

  // B) cwd (útil en desarrollo)
  final candidate2 = File(p.join(Directory.current.path, 'scripts', 'convert-xls.ps1'));
  if (await candidate2.exists()) return candidate2.path;

  return null;
}

// Si no lo encuentra, lo escribe desde esta constante al temp y lo usa igual.
Future<String> _writeEmbeddedScriptToTemp() async {
  const ps1 = r'''
param(
  [Parameter(Mandatory=$true)][string]$InputPath,
  [Parameter(Mandatory=$true)][string]$OutputPath
)
$xlOpenXML = 51
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
try {
  $wb = $excel.Workbooks.Open($InputPath)
  $wb.SaveAs($OutputPath, $xlOpenXML)
  $wb.Close($false)
  Write-Output "OK"
} catch {
  Write-Error $_.Exception.Message
  exit 1
} finally {
  $excel.Quit() | Out-Null
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
}
''';

  final tmpDir = await getTemporaryDirectory();
  final file = File(p.join(tmpDir.path, 'convert-xls.ps1'));
  await file.writeAsString(ps1, encoding: const Utf8Codec());
  return file.path;
}

/// Convierte un .xls/.xlsx a JSON (primera hoja) usando PowerShell + Excel COM.
/// Devuelve la ruta al .json generado.
Future<String> convertExcelToJsonWindows(String inputPath, {String? sheetName}) async {
  if (!Platform.isWindows) {
    throw UnsupportedError('Excel→JSON automático solo en Windows.');
  }
  final src = File(inputPath);
  if (!await src.exists()) {
    throw ArgumentError('No existe el archivo: $inputPath');
  }

  final tmpDir = await getTemporaryDirectory();
  final outPath = p.join(tmpDir.path, '${p.basenameWithoutExtension(inputPath)}.json');

  // Script embebido (basado en el tuyo, con mínimos ajustes y UTF8)
  const ps1 = r'''
param(
  [Parameter(Mandatory=$true)][string]$InputFile,
  [Parameter(Mandatory=$true)][string]$OutputFileName,
  [string]$SheetName
)

$InputFile     = [System.IO.Path]::GetFullPath($InputFile)
$OutputFileName = [System.IO.Path]::GetFullPath($OutputFileName)

$excel = New-Object -ComObject Excel.Application
$excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Open($InputFile)

try {
  if (-not $SheetName) {
    if ($wb.Sheets.Count -eq 1) {
      $SheetName = @($wb.Sheets)[0].Name
    } else {
      # si hay varias hojas y no especificás, usamos la primera
      $SheetName = @($wb.Sheets)[0].Name
    }
  } else {
    $theSheet = $wb.Sheets | Where-Object { $_.Name -eq $SheetName }
    if (-not $theSheet) { throw "No existe la hoja '$SheetName' en el workbook." }
  }

  $theSheet = $wb.Sheets | Where-Object { $_.Name -eq $SheetName }

  # Headers (fila 1)
  $Headers = @{}
  $col = 1
  while ($true) {
    $cellValue = $theSheet.Cells.Item(1, $col).Text
    if ($null -eq $cellValue -or $cellValue.Trim().Length -eq 0) { break }
    $Headers.$col = $cellValue
    $col++
  }
  $NumberOfColumns = $Headers.Count

  # Filas
  $rowsToIterate = $theSheet.UsedRange.Rows.Count
  $results = @()
  for ($row = 2; $row -le ($rowsToIterate + 1); $row++) {
    $result = @{}
    foreach ($kv in $Headers.GetEnumerator()) {
      $colIndex = [int]$kv.Name
      $colName  = [string]$kv.Value
      $val = $theSheet.Cells.Item($row, $colIndex).Value2
      $result[$colName] = $val
    }
    # Filtro: descartar filas totalmente vacías
    $allEmpty = $true
    foreach ($v in $result.Values) { if ($null -ne $v -and "$v".Trim().Length -gt 0) { $allEmpty = $false; break } }
    if (-not $allEmpty) { $results += [pscustomobject]$result }
  }

  $json = $results | ConvertTo-Json -Depth 4
  # UTF8 sin BOM (por defecto en PS5/7 es UTF8-BOM; forzamos -Encoding utf8)
  Set-Content -Path $OutputFileName -Value $json -Encoding utf8

  Write-Output "OK"
}
catch {
  Write-Error $_.Exception.Message
  exit 1
}
finally {
  $wb.Close($false) | Out-Null
  $excel.Quit()    | Out-Null
  [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
}
''';

  final psFile = File(p.join(tmpDir.path, 'excel-to-json.ps1'));
  await psFile.writeAsString(ps1, encoding: const Utf8Codec());

  final args = [
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', psFile.path,
    '-InputFile', inputPath,
    '-OutputFileName', outPath,
  ];
  if (sheetName != null && sheetName.isNotEmpty) {
    args.addAll(['-SheetName', sheetName]);
  }

  final result = await Process.run('powershell.exe', args);
  final ok = result.exitCode == 0 && await File(outPath).exists();
  if (!ok) {
    throw ProcessException(
      'powershell.exe', args,
      'Falló Excel→JSON\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}',
      result.exitCode,
    );
  }
  return outPath;

}

/// Lee un CSV a memoria y lo convierte en una tabla de celdas [fila][col],
/// con soporte básico de campos entrecomillados y comillas escapadas "".
Future<List<List<String>>> _csvToTable(String csvPath, {Encoding encoding = utf8}) async {
  final lines = await File(csvPath).readAsLines(encoding: encoding);
  if (lines.isEmpty) return const <List<String>>[];

  // Autodetectar separador: ; , \t (elige el más probable en la 1ª línea)
  String detectSep(String s) {
    final cand = {';': 0, ',': 0, '\t': 0};
    for (final k in cand.keys) {
      // simple: cuenta ocurrencias fuera de comillas
      bool inQ = false;
      int c = 0;
      for (int i = 0; i < s.length; i++) {
        final ch = s[i];
        if (ch == '"') {
          if (inQ && i + 1 < s.length && s[i + 1] == '"') { i++; continue; }
          inQ = !inQ;
        } else if (!inQ && ch == k) {
          c++;
        }
      }
      cand[k] = c;
    }
    // el separador con mayor conteo
    return cand.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  final sep = detectSep(lines.first);

  List<String> splitCsvLine(String s) {
    final row = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < s.length && s[i + 1] == '"') {
          buf.write('"'); i++; // comilla escapada
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes && ch == sep) {
        row.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    row.add(buf.toString().trim());
    return row;
  }

  return lines.map(splitCsvLine).toList();
}


/// Convierte cualquier archivo soportado a tabla:
/// - .csv: parsea directo
/// - .xlsx: usa PowerShell para convertir a .csv (primera hoja) y parsea
/// - .xls:  .xls -> .xlsx -> .csv -> parsea
///
/// Requiere Windows + Excel instalado para .xls/.xlsx (como tu conversión actual).
Future<List<List<String>>> convertAnyToTable(String inputPath) async {
  final ext = p.extension(inputPath).toLowerCase();

  if (ext == '.csv') {
    return _csvToTable(inputPath);
  }

  if (ext == '.xlsx') {
    final csvPath = await convertXlsxToCsvWindows(inputPath);
    return _csvToTable(csvPath);
  }

  if (ext == '.xls') {
    final xlsxPath = await convertXlsToXlsxWindows(inputPath);
    final csvPath = await convertXlsxToCsvWindows(xlsxPath);
    return _csvToTable(csvPath);
  }

  throw FormatException('Extensión no soportada: $ext (usa .csv, .xlsx o .xls)');
}