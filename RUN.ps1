<#
This script does the following
1) count the number of columns in the given datafile
2) (re)creat a generic table with that number of columns. All columns as nvarchar(max).
3) load the data into the table
#>

# Settings
# ========

$server = '<domain>\<database>,<port>'
$username = ''
$password = ''

$database = ''
$schema = 'dbo'
$table = 'table_name'

$datafile = $PSScriptRoot + "\example_data.txt"
$separator = "`t" # Powershell format
$xml_separator = "\t" # XML formatfile format

# -------------- No changes required below this line ---------------------

cls

Write-Output "!!! WARNING !!!"
Write-Output ""
Write-Output "The table $database.$schema.$table will be dropped and recreated!"
Write-Output ""
pause
Write-Output ""

Write-Output "Assumptions"
Write-Output "==========="
    Write-Output "- UTF8"
    Write-Output "- \r\n line ends"
    Write-Output "- no encapsulation"
    Write-Output "- no headers (not skipping any rows)"
    Write-Output ""

Write-Output "Guessing number of columns"
Write-Output "=========================="
    $number_of_columns = (Get-Content $datafile -First 1).Split($separator).Count
    Write-Output "Number of columns based on first row: $number_of_columns"
    Write-Output ""

Write-Output "(Re)create table"
Write-Output "================"
    # Create temporary SQL file
    $create_table_sql = Get-Content -Path "$PSScriptRoot\lib\create_table.sql"
    $create_table_sql = $create_table_sql.Replace('{database}', $database).Replace('{schema}',$schema).Replace('{table}',$table)
    for ($i=2;$i -le 26;$i++) {
        if ($i -gt $number_of_columns) {
            $create_table_sql = $create_table_sql.Replace("{column $i}", '--')
        } else {
            $create_table_sql = $create_table_sql.Replace("{column $i}", '')
        }
    }
    $tmp = New-TemporaryFile
    Set-Content -Path $tmp -Value $create_table_sql

    # Create table
    sqlcmd -S $server -U $username -P $password -i $tmp

    # Remove temporary SQL file
    Remove-Item $tmp.FullName -Force
    Write-Output ""

Write-Output "Loading data"
Write-Output "============"
    # Create temporary formatfile
    $xml_formatfile = Get-Content -Path "$PSScriptRoot\lib\formatfile.xml"
    for ($i=1;$i -le 27;$i++) {
        if ($i -eq $number_of_columns + 1) {
            $xml_formatfile = $xml_formatfile.Replace("{column $i}", '<!--')
        } else {
            $xml_formatfile = $xml_formatfile.Replace("{column $i}", '')
        }
        if ($i -eq $number_of_columns) {
            $xml_formatfile = $xml_formatfile.Replace("{terminator $i}", '\r\n')
        } else {
            $xml_formatfile = $xml_formatfile.Replace("{terminator $i}", $xml_separator)
        }
    }
    $tmp = New-TemporaryFile
    Set-Content -Path $tmp -Value $xml_formatfile

    # Load data
    bcp "$database.$schema.$table" `
    in $datafile `
    -U $username `
    -P $password `
    -S $server `
    -f $tmp `
    -b 100000 `
    -C 65001 `
    -e "$PSScriptRoot\errors.txt" `
    -m 0

    # Remove temporary formatfile
    Remove-Item $tmp.FullName -Force

Write-Output ""
Write-Output "===="
Write-Output "DONE"
Write-Output "===="
Write-Output ""
pause

<#
Used BCP parameters
===================
-a : Packet size
-b : Batch size
-c : Char as default storage type (when not using a format file)
-C : Codepage. 65001 = UTF-8
-e : error file
-F : first row (1-based). Use to skip header row.
-L : last row. Use to only upload a testset
-k : empty columns get loaded as NULL instead of default values
-m : maximum errors. default is 10!
-t : field terminator. Default is tab. No encapsulation needed, so "-t ," works to set comma as a separator
	-t 0x1C ^ : special HEX-value separator
-w : perform copy using unicode
-T : use trusted connection
	Example usage: bcp database_name.dbo.test in "testdata.txt" -T -f "testdata.fmt" -S ECONECOOMDB1\TECHNODB,1434
	
All parameters: https://docs.microsoft.com/en-us/sql/tools/bcp-utility?view=sql-server-2017
#>