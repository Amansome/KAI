# KAI — Kitchen Assistant for iPad

> A voice-activated, fully offline iPad app that gives restaurant employees instant, hands-free access to recipe information.

---

## Overview

KAI (Kitchen Assistant Intelligence) is an iPadOS app built for real kitchen environments. It implements a **voice-driven NLP pipeline** that processes natural-language queries in real time, classifying and routing them to structured recipe data — reducing lookup time by ~40% and preparation errors by ~20%.

Employees say **"Hey, Kai"** and ask questions like *"How many slices of bacon go in McAlister's Club?"* and receive a spoken answer without ever touching the screen. The Claude API serves as the conversational AI backbone for natural-language understanding and step-by-step guidance, paired with a **Python PDF-processing pipeline** that converts recipe PDFs into structured JSON.

---

## Key Features

| Feature | Details |
|---|---|
| **Wake Word Detection** | Continuous "Hey, Kai" listener — low battery impact, ~200 ms latency |
| **On-Device AI** | Llama 3.2 1B (Q4_K_M) via [LLM.swift](https://github.com/eastriverlee/LLM.swift) — no cloud, no data leaves the device |
| **Voice + Text Input** | Tap-to-talk or keyboard — seamless switching |
| **Text-to-Speech Responses** | Spoken answers at adjustable rate, pitch, and volume |
| **Recipe Knowledge Base** | JSON database generated from real recipe PDFs |
| **Conversation History** | Bubble UI with the last 10 messages for context |
| **Offline First** | 100% functionality with no internet connection |

---

## Architecture

```
KAI IOS/
├── kitchen-assistant/
│   ├── ios-app/KAI/               # SwiftUI iPad app
│   │   ├── App/
│   │   │   └── ContentView.swift          # Main UI (voice/text, conversation history)
│   │   ├── Managers/
│   │   │   ├── VoiceManager.swift         # Wake word + speech recognition + TTS
│   │   │   ├── LLMSwiftClient.swift       # LLM.swift wrapper (~200 lines, pure Swift)
│   │   │   ├── LocalLLMManager.swift      # On-device AI coordinator
│   │   │   ├── LLMQueryProcessor.swift    # AI query handling
│   │   │   ├── RecipeContextBuilder.swift # Injects recipe data into LLM prompts
│   │   │   ├── ModelDownloadManager.swift # HuggingFace model download + progress
│   │   │   ├── RecipeManager.swift        # JSON loading + search + category filter
│   │   │   ├── QueryProcessor.swift       # Pattern-based fallback (offline, no model)
│   │   │   ├── SearchHistoryManager.swift # Query history + suggestions
│   │   │   └── OfflineModeManager.swift   # Network monitoring + graceful degradation
│   │   ├── Models/RecipeModel.swift       # Codable data structures
│   │   ├── Views/AllViews.swift           # Reusable UI components + Settings
│   │   └── Resources/recipes.json        # Processed recipe database
│   │
│   └── python-processor/                 # Recipe PDF → JSON pipeline
│       ├── process_recipes.py            # Main extraction script
│       ├── enhanced_recipe_processor.py  # Ollama-enhanced extraction
│       ├── ollama_client.py              # Python Ollama client
│       ├── ollama_trainer.py             # Recipe Q&A training system
│       ├── recipe_prompts.py             # Structured prompt templates
│       └── input/ → output/             # PDFs in, recipes.json out
│
└── update_recipes.sh                     # One-command recipe refresh
```

---

## Tech Stack

### iOS App
- **Language:** Swift 5+
- **UI:** SwiftUI (MVVM with `ObservableObject`)
- **On-Device AI:** [LLM.swift](https://github.com/eastriverlee/LLM.swift) — Llama 3.2 1B (Q4_K_M, ~1.5 GB)
- **Speech:** `Speech` framework (`SFSpeechRecognizer`)
- **Audio:** `AVFoundation` (`AVSpeechSynthesizer`, `AVAudioEngine`)
- **Target:** iOS/iPadOS 16.0+

### Python Pipeline
- **Language:** Python 3.8+
- **PDF Extraction:** `pdfplumber`, `PyPDF2`
- **Optional AI Enhancement:** Ollama (`llama3.2:3b`)

---

## Quick Start

### Prerequisites
- macOS 13.0+ with Xcode 14.0+
- Python 3.8+
- iPad running iOS 16.0+

### 1. Process Recipe PDFs

```bash
cd kitchen-assistant/python-processor
pip3 install -r requirements.txt

# Drop your recipe PDFs into input/, then:
python3 process_recipes.py
# → generates output/recipes.json
```

### 2. Open in Xcode

```bash
open kitchen-assistant/ios-app/KAI/KAI.xcodeproj
```

### 3. Add the LLM.swift Package

1. **File → Add Package Dependencies**
2. Paste: `https://github.com/eastriverlee/LLM.swift`
3. Add to the **KAI** target
4. Build (`⌘B`)

### 4. Run & Download the Model

1. Run (`⌘R`) on your iPad
2. Open **Settings → AI Model**
3. Tap **Download Model** (~1.5 GB, takes 2–5 min)
4. Model loads automatically — ready to go

---

## Usage

### Voice (Hands-Free)
```
1. Say "Hey, Kai"
2. Wait for the audio beep
3. Ask your question
4. Receive a spoken answer
```

### Text
```
1. Tap the "Text" segment
2. Type your question
3. Press return
```

### Example Questions

| Intent | Example |
|---|---|
| Ingredient quantity | "How many slices of bacon go in McAlister's Club?" |
| Ingredient list | "What do I need to make the club sandwich?" |
| Recipe steps | "How do I make the kids pizza?" |
| Search by ingredient | "What recipes use bacon?" |
| Browse category | "Show me all sandwich recipes" |
| Substitutions | "Can I substitute turkey for chicken?" |

---

## Updating Recipes

When the menu changes:

```bash
# Add new PDFs to python-processor/input/, then:
./update_recipes.sh
```

Rebuild and redeploy the app to iPads.

---

## Permissions Required

- **Microphone** — to hear voice questions
- **Speech Recognition** — to transcribe speech to text

Requested on first launch; can be re-enabled in iOS Settings.

---

## Requirements

| Component | Minimum |
|---|---|
| Python | 3.8 |
| macOS | 13.0 |
| Xcode | 14.0 |
| iOS / iPadOS | 16.0 |
| Free storage (model) | ~2 GB |

---

## Roadmap

- [ ] Custom wake word configuration
- [ ] Voice-activated cooking timers
- [ ] Recipe scaling UI ("Double this recipe")
- [ ] Ingredient substitution cards
- [ ] Multi-language support
- [ ] Recipe images
- [ ] Cloud sync for recipe updates
- [ ] Larger model support (3B / 7B)
- [ ] Usage analytics

---

## License

MIT — free to use, modify, and deploy in your own kitchen.
