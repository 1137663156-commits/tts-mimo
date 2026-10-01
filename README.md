# tts-mimo

把小米 **MiMo V2.5 TTS** 语音合成接进任意 Agent：一段文本进去，一段自然、带情绪的中文 / 英文语音出来。

- **系统播放**：合成后直接走 Windows 系统音频子系统（winmm / MCI）播放，**不弹播放器窗口、不留后台播放器进程**
- **零依赖**：纯 PowerShell 调 HTTPS API，不用 pip、不用 npm
- **声音可调**：内置 8 个音色，支持自然语言风格指令、括号音频标签、导演模式
- **可移植**：脚本自定位、不写死绝对路径，clone 下来配上 key 就能跑

## 环境要求

| 项 | 要求 |
|----|------|
| 系统 | Windows（语音合成本身跨平台，但自动播放用了 Windows MCI） |
| Shell | Windows PowerShell 5.1 或 PowerShell 7+ |
| 网络 | 能访问 `https://api.xiaomimimo.com` |
| 密钥 | 小米 MiMo 平台 API Key |

## 安装

```powershell
git clone <repo-url>
cd tts-mimo
```

把 `.env.example` 复制成 `.env`，填入你的 key：

```
XIAOMI_API_KEY=your_api_key_here
```

或者直接设环境变量 `XIAOMI_API_KEY`（脚本优先读环境变量，没有再读同目录的 `.env`）。

> ⚠️ `.env` 里是你的真实密钥，**永远不要提交到仓库**。本仓库的 `.gitignore` 已经忽略了它。

## 用法

`<skill-dir>` 指本技能所在目录。

**基本朗读：**

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\tts.ps1" -Text "你好世界" -Output "hello.mp3"
```

**指定音色 + 风格：**

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\tts.ps1" -Text "这段文字很感人" -Style "用温柔略带伤感的语气朗读" -Voice "茉莉" -Output "emotional.mp3"
```

**括号内音频标签（嵌在文本里）：**

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\tts.ps1" -Text "(微笑)今天天气真好，我们出去走走吧。" -Output "sunny.mp3"
```

**只生成不播放：**

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\tts.ps1" -Text "存成文件稍后再听" -Output "later.mp3" -NoPlay
```

**从 UTF-8 文件读文本（中文 / 长文本推荐）：**

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>\scripts\tts.ps1" -TextFile "input.txt" -Output "from_file.mp3"
```

> 💡 中文等非 ASCII 文本建议走 `-TextFile`。在 Windows PowerShell 5.1 下，`powershell -File` 会按控制台代码页解析命令行参数，可能把中文参数弄坏（用 PowerShell 7 的 `pwsh -File` 不受影响）；写成 UTF-8 文件就能彻底绕开，顺带免去引号和长度限制的烦恼。

## 参数

| 参数 | 必填 | 默认 | 说明 |
|------|------|------|------|
| `-Text` | 是* | — | 要合成的文本（单次约 5000 字以内；中文 / 长文本建议改用 `-TextFile`） |
| `-TextFile` | 是* | — | 从 UTF-8 文本文件读入要合成的文本（与 `-Text` 二选一） |
| `-Output` | 是 | — | 输出文件路径（推荐 `.mp3`），相对路径按当前目录解析 |
| `-Voice` | 否 | `mimo_default` | 音色名，见下表 |
| `-VoiceDescription` | 否 | — | 用自然语言描述自定义音色（走 VoiceDesign 模型，只支持 wav） |
| `-Style` | 否 | — | 自然语言风格指令 |
| `-Format` | 否 | `mp3` | 输出格式：mp3 / wav / opus / flac / pcm |
| `-NoPlay` | 否 | false | 生成后不做系统播放，只要文件 |

## 内置音色

| 音色 | 说明 |
|------|------|
| 冰糖 | 中文女声，甜美温暖 |
| 茉莉 | 中文女声，清亮优雅 |
| 苏打 | 中文男声，年轻有活力 |
| 白桦 | 中文男声，低沉稳重 |
| Mia | 英文女声 |
| Chloe | 英文女声 |
| Milo | 英文男声 |
| Dean | 英文男声 |

## 风格控制

**自然语言风格**（`-Style`）：直接描述想要的语气，例如“用低沉沙哑的声音，像历经沧桑的老前辈在讲述”。

**音频标签**（写在文本里，用括号包裹）：`(微笑)`、`(叹气)`、`[喘息]`、`(唱歌)` 等，可放在句首或句中。

**导演模式**：把结构化指令写进 `-Style`：

```
角色: 一位资深新闻主播
场景: 正在播报晚间头条新闻
指导: 声音沉稳有力，语速适中，咬字清晰，带有权威感
```

## 关于播放

默认情况下，合成完成后脚本会通过 **Windows 多媒体子系统（winmm / MCI）** 直接播放音频：

- 没有外部播放器窗口，也不残留播放器进程
- 播放会**阻塞到音频播完**，所以脚本成功返回就意味着整段已经放完
- 系统播放支持 `mp3` / `wav` / `wma`；`opus` / `flac` / `pcm` 会正常生成文件，但跳过播放并给出明确警告（不做静默回退）
- 在 macOS / Linux 上，合成本身照常工作，只是自动播放会被跳过并提示，交给调用方自行播放文件

## 目录结构

```
tts-mimo/
├── SKILL.md            # 技能定义（frontmatter 描述 + 完整说明）
├── scripts/
│   └── tts.ps1         # 合成 + 系统播放脚本
├── .env.example        # 密钥模板
├── .gitignore
├── LICENSE
└── README.md
```

## License

MIT
