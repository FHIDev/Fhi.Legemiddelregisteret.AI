#Requires -Version 7.0
# Funksjoner for å hente, lese, endre og laste opp domenemodell-dokumenter (.docx) på SharePoint
# uten å ødelegge dem. Prosedyren og reglene står i references/DOMENEMODELL-LESE-SKRIVE.md.
#
# Bruk: dot-source filen i hver PowerShell-økt (variabler overlever ikke mellom kall):
#   . "<skill-katalog>/scripts/Domenemodell.ps1"
# All tilstand mellom stegene (item-ID, eTag, hasher) ligger i tilstand.json i arbeidsmappen,
# og token hentes på nytt fra az CLI i hvert kall.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$script:WNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
$script:W14Ns = 'http://schemas.microsoft.com/office/word/2010/wordml'
$script:DocxType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'

# ---------------------------------------------------------------- Graph og tilstand

function Get-DomenemodellToken {
    $token = az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or -not $token) { throw 'Fikk ikke Graph-token fra az CLI. Kjør az login.' }
    return $token
}

function Read-DomenemodellTilstand([string]$Arbeidsmappe) {
    $fil = Join-Path $Arbeidsmappe 'tilstand.json'
    if (-not (Test-Path $fil)) { throw "Fant ikke $fil. Kjør Get-Domenemodell først." }
    return Get-Content $fil -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
}

function Write-DomenemodellTilstand([string]$Arbeidsmappe, [hashtable]$Tilstand) {
    $Tilstand | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Arbeidsmappe 'tilstand.json') -Encoding utf8
}

function Get-Sha256([string]$Sti) { (Get-FileHash $Sti -Algorithm SHA256).Hash }

# v1.0 /content svarer med 302 til SharePoints download.aspx, som avviser Azure CLI-tokenet
# ("App is not allowed to call SPO with user_impersonation scope"). beta /contentStream
# leverer innholdet direkte fra Graph og virker med samme token.
function Save-DomenemodellInnhold([string]$DriveId, [string]$ItemId, [string]$Til) {
    $h = @{ Authorization = "Bearer $(Get-DomenemodellToken)" }
    Invoke-WebRequest -Headers $h -Uri "https://graph.microsoft.com/beta/drives/$DriveId/items/$ItemId/contentStream" -OutFile $Til | Out-Null
}

