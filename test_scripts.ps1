Function CompareFiles($file1, $file2) {
    if ($file1.Length -ne $file2.Length) {
        return $False
    }

    $f1_content = get-content $file1.FullName -raw
    $f2_content = get-content $file2.FullName -raw

    return ($f1_content.Equals($f2_content))
}

Function CompareDirectories($dir1, $dir2, $ignore_list) {
    $dir1_files = $dir1.GetFiles()
    $dir2_files = $dir2.GetFiles()

    $dir1_files_names = New-Object System.Collections.ArrayList
    foreach ($file_info in $dir1_files) {
        $dummy = $dir1_files_names.Add($file_info.Name)
    }

    $dir2_files_names = New-Object System.Collections.ArrayList
    foreach ($file_info in $dir2_files) {
        $dummy = $dir2_files_names.Add($file_info.Name)
    }

    if ($dir1_files.Count -ne $dir2_files.Count) {
        # Write -debug "Directories have different set of files"

        if (! ($dir1_files_names.Empty) ) {
            foreach ($file_name in $dir1_files_names) {
                if (! ($dir2_files_names.Contains($file_name)))  {
                    # write -debug "$dir2 do not contain $filename"
                }
            }
        }

        foreach ($file_name in $dir2_files_names) {
            if (! ($dir1_files_names.Contains($file_name))) {
                # write -debug "$dir1 do not contain $filename"
            }
        }

        return $False
    }

    for ($i = 0; $i -lt $dir1_files.Count; $i++) {
        if ( $dir1_files[$i].Name -ne $dir2_files[$i].Name) {
            $name1 = $dir1_files[$i].FullName
            $name2 = $dir2_files[$i].FullName

            # Write -debug "Directories have different set of files. $name1 instead of $name2"
            return $False
        }

        if (! (CompareFiles $dir1_files[$i] $dir2_files[$i]) ) {
            $name1 = $dir1_files[$i].FullName
            $name2 = $dir2_files[$i].FullName
            # write -debug "Files not equal: $name1 and $name2"
            return $False
        }
    }

    $dir1_directories = new-object System.Collections.ArrayList
    $dir2_directories = new-object System.Collections.ArrayList

    foreach ($dir_info in $dir1.GetDirectories()) {
        if (! ($ignore_list.Contains($dir_info.Name))) {
            $dummy = $dir1_directories.Add($dir_info)
        }
    }

    foreach ($dir_info in $dir2.GetDirectories()) {
        if (! ($ignore_list.Contains($dir_info.Name))) {
            $dummy = $dir2_directories.Add($dir_info)
        }
    }

    $dir1_dir_names = new-object System.Collections.ArrayList
    foreach ( $dir_info in $dir1_directories) {
        $dummy = $dir1_dir_names.Add($dir_info.Name)
    }

    $dir2_dir_names = new-object System.Collections.ArrayList
    foreach ( $dir_info in $dir2_directories) {
        $dummy = $dir2_dir_names.Add($dir_info.Name)
    }

    if ( $dir1_directories.Count -ne $dir2_directories.Count ) {
        foreach ($dir_name in $dir1_dir_names) {
            if (! ($dir2_dir_names.Contains($dir_name)) ) {
                # write -debug "$dir2 do not contain $dir_name"
            }
        }

        foreach ($dir_name in $dir2_dir_names) {
            if (! ($dir1_dir_names.Contains($dir_name)) ) {
                # write -debug "$dir1 do not contain $dir_name"
            }
        }

        return $False
    }

    for ($i = 0; $i -lt $dir2_directories.Count ; $i++) {
        if ($dir1_directories[$i].Name -ne $dir2_directories[$i].Name) {
            $d1 = $dir1_directories[$i].Name
            $d2 = $dir2_directories[$i].Name

            # write -debug "Different directories $d1 and $d2"

            return $False
        }

        if (! (CompareDirectories $dir1_directories[$i] $dir2_directories[$i] $ignore_list) ) {
            return $False
        }
    }

    return $True
}

$ignore_list = new-object System.Collections.ArrayList
$dummy = $ignore_list.Add(".svn")

$test_root = "$PSScriptRoot\test_root"
$report_file = join-path $test_root "test_report.xml"

$repo_root = "$test_root\repo"
$local_path = "$test_root\local"
$remote_path = "$test_root\remote"

if (test-path $test_root) {
    remove-item -recurse -force $test_root
}

$root_info = [System.IO.Directory]::CreateDirectory($test_root)

$repo_root_info = [System.IO.Directory]::CreateDirectory($repo_root)
$local_path_info = [System.IO.Directory]::CreateDirectory($local_path)
$remote_path_info = [System.IO.Directory]::CreateDirectory($remote_path)

cd $repo_root_info.FullName

