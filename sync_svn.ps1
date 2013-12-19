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
    $ignored_path = @('ThorServers')

    # TODO remove when ready to work with directories
    return $false

    return !($ignored_path.Contains($path))
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

Function WriteDirectoriesToXMLWriter ( $writer, $elementName, $directories)
{
    $writer.WriteStartElement($elementName)
    foreach ( $path in $directories)
    {
        $writer.WriteStartElement("directory")
        $writer.WriteAttributeString("path", $path)
        $writer.WriteEndElement()
    }
    $writer.WriteEndElement()
}

######################################### main #########################################

cd $local_src_path

# old_copied_files contains previously copied files list
$old_copied_files = new-object System.Collections.ArrayList
# old_deleted_files contains previously deleted files list
$old_deleted_files = new-object System.Collections.ArrayList
# old_unversioned_files contains list of unversioned files that were copied to the remote
$old_unversioned_files = new-object System.Collections.ArrayList

#old_copy_directories list of completely copied directories (because whole directory was unversioned)
$old_copy_directories = new-object System.Collections.ArrayList

$old_delete_directories = new-object System.Collections.ArrayList

$old_unversioned_directories = new-object System.Collections.ArrayList

######################################### read previous operations #########################################

if (Test-Path $report_file) {
    # NOTE: count is used just to hide output (probably it is dumb =) )
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

    if ( $content.Directories.ToCopy.directory -ne $null) {
        foreach ($directory_node in $content.Directories.ToCopy.directory) {
                $count = $old_copy_directories.Add($directory_node.GetAttribute("path") )
        }
    }

    if ( $content.Directories.ToDelete.directory -ne $null) {
        foreach ($directory_node in $content.Directories.ToDelete.directory) {
                $count = $old_delete_directories.Add($directory_node.GetAttribute("path") )
        }
    }

    if ( $content.Directories.Unversioned.directory -ne $null) {
        foreach ($directory_node in $content.Directories.Unversioned.directory) {
                $count = $old_unversioned_directories.Add($directory_node.GetAttribute("path") )
        }
    }
}

######################################### get status #########################################

$status = [xml](svn st --xml)

$copy_files = new-object System.Collections.ArrayList
$delete_files = new-object System.Collections.ArrayList
$unversioned_files = new-object System.Collections.ArrayList

$copy_directories = new-object System.Collections.ArrayList
$delete_directories = new-object System.Collections.ArrayList
$unversioned_directories = new-object System.Collections.ArrayList

#create new actions list
#NOTE: dummy is used just to hide output from elements adding
foreach ($entry in $status.status.target.entry)
{
    $file_path = $entry.path
    $node = $entry.SelectSingleNode("wc-status")
    $file_status = $node.GetAttribute("item")

    if ( IsDirectory( $file_path) ) {
        if ($file_status -eq "missing") {
            $dummy = $delete_directories.add($file_path)
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
                $dummy = $unversioned_directories.add( $file_path)
            } else {
                write "Ignoring directory $file_path"
            }
        }
    } else {
        if ($file_status -eq "missing") {
            # missed file is not reported if directory missed or deleted
            $dummy = $delete_files.Add($file_path)
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
                $dummy = $delete_files.Add( $file_path )
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
                $dummy = $copy_files.add( $file_path)
            }
        }
        elseif ($file_status -eq "modified") {
            # modified file is not reported if directory was removed or deleted
            $dummy = $copy_files.Add($file_path)
        }
        elseif ($file_status -eq "unversioned") {
            if ( CopyFileRequired( $file_path ) ) {
                    $dummy = $unversioned_files.Add($file_path)
            } else {
                write "Ignoring file $file_path"
            }
        }
    }
}

######################################### save current operations #########################################
# save current changes (merged changes will be restoring)
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

$writer.WriteStartElement("Directories")

WriteDirectoriesToXMLWriter $writer "ToCopy" $copy_directories
WriteDirectoriesToXMLWriter $writer "ToDelete" $copy_directories
WriteDirectoriesToXMLWriter $writer "Unversioned" $unversioned_directories

$writer.WriteEndElement() #Directories

$writer.WriteEndDocument()
$writer.Flush()
$writer.Close()

######################################### merge operations #########################################
# to determine if we need to do restore for something

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
            $local_file_path = GetLocalPath( $file)
            if (Test-Path $local_file_path) {
                $dummy = $copy_files.Add($file)
            } else {
                $dummy = $delete_files.Add($file)
            }
        }
    }
}

foreach ( $dir in $old_copy_directories ) {
    if ( ! ( $copy_directories.contains($dir) -or 
      $unversioned_directories.contains( $dir) -or 
      $delete_directories.contains($dir)) ) {
            $dummy = $copy_directories.add($dir)
    }
}

foreach ( $dir in $old_unversioned_directories ) {
    if ( ! ( $copy_directories.contains($dir) -or 
             $unversioned_directories.contains( $dir) -or 
             $delete_directories.contains($dir)) ) {
        $dummy = $delete_directories.add( $dir)
    }
}

foreach ( $dir in $old_delete_directories ) {
    if ( ! ( $copy_directories.contains($dir) -or 
             $unversioned_directories.contains( $dir) -or 
             $delete_directories.contains($dir)) {
        $local_path = GetLocalPath( $dir )

        if (test-path $local_path) {
            # directory restored
            $dummy = $copy_directories.add( $dir)
        } else {
            # nothing to do. it was deleted last time and now it is missing and not in the index
        }
    }
}

######################################### update remote repository #########################################

$haveWork = ( $copy_files.count -ne 0 ) -or ( $unversioned_files.count -ne 0 ) -or ( $delete_files.count -ne 0 )
  -or ( $copy_directories.count -ne 0 ) -or ( $delete_directories.count -ne 0) -or ( $unversioned_directories.count -ne 0)

if ($haveWork)
{
    #perfom copy

    # process directories first
    foreach ($directory in $copy_directories + $unversioned_directories) {
        $local_directory_path = GetLocalPath( $directory ) + "\*"
        $remote_directory_path = GetPathOnRemote( $directory )

        write "Copy directory: $local_directory_path"
        Copy-item $local_directory_path $remote_directory_path -recurse
    }

    foreach ( $dir in $delete_directories ) {
        $remote_directory_path = GetPathOnRemote( $dir )

        write "Remove directory: $remote_directory_path"
        Remove-Item $remote_directory_path -recurse
    }

    # now process files
    foreach ($file in $copy_files + $unversioned_files) {
        $local_file_path = GetLocalPath( $file)
        $remote_file_path = GetPathOnRemote($file)

        write "Copy file: $local_file_path"
        Copy-Item -Force $local_file_path $remote_file_path
    }

    foreach ($file in $delete_files) {
        $remote_file_path = GetPathOnRemote($file)

        write "Delete file: $remote_file_path"
        Remove-Item $remote_file_path
    }
} else {
    write "Nothing to update"
}

$end_time = get-date
write "Done at: $end_time"