function Get-Domenemodell {
    # Laster ned dokumentet til <Arbeidsmappe>/original.docx (skrivebeskyttet backup) og
    # endret.docx (arbeidskopi), og lagrer item-ID, eTag og lastModifiedDateTime i tilstand.json.
    param(
        [Parameter(Mandatory)][string]$Filnavn,
        [Parameter(Mandatory)][string]$Arbeidsmappe,
        [string]$Site = 'folkehelse.sharepoint.com:/sites/1221',
        [string]$Mappe = '7 - Gjennomføringsfase/02 - Løsningsbeskrivelse/Domenemodell'
    )
    if (Test-Path (Join-Path $Arbeidsmappe 'original.docx')) {
        throw "$Arbeidsmappe har allerede en nedlasting. Bruk en ny arbeidsmappe."
    }
    New-Item -ItemType Directory -Force $Arbeidsmappe | Out-Null
    $h = @{ Authorization = "Bearer $(Get-DomenemodellToken)" }

    $drive = Invoke-RestMethod -Headers $h -Uri "https://graph.microsoft.com/v1.0/sites/$($Site):/drive?`$select=id"
    # Hvert segment URL-enkodes for seg (mellomrom, æ/ø/å), skråstrekene beholdes.
    $sti = (("$Mappe/$Filnavn").Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    # Metadata hentes før innholdet. Endres filen mellom de to kallene, er eTag-en eldre enn
    # innholdet, og opplastingen stoppes av If-Match. Motsatt rekkefølge kunne overskrevet endringer.
    $item = Invoke-RestMethod -Headers $h -Uri "https://graph.microsoft.com/v1.0/drives/$($drive.id)/root:/$($sti)?`$select=id,name,eTag,lastModifiedDateTime"

    $original = Join-Path $Arbeidsmappe 'original.docx'
    Save-DomenemodellInnhold $drive.id $item.id $original
    Copy-Item $original (Join-Path $Arbeidsmappe 'endret.docx')
    Set-ItemProperty $original -Name IsReadOnly -Value $true

    $tilstand = @{
        Filnavn              = $item.name
        DriveId              = $drive.id
        ItemId               = $item.id
        ETag                 = $item.eTag
        LastModifiedDateTime = $item.lastModifiedDateTime
        OriginalSha256       = Get-Sha256 $original
    }
    Write-DomenemodellTilstand $Arbeidsmappe $tilstand
    return [pscustomobject]$tilstand
}

# ---------------------------------------------------------------- document.xml

# Leser word/document.xml og kontrollerer at en rundtur gjennom XmlDocument gir nøyaktig samme
# tekst. Bare da er det trygt å skrive tilbake: endringene blir de eneste forskjellene.
function Read-DocumentXml([string]$Sti) {
    $zip = [IO.Compression.ZipFile]::OpenRead($Sti)
    try {
        $leser = [IO.StreamReader]::new($zip.GetEntry('word/document.xml').Open(), [Text.UTF8Encoding]::new($false))
        $tekst = $leser.ReadToEnd(); $leser.Dispose()
    } finally { $zip.Dispose() }

    $doc = [Xml.XmlDocument]::new()
    $doc.PreserveWhitespace = $true
    $doc.LoadXml($tekst)
    $prolog = $tekst.Substring(0, $tekst.IndexOf('<w:document'))
    if (-not [string]::Equals((ConvertTo-DocumentXmlTekst $doc $prolog), $tekst, [StringComparison]::Ordinal)) {
        throw 'document.xml kan ikke skrives tilbake uten utilsiktede endringer. Ikke endre dokumentet; list avvikene i stedet.'
    }
    $ns = [Xml.XmlNamespaceManager]::new($doc.NameTable)
    $ns.AddNamespace('w', $script:WNs)
    return @{ Doc = $doc; Ns = $ns; Prolog = $prolog }
}

# XmlWriter skriver encoding="utf-8" og "<a />". Word skriver "UTF-8" og "<a/>", så prologen
# tas fra originalen og mellomrommet fjernes. Prefikser og xmlns-deklarasjoner beholdes uendret.
function ConvertTo-DocumentXmlTekst([Xml.XmlDocument]$Doc, [string]$Prolog) {
    $innst = [Xml.XmlWriterSettings]::new()
    $innst.OmitXmlDeclaration = $true
    $innst.Encoding = [Text.UTF8Encoding]::new($false)
    $ms = [IO.MemoryStream]::new()
    $skriver = [Xml.XmlWriter]::Create($ms, $innst)
    $Doc.DocumentElement.WriteTo($skriver); $skriver.Dispose()
    return $Prolog + [Text.Encoding]::UTF8.GetString($ms.ToArray()).Replace(' />', '/>')
}

# Erstatter bare innholdet i word/document.xml. Øvrige deler, også [trash]/*.dat, og
# rekkefølgen i pakken beholdes.
function Write-DocumentXml([string]$Sti, [string]$Tekst) {
    $zip = [IO.Compression.ZipFile]::Open($Sti, [IO.Compression.ZipArchiveMode]::Update)
    try {
        $strom = $zip.GetEntry('word/document.xml').Open()
        $strom.SetLength(0)
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Tekst)
        $strom.Write($bytes, 0, $bytes.Length); $strom.Dispose()
    } finally { $zip.Dispose() }
}

function Edit-DocumentXml([string]$Sti, [scriptblock]$Endring) {
    $x = Read-DocumentXml $Sti
    & $Endring $x.Doc $x.Ns
    Write-DocumentXml $Sti (ConvertTo-DocumentXmlTekst $x.Doc $x.Prolog)
}