svnadmin create .

$repo_link = "file:///$repo_root"

write $remote_path_info.FullName
cd $remote_path_info.FullName
svn co $repo_link . 

cd $local_path_info.FullName
svn co $repo_link .

# CompareDirectories $remote_path_info $local_path_info $ignore_list

$content1 = "asdasd"
$content2 = "xxxxzzzzzz"
$content3 = "33333333333333333"

# 1 create file
write "Testing for unversioned file"
write "# 1.1 Creating file"
$file_name1 = join-path $local_path_info.FullName "test_file1.cpp"
$file_name2 = join-path $local_path_info.FullName "test_file2.cpp"

set-content $file_name1 $content1

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.1. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.1. Second check"
    return
}

# 2 remove this file

write "# 1.2 Removing file"
remove-item $file_name1

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.2. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.2. Second check"
    return
}

# 3 restore file

write "# 1.3 Restoring file"
set-content $file_name1 $content1

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.3. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.3. Second check"
    return
}

# 4 add file

write "# 1.4 Adding to index"

set-content $file_name2 $content2
svn add $file_name1
svn add $file_name2

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.4. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.4. Second check"
    return
}

# 5 delete file
write "# 1.5 Removing added files"

remove-item $file_name1
remove-item $file_name2

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.5. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.5. Second check"
    return
}

# 6 restore file

write "# 1.6 Restore files and revert missing file"
set-content $file_name1 $content1
svn revert $file_name2

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.6. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.6. Second check"
    return
}

# 7 undo add 

write "# 1.7 Revert file"
svn revert $file_name1

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.7. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.7. Second check"
    return
}

write "# 1.8 Test for rename of unversioned file"

svn add $file_name1
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.7. First check"
    return
}

svn rename $file_name1 $file_name2
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.8. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 1.8. Second check"
    return
}

svn rename $file_name2 $file_name1
svn commit -m "First commit"

. "$PSScriptRoot\prepare_to_update.ps1" $report_file $remote_path_info.FullName
svn update $remote_path_info.FullName

write "Testing for versioned files"

write "# 2.1 Modify the file"

set-content $file_name1 $content2
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.1. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.1. Second check"
    return
}

write "# 2.2 Test for restore file"

svn revert $file_name1
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.2. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.2. Second check"
    return
}

write "# 2.3 Test for missing file"

remove-item $file_name1
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.3. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.3. Second check"
    return
}

write "# 2.4 Restore missing file"

svn revert $file_name1
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.4. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.4. Second check"
    return
}

write "# 2.5 Test for svn delete file"

svn rm $file_name1
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.5. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.5. Second check"
    return
}

write "# 2.6 test for revert removed file"

svn revert $file_name1
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.6. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.6. Second check"
    return
}

write "# 2.7 test for remove and replace file"

svn rm $file_name1
# with different content
set-content $file_name1 $content2
svn add $file_name1

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.7. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.7. Second check"
    return
}

write "# 2.8 test for revert step 2.7"

svn revert $file_name1

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.8. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.8. Second check"
    return
}

write "# 2.9 test for rename"

svn rename $file_name1 $file_name2

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.9. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.9. Second check"
    return
}

write "# 2.10 change conent of renamed file"

set-content $file_name2 $content2

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.10. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.10. Second check"
    return
}

write "# 2.11 test for missing renamed file"

remove-item $file_name2

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.11. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.11. Second check"
    return
}

write "# 2.12 test for revert"

svn revert $file_name1

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.12. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.12. Second check"
    return
}

svn revert $file_name2

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.12. Third check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.12. Fourth check"
    return
}

write "# 2.14 test for rename and replace file"

svn rename $file_name1 $file_name2
set-content $file_name1 $content2
svn add $file_name1

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.14. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.14. Second check"
    return
}

write "# 2.15 test delete renamed file"

svn rm $file_name2

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.15. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.15. Second check"
    return
}

write "# 2.16 test revert"

svn revert $file_name1
svn revert $file_name2

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.16. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 2.16. Second check"
    return
}

write "#### Start testing for unversioned folders"

$test_directory1 = new-object System.IO.DirectoryInfo (join-path $local_path_info.FullName "dir1")
$test_directory2 = new-object System.IO.DirectoryInfo (join-path $local_path_info.FullName "dir2")

$dir1_file1 = join-path $test_directory1.FullName "dir1_file1.cpp"
$dir1_file2 = join-path $test_directory1.FullName "dir1_file2.cpp"
$dir1_file3 = join-path $test_directory1.FullName "dir1_file3.cpp"

write "# 3.1 Create dir"

$test_directory1.Create()

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.1. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.1. Second check"
    return
}

write "# 3.2 remove unversioned dir"

$test_directory1.Delete($True)
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.2. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.2. Second check"
    return
}

