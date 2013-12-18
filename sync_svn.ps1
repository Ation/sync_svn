#########################################################
#                    Settings
#########################################################

$local_src_path = "C:\dev\backend\"
$remote_path = "Z:\dev\backend\"

$report_file = "C:\dev\sync_report.xml"

 # if you have svn in PATH, next 3 lines should be removed

$svn_path = "C:\dev\Tools\svn-win32-1.6.12\svn-win32-1.6.12\bin"
if (! $env:path.Contains($svn_path)) {
    $env:path += ";" + $svn_path
}

######################################################### EO settings


Function CopyRequired ( $path )
{
    $accepted_extensions = @(".cxx", ".hxx", ".c", ".cpp", ".h", ".hpp", "Makefile")

    if ( test-path $path -PathType Leaf) {
        foreach ($extension in $accepted_extensions) {
            if ($path.EndsWith( $extension) ) {
                return $True
            }
        }
    }

    return $False
}

Function WriteFilesToXMLWriter( $writer, $elementName, $files)
{
    $writer.WriteStartElement($elementName)
    foreach ( $path in $files)
    {
        $writer.WriteStartElement("file")
        $writer.WriteAttributeString("path", $path)
        $writer.WriteEndElement()
    }
    $writer.WriteEndElement()
}

cd $local_src_path

$old_copied_files = new-object System.Collections.ArrayList
$old_deleted_files = new-object System.Collections.ArrayList
$old_unversioned_files = new-object System.Collections.ArrayList

# read old status
if (Test-Path $report_file) {
    $content = [xml](get-content $report_file)
    Remove-Item $report_file

    if ( $content.Files.ToCopy.file -ne $null) {
        foreach ($file_node in $content.Files.ToCopy.file) {
            $count = $old_copied_files.Add( $file_node.GetAttribute("path") )
        }
    }

    if ( $content.Files.ToDelete.file -ne $null) {
        foreach ($file_node in $content.Files.ToDelete.file) {
            $count = $old_deleted_files.Add( $file_node.GetAttribute("path") )
        }
    }

    if ( $content.Files.Unversioned.file -ne $null) {
        foreach ($file_node in $content.Files.Unversioned.file) {
            $count = $old_unversioned_files.Add( $file_node.GetAttribute("path") )
        }
    }
}

$status = [xml](svn st --xml)

$copy_files = new-object System.Collections.ArrayList
$delete_files = new-object System.Collections.ArrayList
$unversioned_files = new-object System.Collections.ArrayList

#create new actions list
foreach ($entry in $status.status.target.entry)
{
    $file_path = $entry.path
    $node = $entry.SelectSingleNode("wc-status")
    $file_status = $node.GetAttribute("item")

    if ( ($file_status -eq "missing") -or ($file_status -eq "deleted") )
    {
        $dummy = $delete_files.Add($file_path)
    }
    elseif ( ($file_status -eq "added") -or ($file_status -eq "modified") )
    {
        $dummy = $copy_files.Add($file_path)
    }
    elseif ($file_status -eq "unversioned")
    {
        # check if it is a source file
        if ( CopyRequired($file_path) )
        {
            $dummy = $unversioned_files.Add($file_path)
        } else {
            write "Ignoring $file_path"
        }
    }
}

#save current changes (merged changes will be restoring)
$xml_settings = new-object System.Xml.XmlWriterSettings

$xml_settings.Indent = $True
$xml_settings.IndentChars = "`t"

$writer = [System.Xml.XmlWriter]::Create($report_file, $xml_settings)

$writer.WriteStartDocument()

$writer.WriteStartElement("Files")


WriteFilesToXMLWriter $writer "ToCopy" $copy_files

WriteFilesToXMLWriter $writer "ToDelete" $delete_files

WriteFilesToXMLWriter $writer "Unversioned" $unversioned_files

$writer.WriteEndElement() #files

$writer.WriteEndDocument()
$writer.Flush()
$writer.Close()

#merge lists
foreach ($file in $old_unversioned_files) {
    if ( ! $unversioned_files.Contains($file) ) {
        if ( ! ( $copy_files.Contains($file) -or $delete_files.Contains($file) ) ) {
            #unversioned file is not in there any more
            $dummy = $delete_files.Add($file)
        }
    }
}

foreach ($file in $old_copied_files) {
    if ( ! ( $copy_files.Contains($file) -or $unversioned_files.Contains($file) ) )
    {
        #file need to be restored
        $dummy = $copy_files.Add($file)
    }
}

foreach ($file in $old_deleted_files) {
    if ( ! $delete_files.Contains( $file) ) {
        #file need to be restored
        if ( ! ( $copy_files.Contains($file) -or $delete_files.Contains($file) ) )
        {
            $local_file_path = $local_src_path + $file
            if (Test-Path $local_file_path) {
                $dummy = $copy_files.Add($file)
            } else {
                $dummy = $delete_files.Add($file)
            }
        }
    }
}

$haveWork = ($copy_files.count -ne 0) -or ($unversioned_files.count -ne 0) -or ($delete_files.count -ne 0)

if ($haveWork)
{
    #perfom copy
    foreach ($file in $copy_files + $unversioned_files) {
        $local_file_path = $local_src_path + $file
        $remote_file_path = $remote_path + $file

        write "Copy: $local_file_path"
        Copy-Item -Force $local_file_path $remote_file_path
    }

    foreach ($file in $delete_files) {
        $remote_file_path = $remote_path + $file

        write "Delete: $remote_file_path"
        Remove-Item $remote_file_path
    }
} else {
    write "Nothing to update"
}

$end_time = get-date
write "Done at: $end_time"