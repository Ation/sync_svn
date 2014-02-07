Function CreateEmptySettings
{
    $settings = new-object PSObject
    $settings | Add-Member -NotePropertyName IgnoreFileExtension -NotePropertyValue (New-Object System.Collections.ArrayList)
    $settings | Add-Member -NotePropertyName IgnoreDirectory -NotePropertyValue (New-Object System.Collections.ArrayList)

    return $settings
}

Function LoadSettingsFromFile($fileName)
{
    $settings = CreateEmptySettings

    if ( ! (Test-Path $fileName) ) {
        return $settings
    }

    $content = [xml](get-content $fileName)
    if ($content.SyncSettings.IgnoreFileExtension.node -ne $null) {
        foreach ($fileNode in $content.SyncSettings.IgnoreFileExtension.node) {
            $count = $settings.IgnoreFileExtension.Add( $fileNode.GetAttribute("value") )
        }
    }

    if ($content.SyncSettings.IgnoreDirectory.node -ne $null) {
        foreach ($directoryNode in $content.SyncSettings.IgnoreDirectory.node) {
            $count = $settings.IgnoreDirectory.Add( $directoryNode.GetAttribute("value") )
        }
    }

    return $settings
}

Function WriteValuesToXML( $writer, $element, $values)
{
    $writer.WriteStartElement($element)
    foreach ( $value in $values)
    {
        $writer.WriteStartElement("node")
        $writer.WriteAttributeString("value", $value)
        $writer.WriteEndElement()
    }
    $writer.WriteEndElement()
}

Function SaveSettings($fileName, $settings)
{
    $xml_settings = new-object System.Xml.XmlWriterSettings

    $xml_settings.Indent = $True
    $xml_settings.IndentChars = "`t"

    $writer = [System.Xml.XmlWriter]::Create($fileName, $xml_settings)

    $writer.WriteStartDocument()

    $writer.WriteStartElement("SyncSettings")

    WriteValuesToXML $writer "IgnoreFileExtension" $settings.IgnoreFileExtension
    WriteValuesToXML $writer "IgnoreDirectory" $settings.IgnoreDirectory

    $writer.WriteEndElement() # SyncSettings

    $writer.WriteEndDocument()
    $writer.Flush()
    $writer.Close()
}