write "# 3.3 create unversioned directory with files"

$test_directory1.Create()

set-content $dir1_file1 $content1
set-content $dir1_file2 $content2

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.3. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.3. Second check"
    return
}

write "# 3.4 remove one of the files"

remove-item $dir1_file1
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.4. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.4. Second check"
    return
}

write "# 3.5 remove directory"

$test_directory1.Delete($True)
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.5. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.5. Second check"
    return
}

write "# 3.6 Add directory and a file inside"

$test_directory1.Create()
set-content $dir1_file1 $content1
svn add $test_directory1.FullName

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) )  {
    write "Failed to sync at stage 3.6. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.6. Second check"
    return
}

write "# 3.7 Add unversioned file to added directory"

set-content $dir1_file2 $content2

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) )  {
    write "Failed to sync at stage 3.7. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.7. Second check"
    return
}

write "# 3.8 rename added file"

svn rename $dir1_file1 $dir1_file3

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) )  {
    write "Failed to sync at stage 3.8. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.8. Second check"
    return
}

write "# 3.9 replace added file"

set-content $dir1_file1 $content3
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) )  {
    write "Failed to sync at stage 3.9. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.9. Second check"
    return
}

write "# 3.10 remove added file"

remove-item $dir1_file3

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) )  {
    write "Failed to sync at stage 3.10. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.10. Second check"
    return
}

write "# 3.11 remove unversioned file"

remove-item $dir1_file2

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) )  {
    write "Failed to sync at stage 3.11. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.11. Second check"
    return
}

write "# 3.12 test for directory rename and replace"

set-content $dir1_file2 $content2
svn add $dir1_file2
svn rename $test_directory1.FullName $test_directory2.FullName

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) )  {
    write "Failed to sync at stage 3.12. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.12. Second check"
    return
}

$test_directory1.Create()
set-content $dir1_file1 $content2
set-content $dir1_file2 $content3
set-content $dir1_file3 $content1

svn add $test_directory1.FullName

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) )  {
    write "Failed to sync at stage 3.12. Third check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.12. Fourth check"
    return
}

write "# 3.13 test for remove one dir"

$test_directory2.Delete($True)
svn remove $test_directory2.FullName

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) )  {
    write "Failed to sync at stage 3.13. First check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 3.13. Second check"
    return
}

svn commit -m "Second commit"
. "$PSScriptRoot\prepare_to_update.ps1" $report_file $remote_path_info.FullName
svn update $remote_path_info.FullName

write "Testing for changes in versioned directory"

$dir1_file4 = join-path $test_directory1.FullName "dir1_file4.cpp"

write "Directory in directory test"

$master_directory = new-object System.IO.DirectoryInfo (join-path $local_path_info.FullName "masterdir")
$added_sub_directory = new-object System.IO.DirectoryInfo (join-path $master_directory.FullName "added_subdir")
$sub_directory = new-object System.IO.DirectoryInfo (join-path $master_directory.FullName "subdir")

$master_file1 = join-path $master_directory.FullName "mf1.cpp"
$master_file2 = join-path $master_directory.FullName "mf2.cpp"
$master_file3 = join-path $master_directory.FullName "mf3.cpp"

$sub_file1 = join-path $sub_directory.FullName "sf1.cpp"
$sub_file2 = join-path $sub_directory.FullName "sf2.cpp"
$sub_file3 = join-path $sub_directory.FullName "sf3.cpp"

$added_sub_file1 = join-path $added_sub_directory.FullName "asf1.cpp"
$added_sub_file2 = join-path $added_sub_directory.FullName "asf2.cpp"
$added_sub_file3 = join-path $added_sub_directory.FullName "asf3.cppa"

# create directory and subdir. add them, then create another

$master_directory.Create()
$added_sub_directory.Create()

set-content $master_file1 $content1
set-content $master_file2 $content2

set-content $added_sub_file1 $content1
set-content $added_sub_file2 $content2

svn add $master_directory.FullName

write "# 4.1 Adding dir and subdir"

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) )  {
    write "Failed to sync at stage 4.1. Third check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 4.1. Fourth check"
    return
}

write "# 4.2 add unverioned directory"

$sub_directory.Create()

set-content $sub_file1 $content1
set-content $sub_file2 $content2

. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) )  {
    write "Failed to sync at stage 4.2. Third check"
    return
}

# want to check second time, cause report now exists
. "$PSScriptRoot\sync_svn.ps1" $report_file $local_path_info.FullName $remote_path_info.FullName
if ( ! ( CompareDirectories $local_path_info $remote_path_info $ignore_list) ) {
    write "Failed to sync at stage 4.2. Fourth check"
    return
}

write "OK"

# remove-item -recurse -force $test_root