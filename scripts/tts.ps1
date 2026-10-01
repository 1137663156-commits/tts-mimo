<#
.SYNOPSIS
    MiMo V2.5 TTS - Text to Speech via Xiaomi MiMo API
.DESCRIPTION
    Converts text to speech using MiMo-V2.5-TTS model.
    Supports built-in voices, style instructions, and audio tags.
.PARAMETER Text
    The text to synthesize. Provide either -Text or -TextFile.
.PARAMETER TextFile
    Path to a UTF-8 text file to synthesize. Recommended for CJK or long text:
    it bypasses command-line argument encoding issues on Windows PowerShell 5.1.
.PARAMETER Output
    Output file path (e.g., output.mp3). Required.
.PARAMETER Voice
    Voice name: 冰糖, 茉莉, 苏打, 白桦, Mia, Chloe, Milo, Dean. Default: mimo_default
.PARAMETER Style
    Optional natural language style instruction.
.PARAMETER Format
    Output format: mp3, wav, opus, flac, pcm. Default: mp3
.PARAMETER NoPlay
    Skip automatic system playback after generation. Use when you only want the file.
.NOTES
    Playback uses the Windows multimedia subsystem (winmm / MCI), so audio is played
    in-process through the default audio device with no external player window.
    Playback blocks until the audio finishes. Requires Windows.
#>
param(
    [string]$Text,

    [string]$TextFile,

    [Parameter(Mandatory=$true)]
    [string]$Output,

    [string]$Voice = "mimo_default",

    [string]$VoiceDescription = "",

    [string]$Style = "",

    [string]$Format = "mp3",

    [switch]$NoPlay
)

# --- Resolve text input ---
# -TextFile is the robust path for CJK or long text. Passing non-ASCII through
# `powershell -File` can be corrupted by the console code page; a UTF-8 file
# avoids that entirely.
if (-not $Text -and $TextFile) {
    if (-not (Test-Path -LiteralPath $TextFile)) {
        Write-Error "Text file not found: $TextFile"
        exit 1
    }
    $Text = Get-Content -LiteralPath $TextFile -Raw -Encoding UTF8
}
if (-not $Text -or $Text.Trim().Length -eq 0) {
    Write-Error "No text provided. Use -Text <string> or -TextFile <path>."
    exit 1
}

# --- Load API key ---
$apiKey = $env:XIAOMI_API_KEY
if (-not $apiKey) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
    $envFile = Join-Path $scriptDir "..\.env"
    if (Test-Path $envFile) {
        $lines = Get-Content $envFile
        foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line -and -not $line.StartsWith("#")) {
                $parts = $line -split "=", 2
                if ($parts.Length -eq 2) {
                    $key = $parts[0].Trim()
                    $val = $parts[1].Trim()
                    if ($key -eq "XIAOMI_API_KEY") { $apiKey = $val }
                }
            }
        }
    }
}

if (-not $apiKey) {
    Write-Error "XIAOMI_API_KEY not found. Set the environment variable or create .env file in the skill directory."
    exit 1
}

# --- Build messages array ---
# For VoiceDesign: user message contains voice description
# For standard TTS: user message contains style instruction
$messages = @()

if ($VoiceDescription -and $VoiceDescription.Trim().Length -gt 0) {
    # VoiceDesign mode: user message is voice description
    $messages += @{
        role = "user"
        content = $VoiceDescription
    }
} elseif ($Style -and $Style.Trim().Length -gt 0) {
    # Standard TTS with style instruction
    $messages += @{
        role = "user"
        content = $Style
    }
}

# Assistant message always contains the text to synthesize
$messages += @{
    role = "assistant"
    content = $Text
}

# --- Build request body ---
# Validate format for VoiceDesign model
if ($VoiceDescription -and $VoiceDescription.Trim().Length -gt 0 -and $Format -ne "wav") {
    Write-Warning "VoiceDesign model only supports WAV format. Changing format to WAV."
    $Format = "wav"
}

# Determine which model to use based on VoiceDescription
if ($VoiceDescription -and $VoiceDescription.Trim().Length -gt 0) {
    # Use VoiceDesign model with voice description
    $model = "mimo-v2.5-tts-voicedesign"
    $body = @{
        model = $model
        messages = $messages
        audio = @{
            format = $Format
            optimize_text_preview = $true
        }
    } | ConvertTo-Json -Depth 10 -Compress
} else {
    # Use standard TTS model with predefined voice
    $model = "mimo-v2.5-tts"
    $body = @{
        model = $model
        messages = $messages
        voice = $Voice
        response_format = $Format
    } | ConvertTo-Json -Depth 10 -Compress
}

