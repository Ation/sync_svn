if ( $args.count -ne 2) {
    write "Usage: <report file> <remote path>"
    return
}
 
. "$PSScriptRoot\report_tools.ps1"

#########################################################
#                    Settings
#########################################################

$report_file = $args[0]

$remote_path = $args[1]

######################################################### EO settings

# read old status
if (Test-Path $report_file) {
    $report = LoadReportFromFile( $report_file)
    Remove-Item $report_file

    #perfom copy
    foreach ($file in $report.FileToCopy + $report.FileUnversioned) {
        $remote_file_path = $remote_path + $file

        write "Delete: $remote_file_path"
        Remove-Item $remote_file_path
    }

    write "Remote ready to update"
} else {
    write "Status file not found"
}