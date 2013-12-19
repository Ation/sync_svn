. "$PSScriptRoot\script.ps1"

# creates object that will be used for reports on 
Function CreateReportObject
{
    $report_object = new-object PSObject
    $report_object | Add-Member -NotePropertyName FileToCopy -NotePropertyValue (New-Object System.Collections.ArrayList)
    $report_object | Add-Member -NotePropertyName FileToDelete -NotePropertyValue (New-Object System.Collections.ArrayList)
    $report_object | Add-Member -NotePropertyName FileUnversioned -NotePropertyValue (New-Object System.Collections.ArrayList)
    
    $report_object | Add-Member -NotePropertyName DirectoryToCopy -NotePropertyValue (New-Object System.Collections.ArrayList)
    $report_object | Add-Member -NotePropertyName DirectoryToDelete -NotePropertyValue (New-Object System.Collections.ArrayList)
    $report_object | Add-Member -NotePropertyName DirectoryUnversioned -NotePropertyValue (New-Object System.Collections.ArrayList)

    return $report_object
}

Function LoadReportFromFile($report_file)
{
    $content = [xml](get-content $report_file)

    $report = CreateReportObject

    if ( $content.Files.ToCopy.file -ne $null) {
        foreach ($file_node in $content.Files.ToCopy.file) {
            $count = $report.FileToCopy.Add( $file_node.GetAttribute("path") )
        }
    }

    if ( $content.Files.ToDelete.file -ne $null) {
        foreach ($file_node in $content.Files.ToDelete.file) {
            $count = $report.FileToDelete.Add( $file_node.GetAttribute("path") )
        }
    }

    if ( $content.Files.Unversioned.file -ne $null) {
        foreach ($file_node in $content.Files.Unversioned.file) {
            $count = $report.FileUnversioned.Add( $file_node.GetAttribute("path") )
        }
    }

    if ( $content.Directories.ToCopy.directory -ne $null) {
        foreach ($directory_node in $content.Directories.ToCopy.directory) {
                $count = $report.DirectoryToCopy.Add($directory_node.GetAttribute("path") )
        }
    }

    if ( $content.Directories.ToDelete.directory -ne $null) {
        foreach ($directory_node in $content.Directories.ToDelete.directory) {
                $count = $report.DirectoryToDelete.Add($directory_node.GetAttribute("path") )
        }
    }

    if ( $content.Directories.Unversioned.directory -ne $null) {
        foreach ($directory_node in $content.Directories.Unversioned.directory) {
                $count = $report.DirectoryUnversioned.Add($directory_node.GetAttribute("path") )
        }
    }

    return $report
}