#Requires -Version 7.0
# Regresjonstest for Set-DomenemodellCelle i Domenemodell.ps1. Bruker bare en syntetisk .docx som
# lages i temp-mappen. Ingen ekte dokumenter, SharePoint eller Word. Avslutter med kode 1 ved feil.
#
# Kjør: pwsh -File skills/lmr/scripts/Test-Domenemodell.ps1

. "$PSScriptRoot/Domenemodell.ps1"

$mappe = Join-Path ([IO.Path]::GetTempPath()) "domenemodell-test-$([guid]::NewGuid().ToString('N'))"
[void](New-Item -ItemType Directory $mappe)
$feil = 0; $antall = 0

function Assert-Lik($Faktisk, $Forventet, [string]$Navn) {
    $script:antall++
    if ($Faktisk -ceq $Forventet) { "OK    $Navn" }
    else { $script:feil++; "FEIL  $Navn`n      forventet: '$Forventet'`n      faktisk:   '$Faktisk'" }
}

# Én rad i testtabellen: Beskrivelse-cellen får innholdet i $Avsnitt.
function New-Rad([string]$Navn, [string]$Avsnitt) {
    $celle = { param($p) "<w:tc><w:p>$p</w:p></w:tc>" }
    "<w:tr>" + (& $celle "<w:r><w:t>$Navn</w:t></w:r>") + (& $celle '<w:r><w:t>tekst</w:t></w:r>') +
    (& $celle '<w:r><w:t>1</w:t></w:r>') + "<w:tc><w:p>$Avsnitt</w:p></w:tc></w:tr>"
}

$rader = [ordered]@{
    Ok           = '<w:r><w:t>gammel</w:t></w:r>'
    ToLop        = '<w:r><w:t>gam</w:t></w:r><w:r><w:t>mel</w:t></w:r>'
    Tom          = ''
    FlereT       = '<w:r><w:t>gammel</w:t><w:tab/><w:t>rest</w:t></w:r>'
    Tabulator    = '<w:r><w:t>gammel</w:t></w:r><w:r><w:tab/></w:r>'
    KomplektFelt = '<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText> PAGE </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>gammel</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>'
    EnkeltFelt   = '<w:fldSimple w:instr=" PAGE "><w:r><w:t>gammel</w:t></w:r></w:fldSimple>'
    SporetSletting = '<w:del w:id="1" w:author="a" w:date="2026-01-01T00:00:00Z"><w:r><w:delText>gammel</w:delText></w:r></w:del><w:r><w:t>annen</w:t></w:r>'
    Lenke        = '<w:hyperlink w:anchor="x"><w:r><w:t>gammel</w:t></w:r></w:hyperlink>'
    Bokmerke     = '<w:bookmarkStart w:id="2" w:name="b"/><w:r><w:t>gammel</w:t></w:r><w:bookmarkEnd w:id="2"/>'
}

$hode = (@('Navn', 'Type', 'K', 'Beskrivelse') | ForEach-Object { "<w:tc><w:p><w:r><w:t>$_</w:t></w:r></w:p></w:tc>" }) -join ''
$tabell = '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Test</w:t></w:r></w:p></w:tc></w:tr>' +
'<w:tr><w:tc><w:p><w:r><w:t>Beskrivelse</w:t></w:r></w:p></w:tc></w:tr>' +
'<w:tr>' + $hode + '</w:tr>' +
(($rader.GetEnumerator() | ForEach-Object { New-Rad $_.Key $_.Value }) -join '') + '</w:tbl><w:p/>'

$prolog = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + "`r`n"
$documentXml = $prolog + '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>' + $tabell + '</w:body></w:document>'

$mal = Join-Path $mappe 'mal.docx'
$zip = [IO.Compression.ZipFile]::Open($mal, 'Create')
try {
    $deler = [ordered]@{
        '[Content_Types].xml' = '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'
        '_rels/.rels'         = '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'
        'word/document.xml'   = $documentXml
    }
    foreach ($d in $deler.GetEnumerator()) {
        $strom = $zip.CreateEntry($d.Key).Open()
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($d.Value)
        $strom.Write($bytes, 0, $bytes.Length); $strom.Dispose()
    }
} finally { $zip.Dispose() }

try {
    # Gyldige celler endres, og ingenting av den gamle teksten blir igjen.
    foreach ($rad in 'Ok', 'ToLop', 'Tom') {
        $kopi = Join-Path $mappe "$rad.docx"; Copy-Item $mal $kopi
        Set-DomenemodellCelle -Sti $kopi -Tabell 'Test' -Rad $rad -Kolonne Beskrivelse -Verdi 'ny'
        $x = Read-DocumentXml $kopi
        $tbl = Find-DomenemodellTabell $x.Doc $x.Ns 'Test'
        $tc = @(Get-Celler (Find-DomenemodellRad $tbl $x.Ns $rad) $x.Ns)[3]
        Assert-Lik (Get-CelleTekst $tc $x.Ns) 'ny' "$rad - ny verdi"
        Assert-Lik $tc.SelectNodes('.//w:t', $x.Ns).Count 1 "$rad - nøyaktig én tekstnode"
    }

    # Celler utenfor hvitelisten avvises, og filen er uendret etterpå.
    foreach ($rad in 'FlereT', 'Tabulator', 'KomplektFelt', 'EnkeltFelt', 'SporetSletting', 'Lenke', 'Bokmerke') {
        $kopi = Join-Path $mappe "$rad.docx"; Copy-Item $mal $kopi
        $for = Get-Sha256 $kopi
        $kastet = $false
        try { Set-DomenemodellCelle -Sti $kopi -Tabell 'Test' -Rad $rad -Kolonne Beskrivelse -Verdi 'ny' } catch { $kastet = $true }
        Assert-Lik $kastet $true "$rad - avvist"
        Assert-Lik (Get-Sha256 $kopi) $for "$rad - filen er uendret"
    }
} finally {
    Remove-Item $mappe -Recurse -Force
}

"`n$($antall - $feil) av $antall bestått"
if ($feil -gt 0) { exit 1 }
