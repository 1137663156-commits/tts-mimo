---
name: tts-mimo
description: "Use MiMo V2.5 TTS to synthesize speech from text. Triggers when user asks to read aloud, speak text, do text-to-speech,朗读, 朗读内容, 读给我听, 说出来, 语音合成, TTS, 文字转语音. Must use this skill for any speech synthesis request."
---

# MiMo V2.5 TTS Skill

Use the MiMo V2.5 TTS API to convert text into natural, expressive speech.

## Setup

The script reads the API key from environment variable `XIAOMI_API_KEY`. If not set, create a `.env` file in the skill directory with:

```
XIAOMI_API_KEY=your_api_key_here
```

Get your API key from [Xiaomi MiMo Platform](https://platform.xiaomimimo.com).

## Usage

Run the PowerShell script. Point `-File` at wherever this skill is installed (`<skill-dir>` = the folder containing this SKILL.md), and `-Output` at any writable path (relative paths resolve from the current directory):

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\tts.ps1" -Text "要朗读的文本" -Output "output.mp3"
```

For Chinese / Japanese / Korean or long text, prefer `-TextFile` with a UTF-8 file. Passing non-ASCII through `powershell -File` can be corrupted by the console code page on Windows PowerShell 5.1; a text file avoids that entirely (and dodges quoting / length limits):

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\tts.ps1" -TextFile "input.txt" -Output "output.mp3"
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-Text` | Yes* | — | The text to synthesize (use `-TextFile` for CJK / long text) |
| `-TextFile` | Yes* | — | Path to a UTF-8 text file to synthesize (alternative to `-Text`) |
| `-Output` | Yes | — | Output file path (.mp3 recommended) |
| `-Voice` | No | `mimo_default` | Voice name (冰糖/茉莉/苏打/白桦/Mia/Chloe/Milo/Dean) |
| `-VoiceDescription` | No | — | Natural language description of custom voice (e.g., "温柔年轻的女声") |
| `-Style` | No | — | Style instruction in natural language |
| `-Format` | No | `mp3` | Output format (mp3/wav/opus/flac/pcm) |
| `-NoPlay` | No | false | Skip system playback after generation (file only) |

### Available Voices

- **冰糖** — Chinese female, sweet and warm
- **茉莉** — Chinese female, clear and elegant
- **苏打** — Chinese male, young and energetic
- **白桦** — Chinese male, deep and steady
- **Mia** — English female
- **Chloe** — English female
- **Milo** — English male
- **Dean** — English male

### Examples

**Basic read-aloud:**
```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\tts.ps1" -Text "你好世界" -Output "hello.mp3"
```

**With style instruction:**
```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\tts.ps1" -Text "这段文字很感人" -Style "用温柔略带伤感的语气朗读" -Voice "茉莉" -Output "emotional.mp3"
```

**With audio tags (embedded in text):**
```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\tts.ps1" -Text "(微笑)今天天气真好，我们出去走走吧。" -Output "sunny.mp3"
```

**Generate only, no playback:**
```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\tts.ps1" -Text "存成文件稍后再听" -Output "later.mp3" -NoPlay
```

**From a UTF-8 file (best for CJK / long text):**
```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\tts.ps1" -TextFile "input.txt" -Output "from_file.mp3"
```

## Style Control

MiMo V2.5 TTS supports rich style control:

### Natural Language Style (via -Style parameter)
Describe the desired speaking style naturally:
- "用低沉沙哑的声音，像历经沧桑的老前辈在讲述"
- "用欢快活泼的语气，语速稍快，带点兴奋"
- "用磁性温柔的声音，像深夜电台主持人"

### Audio Tags (embedded in text)
Wrap style tags in parentheses at the start or inline:
- `(微笑)你好呀！` — happy tone
- `(叹气)这件事说来话长……` — sighing
- `[喘息]等等……让我……喘口气` — breathing
- `(唱歌)月亮代表我的心` — singing mode

### Director Mode
For complex scenarios, use structured instructions in -Style:
```
角色: 一位资深新闻主播
场景: 正在播报晚间头条新闻
指导: 声音沉稳有力，语速适中，咬字清晰，带有权威感
```

## Notes

- Text must be under ~5000 characters per call
- Provide text with either `-Text` or `-TextFile`. For Chinese and other non-ASCII text, **use `-TextFile`** — `powershell -File` can mangle non-ASCII command-line arguments on Windows PowerShell 5.1 (`pwsh -File` is unaffected).
- Audio tags work in both Chinese and English
- Style instructions are optional but greatly enhance expressiveness
- Output is mp3 by default, compatible with most players and Bridge
- By default the audio plays through the **Windows system audio subsystem** (winmm / MCI): no external player window, no leftover player process. Playback blocks until the clip finishes, so a successful run means the audio has been heard in full.
- System playback supports `mp3` and `wav` (and `wma`). For `opus`, `flac`, or `pcm` output the file is still generated but playback is skipped with a clear warning.
- Add `-NoPlay` to generate the file without any playback

## Platform Notes

- Speech **generation** is platform-independent (it is a plain HTTPS API call).
- Automatic **playback** currently uses Windows MCI and is therefore Windows-only. On macOS or Linux, generation still works; playback is skipped with a warning so callers can play the file with their own tooling.
- Never commit the `.env` file — it holds your API key. See `.gitignore` in this skill package.