# ---------------------------------------------------------------- tabeller

function Get-NaermesteCelle($Node, $Ns) { $Node.SelectSingleNode('ancestor::w:tc[1]', $Ns) }

# Avsnittene som hører til cellen selv, ikke til en tabell inne i cellen.
function Get-CelleAvsnitt($Tc, $Ns) {
    @($Tc.SelectNodes('.//w:p', $Ns) | Where-Object { [object]::ReferenceEquals((Get-NaermesteCelle $_ $Ns), $Tc) })
}

function Get-CelleTekst($Tc, $Ns) {
    $avsnitt = @(Get-CelleAvsnitt $Tc $Ns) | ForEach-Object { ($_.SelectNodes('.//w:t', $Ns) | ForEach-Object InnerText) -join '' }
    return ($avsnitt -join "`n").Trim()
}

function Get-Rader($Tbl, $Ns) { @($Tbl.SelectNodes('./w:tr', $Ns)) }
function Get-Celler($Tr, $Ns) { @($Tr.SelectNodes('./w:tc', $Ns)) }

# Standardformatet: rad 1 tabellnavn, rad 2 beskrivelse, rad 3 Navn | Type | K | Beskrivelse.
# Dokumentene bruker både Navn/Feltnavn og K/Kardinalitet i overskriftsraden.
function Get-KolonneIndekser($Tbl, $Ns) {
    $rader = @(Get-Rader $Tbl $Ns)
    if ($rader.Count -lt 3) { return $null }
    $hode = @(Get-Celler $rader[2] $Ns | ForEach-Object { Get-CelleTekst $_ $Ns })
    if ($hode.Count -ne 4 -or $hode[0] -notin 'Navn', 'Feltnavn' -or $hode[1] -ne 'Type' -or
        $hode[2] -notin 'K', 'Kardinalitet' -or $hode[3] -ne 'Beskrivelse') { return $null }
    return @{ Navn = 0; Type = 1; K = 2; Beskrivelse = 3 }
}

function Find-DomenemodellTabell($Doc, $Ns, [string]$Tabell) {
    $treff = @($Doc.SelectNodes('//w:tbl[not(ancestor::w:tbl)]', $Ns) | Where-Object {
            $forste = $_.SelectSingleNode('./w:tr[1]/w:tc[1]', $Ns)
            $forste -and (Get-CelleTekst $forste $Ns) -eq $Tabell.Trim()
        })
    if ($treff.Count -ne 1) { throw "Fant $($treff.Count) tabeller med navnet '$Tabell', forventet 1." }
    if (-not (Get-KolonneIndekser $treff[0] $Ns)) { throw "Tabellen '$Tabell' har ikke standardformatet (Navn | Type | K | Beskrivelse)." }
    return $treff[0]
}

function Find-DomenemodellRad($Tbl, $Ns, [string]$Rad) {
    $rader = @(Get-Rader $Tbl $Ns)
    $treff = @($rader | Select-Object -Skip 3 | Where-Object { (Get-CelleTekst @(Get-Celler $_ $Ns)[0] $Ns) -eq $Rad.Trim() })
    if ($treff.Count -ne 1) { throw "Fant $($treff.Count) rader med navnet '$Rad', forventet 1." }
    return $treff[0]
}

# Sann hvis raden etter $Tr fortsetter en vertikal fletting, slik at $Tr ikke kan fjernes eller få en ny rad etter seg.
function Test-HarVMergeFortsettelse($Tr, $Ns) {
    $neste = $Tr.SelectSingleNode('following-sibling::w:tr[1]', $Ns)
    return [bool]($neste -and $neste.SelectSingleNode("./w:tc/w:tcPr/w:vMerge[not(@w:val) or @w:val='continue']", $Ns))
}

