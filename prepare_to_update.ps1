#########################################################
#                    Settings
#########################################################

$remote_path = "Z:\dev\backend\"

$report_file = "C:\dev\sync_report.xml"

######################################################### EO settings

$copied_files = new-object System.Collections.ArrayList
$unversioned_files = new-object System.Collections.ArrayList

# read old status
if (Test-Path $report_file) {
    $content = [xml](get-content $report_file)
    Remove-Item $report_file

    if ( $content.Files.ToCopy.file -ne $null) {
        foreach ($file_node in $content.Files.ToCopy.file) {
            $count = $copied_files.Add( $file_node.GetAttribute("path") )
        }
    }

    if ( $content.Files.Unversioned.file -ne $null) {
        foreach ($file_node in $content.Files.Unversioned.file) {
            $count = $unversioned_files.Add( $file_node.GetAttribute("path") )
        }
    }

    #perfom copy
    foreach ($file in $copied_files + $unversioned_files) {
        $remote_file_path = $remote_path + $file

        write "Delete: $remote_file_path"
        Remove-Item $remote_file_path
    }

    write "Remote ready to update"
} else {
    write "Status file not found"
}