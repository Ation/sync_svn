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

    #remove files that were copied
    foreach ($file in $report.FileToCopy + $report.FileUnversioned) {
        $remote_file_path = join-path $remote_path $file

        write "Delete file: $remote_file_path"
        Remove-Item $remote_file_path
    }

    foreach ( $dir in $report.DirectoryToCopy + $report.DirectoryUnversioned ) {
        $remote_dir_path = join-path $remote_path $dir

        write "Delete directory: $remote_dir_path"
        Remove-Item $remote_dir_path -recurse -force
    }

    write "Remote ready to update"
} else {
    write "Status file not found"
}