function Get-DomenemodellTabeller {
    # Returnerer alle tabeller på øverste nivå. Standardtabeller får Kolonner med Navn, Type,
    # Kardinalitet og Beskrivelse. Andre tabeller (enum-verdier, forside, versjonslogg) får bare Rader.
    param([Parameter(Mandatory)][string]$Sti)
    $x = Read-DocumentXml $Sti
    $doc = $x.Doc; $ns = $x.Ns
    foreach ($tbl in $doc.SelectNodes('//w:tbl[not(ancestor::w:tbl)]', $ns)) {
        $rader = @(Get-Rader $tbl $ns)
        $tekst = @($rader | ForEach-Object { , @(Get-Celler $_ $ns | ForEach-Object { Get-CelleTekst $_ $ns }) })
        $overskrift = $tbl.SelectSingleNode("preceding-sibling::w:p[w:pPr/w:pStyle[starts-with(@w:val,'Heading') or starts-with(@w:val,'Overskrift')]][1]", $ns)
        $resultat = [ordered]@{
            Seksjon        = if ($overskrift) { ($overskrift.SelectNodes('.//w:t', $ns) | ForEach-Object InnerText) -join '' } else { '' }
            Tabell         = $tekst[0][0]
            Standardformat = [bool](Get-KolonneIndekser $tbl $ns)
        }
        if ($resultat.Standardformat) {
            $resultat.Beskrivelse = $tekst[1][0]
            # Tekst fra tabeller inne i en celle (f.eks. gyldige verdier) er ikke med i Beskrivelse.
            $resultat.Kolonner = @($rader | Select-Object -Skip 3 | ForEach-Object {
                    $c = @(Get-Celler $_ $ns)
                    [ordered]@{
                        Navn            = Get-CelleTekst $c[0] $ns
                        Type            = Get-CelleTekst $c[1] $ns
                        Kardinalitet    = Get-CelleTekst $c[2] $ns
                        Beskrivelse     = if ($c.Count -gt 3) { Get-CelleTekst $c[3] $ns } else { '' }
                        HarUndertabell  = [bool]$_.SelectSingleNode('.//w:tbl', $ns)
                        FlettetVertikalt = [bool]$_.SelectSingleNode('./w:tc/w:tcPr/w:vMerge', $ns)
                    }
                })
        } else {
            $resultat.Rader = $tekst
        }
        [pscustomobject]$resultat
    }
}

# Setter teksten i ett avsnitt og beholder formateringen fra første tekstløp (eller avsnittsmerket).
# Hviteliste: avsnittet må bare ha w:pPr og w:r, og hvert w:r bare w:rPr og nøyaktig én w:t. Alt annet
# (tabulator, linjeskift, felt, lenker, sporede endringer, bokmerker m.m.) kan holde tekst eller
# struktur som ellers blir liggende igjen ved siden av den nye verdien.
function Set-AvsnittTekst($P, $Ns, [string]$Verdi) {
    $ukjent = $P.SelectSingleNode('./*[not(self::w:pPr or self::w:r)] | ./w:r/*[not(self::w:rPr or self::w:t)]', $Ns)
    $lop = @($P.SelectNodes('./w:r', $Ns))
    if ($ukjent -or @($lop | Where-Object { $_.SelectNodes('./w:t', $Ns).Count -ne 1 }).Count -gt 0) {
        throw 'Avsnittet har innhold utenom vanlige tekstløp med én tekstnode (f.eks. tabulator, felt, lenker eller sporede endringer). Endre det manuelt i Word, eller list avviket.'
    }
    if ($lop.Count -eq 0) {
        $r = $P.OwnerDocument.CreateElement('w', 'r', $script:WNs)
        $rPr = $P.SelectSingleNode('./w:pPr/w:rPr', $Ns)
        if ($rPr) { [void]$r.AppendChild($rPr.CloneNode($true)) }
        [void]$r.AppendChild($P.OwnerDocument.CreateElement('w', 't', $script:WNs))
        [void]$P.AppendChild($r)
        $lop = @($r)
    }
    $t = $lop[0].SelectSingleNode('./w:t', $Ns)
    $t.InnerText = $Verdi
    [void]$t.SetAttribute('space', 'http://www.w3.org/XML/1998/namespace', 'preserve')
    for ($i = 1; $i -lt $lop.Count; $i++) { [void]$P.RemoveChild($lop[$i]) }
}

