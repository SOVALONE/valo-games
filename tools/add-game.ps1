# Adds or updates a game in games.json (and uploads its file to a GitHub Release of this repository).
#   -File      the game: .zip (portable, -Exe = what to run), .exe (one program, or -Installer for an installer)
#   no -File   only a link to -Site (paid / other people's games)
#   -Torrent   optional .torrent to offer as an alternative download;  -Cover  optional image
param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$Id, [Parameter(Mandatory)][string]$Name, [string]$By = '', [string]$Desc = '',
      [string]$Site = '', [string]$File, [string]$Exe, [switch]$Installer, [string]$Version = '1.0', [string]$Torrent, [string]$Cover,
      [ValidateSet('own', 'friend', 'free', 'store')][string]$License = 'own', [switch]$NoPush)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$repo = 'SOVALONE/valo-games'
$utf8 = [Text.UTF8Encoding]::new($false)
$cat = Get-Content "$root\games.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$g = [ordered]@{ id = $Id; name = $Name; by = $By; desc = $Desc; site = $Site; license = $License }
if ($File) {
    if ($License -eq 'store') { throw 'Ігри з магазинів — лише посиланням (без -File)' }
    $f = Get-Item $File
    $kind = if ($f.Extension -eq '.zip') { 'zip' } elseif ($Installer) { 'installer' } else { 'exe' }
    if ($kind -eq 'zip' -and -not $Exe) { throw 'Для .zip вкажіть -Exe (який файл запускати)' }
    $tag = "$Id-$Version"
    $asset = ($f.Name -replace '[^A-Za-z0-9._-]', '_')
    $ErrorActionPreference = 'Continue'
    gh release view $tag --repo $repo *> $null
    if ($LASTEXITCODE -ne 0) { gh release create $tag --repo $repo --title "$Name $Version" --notes $Desc | Out-Null }
    $tmp = Join-Path $env:TEMP $asset; Copy-Item $f.FullName $tmp -Force
    gh release upload $tag $tmp --repo $repo --clobber
    if ($LASTEXITCODE -ne 0) { throw 'Не вдалося викласти файл' }
    Remove-Item $tmp; $ErrorActionPreference = 'Stop'
    $g.kind = $kind; $g.version = $Version
    $g.url = "https://github.com/$repo/releases/download/$tag/$asset"
    $g.sha256 = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLower(); $g.size = $f.Length
    if ($Exe) { $g.exe = $Exe }
} else {
    if (-not $Site) { throw 'Потрібен -File або -Site' }
    $g.kind = 'link'
}
if ($Torrent) { Copy-Item $Torrent "$root\torrents\$Id.torrent" -Force; $g.torrent = "torrents/$Id.torrent" }
if ($Cover) { $ext = [IO.Path]::GetExtension($Cover).ToLower(); Copy-Item $Cover "$root\covers\$Id$ext" -Force; $g.cover = "covers/$Id$ext" }
$list = @($cat.games | Where-Object { $_.id -ne $Id }) + [pscustomobject]$g
$out = [ordered]@{ version = 1; games = $list }
[IO.File]::WriteAllText("$root\games.json", (ConvertTo-Json -InputObject $out -Depth 5), $utf8)
"$Name -> games.json ($($g.kind))"
if (-not $NoPush) {
    $ErrorActionPreference = 'Continue'
    git -C $root add -A; git -C $root commit -q -m "game: $Name $Version"; git -C $root push -q
}
