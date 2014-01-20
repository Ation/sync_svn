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

remove-item -recurse -force $test_root