function Set-CelleTekst($Tc, $Ns, [string]$Verdi) {
    if ($Tc.SelectSingleNode('.//w:tbl', $Ns)) { throw 'Cellen inneholder en tabell. Endre den manuelt i Word, eller list avviket.' }
    if ($Tc.SelectSingleNode("./w:tcPr/w:vMerge[not(@w:val) or @w:val='continue']", $Ns)) { throw 'Cellen er flettet med cellen over, og teksten ville ikke vises. List avviket.' }
    $avsnitt = @(Get-CelleAvsnitt $Tc $Ns)
    $medTekst = @($avsnitt | Where-Object { $_.SelectSingleNode('.//w:t', $Ns) })
    if ($medTekst.Count -gt 1) { throw 'Cellen har tekst i flere avsnitt. Endre den manuelt i Word, eller list avviket.' }
    $maal = if ($medTekst.Count -eq 1) { $medTekst[0] } else { $avsnitt[0] }
    Set-AvsnittTekst $maal $Ns $Verdi
}

# En kopi av en rad eller tabell må ikke ha ID-er som allerede finnes i dokumentet.
function Clear-KopiMarkorer($Node, $Ns) {
    foreach ($e in @($Node.SelectNodes('descendant-or-self::*', $Ns))) {
        $e.RemoveAttribute('paraId', $script:W14Ns)
        $e.RemoveAttribute('textId', $script:W14Ns)
    }
    foreach ($e in @($Node.SelectNodes('.//w:bookmarkStart | .//w:bookmarkEnd | .//w:commentRangeStart | .//w:commentRangeEnd | .//w:r[w:commentReference]', $Ns))) {
        [void]$e.ParentNode.RemoveChild($e)
    }
}

# Lager en ny rad med samme formatering som malraden, uten vertikal fletting og undertabeller.
function New-RadFraMal($Mal, $Ns, [string[]]$Verdier) {
    $celler = @(Get-Celler $Mal $Ns)
    if ($celler.Count -ne 4) { throw 'Malraden har ikke fire celler. Velg en annen rad med -EtterRad.' }
    $ny = $Mal.CloneNode($true)
    Clear-KopiMarkorer $ny $Ns
    $i = 0
    foreach ($tc in @(Get-Celler $ny $Ns)) {
        $vMerge = $tc.SelectSingleNode('./w:tcPr/w:vMerge', $Ns)
        if ($vMerge) { [void]$vMerge.ParentNode.RemoveChild($vMerge) }
        $forsteLop = $tc.SelectSingleNode('.//w:r[w:t]/w:rPr', $Ns)
        $p = $tc.SelectSingleNode('./w:p', $Ns)
        if (-not $p) { $p = $tc.OwnerDocument.CreateElement('w', 'p', $script:WNs) } else { $p = $p.CloneNode($true) }
        foreach ($barn in @($tc.ChildNodes)) { if ($barn.LocalName -ne 'tcPr') { [void]$tc.RemoveChild($barn) } }
        foreach ($barn in @($p.ChildNodes)) { if ($barn.LocalName -ne 'pPr') { [void]$p.RemoveChild($barn) } }
        [void]$tc.AppendChild($p)
        if ($Verdier[$i]) {
            $r = $tc.OwnerDocument.CreateElement('w', 'r', $script:WNs)
            if ($forsteLop) { [void]$r.AppendChild($forsteLop.CloneNode($true)) }
            $t = $tc.OwnerDocument.CreateElement('w', 't', $script:WNs)
            $t.InnerText = $Verdier[$i]
            [void]$t.SetAttribute('space', 'http://www.w3.org/XML/1998/namespace', 'preserve')
            [void]$r.AppendChild($t)
            [void]$p.AppendChild($r)
        }
        $i++
    }
    return $ny
}

