# file contain helpers to read report from file and to save it

######################################### Helper functions

Function IsDirectory($path)
{
    return (test-path $path -PathType container)
}

Function CopyFileRequired ( $path )
{
    $accepted_extensions = @(".cxx", ".hxx", ".c", ".cpp", ".h", ".hpp", "Makefile")

    foreach ($extension in $accepted_extensions) {
        if ($path.EndsWith( $extension) ) {
            return $True
        }
    }

    return $False
}

Function CopyDirectoryRequired ( $path )
{
    $ignored_path = @('DirectoryToIgnore')

    return !($ignored_path.Contains($path))
}

######################################### Helper XML functions

Function WriteNodesToXMLWriter ( $writer, $elementName, $nodes)
{
    $writer.WriteStartElement($elementName)
    foreach ( $path in $nodes)
    {
        $writer.WriteStartElement("node")
        $writer.WriteAttributeString("path", $path)
        $writer.WriteEndElement()
    }
    $writer.WriteEndElement()
}

##########################################################

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

    $report_object | Add-Member -NotePropertyName IsEmpty -NotePropertyValue $True

    return $report_object
}

Function LoadReportFromFile($report_file)
{
    $content = [xml](get-content $report_file)

    $report = CreateReportObject

    $count = -1

    if ( $content.Files.ToCopy.node -ne $null) {
        foreach ($file_node in $content.Files.ToCopy.node) {
            $count = $report.FileToCopy.Add( $file_node.GetAttribute("path") )
        }
    }

    if ( $content.Files.ToDelete.node -ne $null) {
        foreach ($file_node in $content.Files.ToDelete.node) {
            $count = $report.FileToDelete.Add( $file_node.GetAttribute("path") )
        }
    }

    if ( $content.Files.Unversioned.node -ne $null) {
        foreach ($file_node in $content.Files.Unversioned.node) {
            $count = $report.FileUnversioned.Add( $file_node.GetAttribute("path") )
        }
    }

    if ( $content.Directories.ToCopy.node -ne $null) {
        foreach ($directory_node in $content.Directories.ToCopy.node) {
                $count = $report.DirectoryToCopy.Add($directory_node.GetAttribute("path") )
        }
    }

    if ( $content.Directories.ToDelete.node -ne $null) {
        foreach ($directory_node in $content.Directories.ToDelete.node) {
                $count = $report.DirectoryToDelete.Add($directory_node.GetAttribute("path") )
        }
    }

    if ( $content.Directories.Unversioned.node -ne $null) {
        foreach ($directory_node in $content.Directories.Unversioned.node) {
                $count = $report.DirectoryUnversioned.Add($directory_node.GetAttribute("path") )
        }
    }

    if ($count -ne -1) {
        $report.IsEmpty = $False
    }

    return $report
}

Function SaveReport($report_file, $report)
{
    $xml_settings = new-object System.Xml.XmlWriterSettings

    $xml_settings.Indent = $True
    $xml_settings.IndentChars = "`t"

    $writer = [System.Xml.XmlWriter]::Create($report_file, $xml_settings)

    $writer.WriteStartDocument()

    $writer.WriteStartElement("Files")

    WriteNodesToXMLWriter $writer "ToCopy" $report.FileToCopy
    WriteNodesToXMLWriter $writer "ToDelete" $report.FileToDelete
    WriteNodesToXMLWriter $writer "Unversioned" $report.FileUnversioned

    $writer.WriteEndElement() #files

    $writer.WriteStartElement("Directories")

    WriteNodesToXMLWriter $writer "ToCopy" $report.DirectoryToCopy
    WriteNodesToXMLWriter $writer "ToDelete" $report.DirectoryToDelete
    WriteNodesToXMLWriter $writer "Unversioned" $report.DirectoryUnversioned

    $writer.WriteEndElement() #Directories

    $writer.WriteEndDocument()
    $writer.Flush()
    $writer.Close()
}

Function GetSVNReport($status)
{
    $report = CreateReportObject

    $count = -1

    foreach ($entry in $status.status.target.entry)
    {
        $file_path = $entry.path
        $node = $entry.SelectSingleNode("wc-status")
        $file_status = $node.GetAttribute("item")

        if ( IsDirectory( $file_path) ) {
            if ($file_status -eq "missing") {
                $count = $report.DirectoryToDelete.add($file_path)
            }
            elseif ($file_status -eq "deleted") {
                # could be multiple entries for this directory. need to save only high order
            }
            elseif ($file_status -eq "added")  {
                # could be multiple entries for this directory. need to save only high order
            }
            elseif ($file_status -eq "modified") {
                # ignore modified directory - it should be svn properties
                write "Ignore modified directory $file_path"
            }
            elseif ($file_status -eq "unversioned") {
                if ( CopyDirectoryRequired($file_path)) {
                    $count = $report.DirectoryUnversioned.add( $file_path)
                } else {
                    write "Ignoring directory $file_path"
                }
            }
        } else {
            if ($file_status -eq "missing") {
                # missed file is not reported if directory missed or deleted
                $count = $report.FileToDelete.Add($file_path)
            }
            elseif ($file_status -eq "deleted") {
                # could be multiple entries for this directory. need to save only high order
                $directoryDeleted = $False
                foreach ( $dir in $delete_directories ) {
                    if ($file_path.StartsWith($dir) ) {
                        $directoryDeleted = $True
                        break
                    }
                }

                if ( ! $directoryDeleted ) {
                    $count = $report.FileToDelete.Add( $file_path )
                }
            }
            elseif ($file_status -eq "added")  {
                # could be multiple entries for this directory. need to save only high order
                $directory_added = $False
                foreach ( $dir in $copy_directories ) {
                    if ($file_path.StartsWith( $file_path ) ) {
                        $directory_added = $True
                        break
                    }
                }

                if ( ! $directory_added ) {
                    $count = $report.FileToCopy.add( $file_path)
                }
            }
            elseif ($file_status -eq "modified") {
                # modified file is not reported if directory was removed or deleted
                $count = $report.FileToCopy.Add($file_path)
            }
            elseif ($file_status -eq "unversioned") {
                if ( CopyFileRequired( $file_path ) ) {
                        $count = $report.FileUnversioned.Add($file_path)
                } else {
                    write "Ignoring file $file_path"
                }
            }
        }
    }

    if ( $count -ne -1) {
        $report.IsEmpty = $False
    }
}