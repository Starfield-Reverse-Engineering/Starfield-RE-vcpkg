#Requires -Version 5

# args
param (
    [string]$ShaIn = 0
)

function Out-Json {
    param(
        [string]$outfile,
        [Object]$json
    )

    $json = $json | ConvertTo-Json -Depth 9 | ForEach-Object { $_ -replace "(?m)  (?<=^(?:  )*)", "  " }
    [IO.File]::WriteAllText($outfile, $json)
}

function Get-Latest {
    param(
        [string]$repo
    )

    $parse = (& git ls-remote "$repo.git" rev-parse HEAD) -split '\s'
    return $parse[0]
}


try {
    $repo = Resolve-Path $PSScriptRoot/../
    Push-Location $repo

    # test-path
    $manifests = @(
        "$PSScriptRoot/portfile.cmake.in",
        "$repo/ports/commonlibsf/portfile.cmake",
        "$repo/ports/commonlibsf/vcpkg.json",
        "$repo/versions/c-/commonlibsf.json",
        "$repo/versions/baseline.json",
        "$repo/README.md",
        "$PSScriptRoot/workflows/update_registry.yml"
    )
    
    Write-Host "Checking files..."
    foreach ($file in $manifests) {
        if (!(Test-Path $file)) {
            throw "File not found : {$file}"
        }
    }
    Write-Host "...Ok, all files present"
    
    
    # check ShaIn
    Write-Host "Checking REF..."
    if ($ShaIn -eq 0) {
        # use latest, this is meant for manual workflow dispatch
        $ShaIn = Get-Latest "https://github.com/$($env:VCPKG_PORT_REPO)/CommonLibSF"
    }

    if ($ShaIn -eq 0) {
        throw "Invalid REF for main repo"
    }

    # check REF collision
    $portfile = [IO.File]::ReadAllText($manifests[1])
    if ($portfile.Contains("REF $ShaIn")) {
        throw "Existing REF for main repo, skipping action"
    }
    Write-Host "...Upstream: $($env:VCPKG_PORT_REPO)`nREF: $($ShaIn)"
    

    # calc hash
    Write-Host "Hashing tarball..."
    $uri = "https://github.com/$($env:VCPKG_PORT_REPO)/CommonLibSF/archive/$ShaIn.tar.gz"
    Invoke-WebRequest -Uri $uri -OutFile "$PSScriptRoot/tarball"
    $hash = (Get-FileHash "$PSScriptRoot/tarball" -Algorithm SHA512).Hash
    Write-Host "...SHA512 $($hash)"


    # make portfile
    Write-Host "Making portfile..."
    $header = "
vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO $($env:VCPKG_PORT_REPO)/CommonLibSF
"
    $portfile = [System.Collections.ArrayList]::new()
    $portfile.Add($header) | Out-Null
    $portfile.Add(" REF $ShaIn`n") | Out-Null
    $portfile.Add(" SHA512 $hash`n") | Out-Null
    $portfile.Add(" HEAD_REF main)`n") | Out-Null
    $portfile.Add([IO.File]::ReadAllText($manifests[0])) | Out-Null
    
    [IO.File]::WriteAllText($manifests[1], $portfile)
   
    Write-Host "...Ok"
    

    # fetch vcpkg.json
    Write-Host "Fetching vcpkg.json from upstream..."
    $uri = "https://raw.githubusercontent.com/$($env:VCPKG_PORT_REPO)/CommonLibSF/$ShaIn/CommonLibSF/vcpkg.json"
    $vcpkg = Invoke-RestMethod -Uri $uri
    $version = $vcpkg.'version-date'
    
    # make vcpkg.json
    Out-Json $manifests[2] $vcpkg
    Write-Host "...Ok"
    

    # test build
    Write-Host "Testing port package..."
    $triplet = "x64-windows-static"
    $failed = $false
    $vcpkg_test = & "$($env:VCPKG_ROOT)/vcpkg" install commonlibsf:$triplet --overlay-ports="$repo/ports/commonlibsf" | ForEach-Object {
        if ($_.StartsWith("error: ")) {
            $script:failed = $true
        }
        $_ + "`n"
    }
    if ($failed) {
        throw "Cannot compile vcpkg port:`n$vcpkg_test"
    }
    Write-Host "...Ok"


    # update version entries
    Write-Host "Propagating version entry..."
    $gitlog = & git config user.name "vcpkg-action"
    $gitlog += & git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    $gitlog += & git commit -am "port: check"
    $tree = & git rev-parse HEAD:ports/commonlibsf
    $gitlog += $tree

    $entries = [IO.File]::ReadAllText($manifests[3]) | ConvertFrom-Json
    # check entry collision
    foreach ($entry in $entries.versions[$entries.versions.Length..0]) {
        if ($entry.version.Contains($version)) {
            Write-Host "Updating existing entry $version"
            $version = if ($entry.version.Contains('.')) {
                $identifiers = $entry.version.Split('.')
                "$($identifiers[0]).$([Int32]$identifiers[1] + 1)"
            }
            else {
                "$($entry.version).1"
            }
            break
        }
    }
    if ([string]::IsNullOrEmpty($version)) {
        throw "Failed to parse version-date"
    }

    Write-Host "Adding new entry $version"
    $entry = '{ "version": "", "port-version": 0, "git-tree": "" }' | ConvertFrom-Json
    $entry.version = $version
    $entry.'git-tree' = $tree
    $entries.versions += $entry
    Out-Json $manifests[3] $entries
    Write-Host "...Ok, git-tree set to $tree"


    # update baseline
    Write-Host "Updating baseline..."
    $baseline = [IO.File]::ReadAllText($manifests[4]) | ConvertFrom-Json
    $baseline.default.commonlibsf.baseline = $version
    Out-Json $manifests[4] $baseline
    Write-Host "New baseline -> $version"


    # commit
    Write-Host "Committing vcpkg port..."
    $gitlog += & git commit --amend -am "port: ``$version``"


    # update docs
    Write-Host "Updating docs..."
    $readme = [IO.File]::ReadAllLines($manifests[5])
    $latest = @(
        @{
            uri = "https://github.com/microsoft/vcpkg"
            sha = Get-Latest "https://github.com/microsoft/vcpkg"
        },
        @{
            uri = "https://github.com/Starfield-Reverse-Engineering/Starfield-RE-vcpkg"
            sha = & git rev-parse HEAD
        }
    )
    $readme = $readme -replace "(?<=label=vcpkg%20registry&message=).+?(?=&color)", $version
    for ($i = 0; $i -lt $readme.Length; $i = $i + 1) {
        foreach ($replacer in $latest) {
            if ($readme[$i].Contains($replacer.uri)) {
                $readme[$i + 1] = $readme[$i + 1] -replace '(?<="baseline": ").*?(?=")', $replacer.sha
                $i = $i + 1
                continue
            }
        }
    }
    [IO.File]::WriteAllLines($manifests[5], $readme)

    $yaml = [IO.File]::ReadAllText($manifests[6])
    $yaml = $yaml -replace "(?<=VCPKG_COMMIT_ID: ).*?(?=\s)", $latest[0].sha
    [IO.File]::WriteAllText($manifests[6], $yaml)
    Write-Host "...Ok"


    # check gitlog
    $failed = $false
    foreach ($log in $gitlog) {
        if ($log.StartsWith("fatal: ")) {
            $failed = $true
            break
        }
    }
    if ($failed) {
        throw "Cannot commit action:`n$gitlog"
    }

    Write-Output "VCPKG_SUCCESS=true" >> $env:GITHUB_OUTPUT
}
catch {
    Write-Error "...Failed: $_"
    Write-Output "VCPKG_SUCCESS=false" >> $env:GITHUB_OUTPUT
}
finally {
    Pop-Location
    Remove-Item "$PSScriptRoot/tarball" -Force -Confirm:$false -ErrorAction:SilentlyContinue | Out-Null
    exit
}