function Set-DomenemodellCelle {
    # Endrer én celle i en kolonnerad: -Kolonne er Navn, Type, K eller Beskrivelse.
    param(
        [Parameter(Mandatory)][string]$Sti,
        [Parameter(Mandatory)][string]$Tabell,
        [Parameter(Mandatory)][string]$Rad,
        [Parameter(Mandatory)][ValidateSet('Navn', 'Type', 'K', 'Beskrivelse')][string]$Kolonne,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Verdi
    )
    Edit-DocumentXml $Sti {
        param($doc, $ns)
        $tbl = Find-DomenemodellTabell $doc $ns $Tabell
        $tr = Find-DomenemodellRad $tbl $ns $Rad
        $tc = @(Get-Celler $tr $ns)[(Get-KolonneIndekser $tbl $ns)[$Kolonne]]
        Set-CelleTekst $tc $ns $Verdi
    }
}

function Add-DomenemodellRad {
    # Legger til en kolonnerad etter -EtterRad (standard: siste rad), formatert som den raden.
    param(
        [Parameter(Mandatory)][string]$Sti,
        [Parameter(Mandatory)][string]$Tabell,
        [string]$EtterRad,
        [Parameter(Mandatory)][string]$Navn,
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][string]$K,
        [AllowEmptyString()][string]$Beskrivelse = ''
    )
    Edit-DocumentXml $Sti {
        param($doc, $ns)
        $tbl = Find-DomenemodellTabell $doc $ns $Tabell
        $mal = if ($EtterRad) { Find-DomenemodellRad $tbl $ns $EtterRad } else { @(Get-Rader $tbl $ns)[-1] }
        if (@(Get-Rader $tbl $ns).Count -lt 4) { throw "Tabellen '$Tabell' har ingen kolonnerad å bruke som mal." }
        if (Test-HarVMergeFortsettelse $mal $ns) { throw 'Raden etter -EtterRad er vertikalt flettet med den. Velg en annen rad.' }
        $ny = New-RadFraMal $mal $ns @($Navn, $Type, $K, $Beskrivelse)
        [void]$tbl.InsertAfter($ny, $mal)
    }
}

function Remove-DomenemodellRad {
    param(
        [Parameter(Mandatory)][string]$Sti,
        [Parameter(Mandatory)][string]$Tabell,
        [Parameter(Mandatory)][string]$Rad
    )
    Edit-DocumentXml $Sti {
        param($doc, $ns)
        $tbl = Find-DomenemodellTabell $doc $ns $Tabell
        $tr = Find-DomenemodellRad $tbl $ns $Rad
        if (Test-HarVMergeFortsettelse $tr $ns) { throw "Raden '$Rad' er vertikalt flettet med neste rad. Endre den manuelt i Word, eller list avviket." }
        [void]$tbl.RemoveChild($tr)
    }
}

function Add-DomenemodellTabell {
    # Legger til en ny tabell etter -EtterTabell, formatert som den tabellen. Tabellene har ikke egne
    # overskrifter; de skilles med et tomt avsnitt, ellers slår Word sammen to tabeller som står inntil hverandre.
    # -Kolonner: @(@{ Navn = 'Id'; Type = 'heltall'; K = '1'; Beskrivelse = '' }, ...)
    param(
        [Parameter(Mandatory)][string]$Sti,
        [Parameter(Mandatory)][string]$EtterTabell,
        [Parameter(Mandatory)][string]$Navn,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Beskrivelse,
        [Parameter(Mandatory)][hashtable[]]$Kolonner
    )
    Edit-DocumentXml $Sti {
        param($doc, $ns)
        $mal = Find-DomenemodellTabell $doc $ns $EtterTabell
        if (@(Get-Rader $mal $ns).Count -lt 4) { throw "Tabellen '$EtterTabell' har ingen kolonnerad å bruke som mal." }

        $ny = $mal.CloneNode($true)
        Clear-KopiMarkorer $ny $ns
        $rader = @(Get-Rader $ny $ns)
        Set-CelleTekst @(Get-Celler $rader[0] $ns)[0] $ns $Navn
        Set-CelleTekst @(Get-Celler $rader[1] $ns)[0] $ns $Beskrivelse
        $radmal = $rader[3]
        foreach ($k in $Kolonner) {
            [void]$ny.InsertBefore((New-RadFraMal $radmal $ns @($k.Navn, $k.Type, $k.K, $k.Beskrivelse)), $radmal)
        }
        foreach ($r in @($rader | Select-Object -Skip 3)) { [void]$ny.RemoveChild($r) }

        $skille = $doc.CreateElement('w', 'p', $script:WNs)
        [void]$mal.ParentNode.InsertAfter($ny, $mal)
        [void]$mal.ParentNode.InsertAfter($skille, $mal)
    }
}

