. "$PSScriptRoot\report_tools.ps1"

#########################################################
#                    Settings
#########################################################

$local_src_path = "C:\dev\backend\"
$remote_src_path = "Z:\dev\backend\"

$report_file = "C:\dev\sync_report.xml"


 # if you have svn in PATH, next 3 lines should be removed

# $svn_path = "C:\dev\Tools\svn-win32-1.6.12\svn-win32-1.6.12\bin"
# if (! $env:path.Contains($svn_path)) {
#     $env:path += ";" + $svn_path
# }

######################################################### EO settings

Function GetLocalPath($file_path)
{
    return $local_src_path + $file_path
}

Function GetPathOnRemote($file_path)
{
    return $remote_src_path + $file_path
}

######################################### main #########################################

cd $local_src_path

######################################### read previous operations #########################################

$old_report = LoadReportFromFile( $report_file)
Remove-Item $report_file

######################################### get status #########################################

$status = [xml](svn st --xml)

$report = GetSVNReport( $status )

######################################### save current operations #########################################

SaveReport $report_file $report

######################################### merge operations #########################################
# to determine if we need to do restore for something

MergeReports $report $old_report

######################################### update remote repository #########################################

if (! $report.IsEmpty)
{
    #perfom copy

    # process directories first
    foreach ($directory in $report.DirectoryToCopy + $report.DirectoryUnversioned) {
        $local_directory_path = GetLocalPath( $directory ) + "\*"
        $remote_directory_path = GetPathOnRemote( $directory )

        write "Copy directory: $local_directory_path"
        Copy-item $local_directory_path $remote_directory_path -recurse
    }

    foreach ( $dir in $report.DirectoryToDelete ) {
        $remote_directory_path = GetPathOnRemote( $dir )

        write "Remove directory: $remote_directory_path"
        Remove-Item $remote_directory_path -recurse
    }

    # now process files
    foreach ($file in $report.FileToCopy + $report.FileUnversioned) {
        $local_file_path = GetLocalPath( $file)
        $remote_file_path = GetPathOnRemote($file)

        write "Copy file: $local_file_path"
        Copy-Item -Force $local_file_path $remote_file_path
    }

    foreach ($file in $report.FileToDelete) {
        $remote_file_path = GetPathOnRemote($file)

        write "Delete file: $remote_file_path"
        Remove-Item $remote_file_path
    }
} else {
    write "Nothing to update"
}

$end_time = get-date
write "Done at: $end_time"