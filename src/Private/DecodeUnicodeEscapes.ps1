function DecodeUnicodeEscapes {
    param (
        [string]$InputString
    )

    $decoded = [regex]::Replace($InputString, '\\u([0-9a-fA-F]{4})', {
        param($match)
        [char]::ConvertFromUtf32([int]::Parse($match.Groups[1].Value, [System.Globalization.NumberStyles]::HexNumber))
    })

    return $decoded
}