# ---------------------------------------------------------------- verifisering og opplasting

function Get-WordTall($Word, [string]$Sti) {
    # Open(FileName, ConfirmConversions, ReadOnly, AddToRecentFiles)
    $d = $Word.Documents.Open($Sti, $false, $true, $false)
    try {
        return [ordered]@{ Avsnitt = $d.Paragraphs.Count; Tabeller = $d.Tables.Count; Sider = $d.ComputeStatistics(2) }
    } finally {
        $d.Close(0)
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($d)
    }
}

function Test-DomenemodellIWord {
    # Åpner original.docx og endret.docx skrivebeskyttet i Word og sammenligner avsnitt, tabeller og
    # sider. Kaster unntak hvis Word ikke kan åpne filen. Velformet XML er ikke bevis på at den åpner.
    param([Parameter(Mandatory)][string]$Arbeidsmappe)
    $tilstand = Read-DomenemodellTilstand $Arbeidsmappe
    $endret = (Resolve-Path (Join-Path $Arbeidsmappe 'endret.docx')).Path
    $original = (Resolve-Path (Join-Path $Arbeidsmappe 'original.docx')).Path

    try { $word = New-Object -ComObject Word.Application }
    catch { throw "Word er ikke tilgjengelig ($($_.Exception.Message)). Ikke last opp; rapporter at verifiseringen ikke kunne gjøres." }
    $fantesFra = $word.Documents.Count
    try {
        $word.Visible = $false
        $word.DisplayAlerts = 0
        $for = Get-WordTall $word $original
        try { $etter = Get-WordTall $word $endret }
        catch { throw "Word kunne ikke åpne endret.docx: $($_.Exception.Message). Ikke last opp." }
    } finally {
        # Avslutt bare en Word-instans dette kallet startet, ikke en brukeren har dokumenter åpne i.
        if ($fantesFra -eq 0 -and $word.Documents.Count -eq 0) { $word.Quit(0) }
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)
    }

    if ($etter.Tabeller -lt $for.Tabeller) { throw "endret.docx har færre tabeller ($($etter.Tabeller)) enn originalen ($($for.Tabeller)). Ikke last opp." }
    $tilstand.WordOriginal = $for
    $tilstand.WordEndret = $etter
    $tilstand.VerifisertSha256 = Get-Sha256 $endret
    Write-DomenemodellTilstand $Arbeidsmappe $tilstand
    return [pscustomobject]@{ Original = [pscustomobject]$for; Endret = [pscustomobject]$etter }
}

function Get-DocumentXmlSha256([string]$Sti) {
    $zip = [IO.Compression.ZipFile]::OpenRead($Sti)
    try {
        $s = $zip.GetEntry('word/document.xml').Open()
        try { return [BitConverter]::ToString([Security.Cryptography.SHA256]::HashData($s)) } finally { $s.Dispose() }
    } finally { $zip.Dispose() }
}