# --- Call API ---
$apiUrl = "https://api.xiaomimimo.com/v1/chat/completions"

Write-Output "Calling MiMo TTS API..."
Write-Output "Model: $model"
if ($VoiceDescription) {
    Write-Output "Voice description: $VoiceDescription"
} else {
    Write-Output "Voice: $Voice"
}
Write-Output "Text length: $($Text.Length) characters"

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers @{
        "api-key" = $apiKey
        "Content-Type" = "application/json"
    } -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 120
}
catch {
    Write-Error "API call failed: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()
        Write-Error "Response: $errorBody"
    }
    exit 1
}

# --- Extract audio data ---
# MiMo TTS returns audio in choices[0].message.audio.data (base64)
$audioData = $null

if ($response.choices -and $response.choices.Count -gt 0) {
    $msg = $response.choices[0].message

    # Standard path: audio field
    if ($msg.audio -and $msg.audio.data) {
        $audioData = $msg.audio.data
    }
    # Fallback: content may contain base64 data URL
    elseif ($msg.content) {
        $content = $msg.content
        if ($content -match "^data:audio/[^;]+;base64,(.+)$") {
            $audioData = $Matches[1]
        }
        elseif ($content -match "^[A-Za-z0-9+/=]{100,}$") {
            $audioData = $content
        }
    }
}

if (-not $audioData) {
    Write-Error "Failed to extract audio data from API response."
    Write-Error "Full response: $($response | ConvertTo-Json -Depth 5)"
    exit 1
}

# --- Decode and save ---
$audioBytes = [System.Convert]::FromBase64String($audioData)

# Ensure output directory exists
$outputDir = Split-Path -Parent $Output
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

[System.IO.File]::WriteAllBytes($Output, $audioBytes)

# Output file info
$fi = Get-Item $Output
Write-Output "OK: TTS synthesized successfully"
Write-Output "File: $($fi.FullName)"
Write-Output "Size: $([math]::Round($fi.Length / 1024, 1)) KB"
Write-Output "Format: $Format"
Write-Output "Voice: $Voice"

# --- Playback: system audio (in-process, no external player window) ---
if (-not $NoPlay) {
    $fullPath = $fi.FullName
    $ext = [System.IO.Path]::GetExtension($fullPath).ToLowerInvariant()

    # MCI device type by container. These are the formats the Windows
    # multimedia subsystem can play through the default audio device.
    $mciType = switch ($ext) {
        ".mp3"  { "mpegvideo" }
        ".wma"  { "mpegvideo" }
        ".wav"  { "waveaudio" }
        default { $null }
    }

    if (-not $mciType) {
        # No silent fallback: say it plainly, keep the file for the caller.
        Write-Warning "System playback does not support '$ext'. Skipping playback. File: $fullPath"
    }
    elseif (-not $IsWindows -and $PSVersionTable.PSEdition -eq "Core") {
        Write-Warning "System playback via winmm is Windows-only. Skipping playback. File: $fullPath"
    }
    else {
        Add-Type -Name WinMM -Namespace HanaTTS -MemberDefinition @'
[DllImport("winmm.dll", CharSet=CharSet.Auto)]
public static extern int mciSendString(string command, System.Text.StringBuilder buffer, int bufferSize, IntPtr hwndCallback);
[DllImport("winmm.dll", CharSet=CharSet.Auto)]
public static extern bool mciGetErrorString(int errorCode, System.Text.StringBuilder errorText, int errorTextSize);
'@

        # Unique alias so repeated runs never collide.
        $alias = "hanatts_" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
        $mciPath = $fullPath -replace '"', '""'

        $rc = [HanaTTS.WinMM]::mciSendString("open `"$mciPath`" type $mciType alias $alias", $null, 0, [IntPtr]::Zero)

        if ($rc -ne 0) {
            $errBuf = New-Object System.Text.StringBuilder 512
            [void][HanaTTS.WinMM]::mciGetErrorString($rc, $errBuf, 512)
            Write-Warning "System playback failed (MCI rc=$rc): $($errBuf.ToString().Trim()). File: $fullPath"
        }
        else {
            Write-Output "PLAYING: System playback (no external player)..."
            try {
                # 'wait' keeps the process alive until playback ends, so it owns
                # the audio lifetime without spawning any player window.
                [void][HanaTTS.WinMM]::mciSendString("play $alias wait", $null, 0, [IntPtr]::Zero)
            }
            finally {
                [void][HanaTTS.WinMM]::mciSendString("close $alias", $null, 0, [IntPtr]::Zero)
            }
            Write-Output "PLAYBACK: done"
        }
    }
}
