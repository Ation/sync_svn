if ( $args.Count -ne 3) {
    write "Usage: <report file> <local path> <remote path>"
    return
}

#check if svn acessible
try {
    $dummy = svn help
} 
catch
{
    write "ERROR: SVN not found"
    return
}

. "$PSScriptRoot\report_tools.ps1"

#########################################################
#                    Settings
#########################################################

$report_file = $args[0]

$local_src_path = $args[1]
$remote_src_path = $args[2]

######################################################### EO settings

Function GetLocalPath($file_path)
{
    return join-path $local_src_path $file_path
}

Function GetPathOnRemote($file_path)
{
    return join-path $remote_src_path $file_path
}

######################################### main #########################################

cd $local_src_path

######################################### read previous operations #########################################

$old_report = LoadReportFromFile( $report_file)
if ( Test-Path $report_file ) {
    Remove-Item $report_file
}

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
    # process directories first
    foreach ($directory in $report.DirectoryToCopy + $report.DirectoryUnversioned) {
        $local_directory_path = GetLocalPath( $directory ) + "\*"
        $remote_directory_path = GetPathOnRemote( $directory )

        write "Copy directory: $remote_directory_path"
        if ( test-path $remote_directory_path ) {
            # if directory should be copied - old version should be removed if exists
            Remove-Item $remote_directory_path -recurse -force
        }

        Copy-Item -force -recurse $local_directory_path $remote_directory_path
    }

    foreach ( $directory in $report.DirectoryToDelete ) {
        $remote_directory_path = GetPathOnRemote( $directory )        

        write "Delete directory: $remote_directory_path"
        if (test-path $remote_directory_path) {
            Remove-Item -recurse -force $remote_directory_path
        } else {
            write "Directory missing on the remote"
        }
    }

    # now process files
    foreach ($file in $report.FileToCopy + $report.FileUnversioned) {
        $local_file_path = GetLocalPath( $file)
        $remote_file_path = GetPathOnRemote($file)

        write "Copy file: $remote_file_path"
        Copy-Item -Force $local_file_path $remote_file_path
    }

    foreach ($file in $report.FileToDelete) {
        $remote_file_path = GetPathOnRemote($file)

        write "Delete file: $remote_file_path"
        if (test-path $remote_file_path) {
            Remove-Item $remote_file_path
        } else {
            write "File is missing on the remote"
        }
    }
} else {
    write "Nothing to update"
}

$end_time = get-date
write "Done at: $end_time"