function Publish-Domenemodell {
    # Laster opp endret.docx til samme item med If-Match på eTag fra nedlastingen, og leser tilbake.
    param([Parameter(Mandatory)][string]$Arbeidsmappe)
    $tilstand = Read-DomenemodellTilstand $Arbeidsmappe
    $endret = Join-Path $Arbeidsmappe 'endret.docx'
    $hash = Get-Sha256 $endret
    if ($hash -eq $tilstand.OriginalSha256) { throw 'endret.docx er lik originalen. Ingenting å laste opp.' }
    if ($hash -ne $tilstand.VerifisertSha256) { throw 'endret.docx er ikke verifisert i Word etter siste endring. Kjør Test-DomenemodellIWord.' }

    # Virker ikke mot SharePoint per 2026-10-09: az-tokenet (appen Microsoft Azure CLI) mangler Files.*/Sites.*-scopes.
    # Agenter skal ikke kjøre denne; se DOMENEMODELL-LESE-SKRIVE.md. Opplasting, If-Match/412 og tilbakelesing er ikke testet.
    $token = Get-DomenemodellToken
    # Graph-dokumentasjonen for PUT .../content nevner ikke If-Match, så det er ikke sikkert at 412 kommer.
    # Derfor sammenlignes eTag også rett før opplasting. If-Match beholdes for å dekke tiden mellom kallene.
    $naa = Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } `
        -Uri "https://graph.microsoft.com/v1.0/drives/$($tilstand.DriveId)/items/$($tilstand.ItemId)?`$select=id,eTag"
    if ($naa.eTag -ne $tilstand.ETag) {
        throw 'Dokumentet er endret av andre siden det ble hentet (eTag er endret). Ikke lastet opp. Rapporter det, og ikke prøv igjen uten ny nedlasting og ny sammenligning.'
    }

    $h = @{ Authorization = "Bearer $token"; 'If-Match' = $tilstand.ETag }
    $svar = Invoke-WebRequest -Method Put -Headers $h -ContentType $script:DocxType -InFile $endret -SkipHttpErrorCheck `
        -Uri "https://graph.microsoft.com/v1.0/drives/$($tilstand.DriveId)/items/$($tilstand.ItemId)/content"
    switch ($svar.StatusCode) {
        { $_ -in 200, 201 } { break }
        412 { throw 'HTTP 412: dokumentet er endret av andre siden det ble hentet. Ikke lastet opp. Rapporter det, og ikke prøv igjen uten ny nedlasting og ny sammenligning.' }
        423 { throw 'HTTP 423: dokumentet er låst (åpent for redigering eller sjekket ut). Ikke lastet opp. Rapporter det.' }
        default { throw "Opplasting feilet med HTTP $($svar.StatusCode): $($svar.Content)" }
    }
    $lastet = $svar.Content | ConvertFrom-Json
    if ($lastet.id -ne $tilstand.ItemId) { throw "Opplastingen ga item-ID $($lastet.id), forventet $($tilstand.ItemId)." }

    # HTTP 200 er ikke bevis på at riktig innhold er lagret: last ned på nytt og sammenlign.
    $tilbake = Join-Path $Arbeidsmappe 'tilbakelest.docx'
    Save-DomenemodellInnhold $tilstand.DriveId $tilstand.ItemId $tilbake
    if ((Get-Sha256 $tilbake) -ne $hash) {
        # SharePoint kan skrive biblioteksmetadata inn i docProps/customXml ved opplasting.
        $likDokument = (Get-DocumentXmlSha256 $tilbake) -eq (Get-DocumentXmlSha256 $endret)
        throw "Tilbakelest fil har annen hash enn endret.docx. word/document.xml er $(if ($likDokument) { 'lik' } else { 'ULIK' }). Rapporter det."
    }
    $tilstand.ETag = $lastet.eTag
    $tilstand.LastModifiedDateTime = $lastet.lastModifiedDateTime
    $tilstand.OpplastetSha256 = $hash
    Write-DomenemodellTilstand $Arbeidsmappe $tilstand
    return [pscustomobject]@{ ItemId = $lastet.id; ETag = $lastet.eTag; Sha256 = $hash }
}
