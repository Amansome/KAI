# Kitchen Assistant - Setup Instructions (LLM.swift)

## Quick Start (5 Minutes!)

### Prerequisites
- Xcode 14.0+
- iOS 16.0+ (iPad recommended)
- 2GB+ free storage on device

### Step 1: Add LLM.swift Package (2 minutes)

1. Open Xcode project:
   ```bash
   open kitchen-assistant/ios-app/KAI/KAI.xcodeproj
   ```

2. Add LLM.swift package:
   - **File** → **Add Package Dependencies**
   - Enter URL: `https://github.com/eastriverlee/LLM.swift`
   - Version: **Latest** (2.0.1 or newer)
   - Add to **KAI** target
   - Click **Add Package**

3. That's it! No build settings to change, no C++ interop needed! ✅

### Step 2: Build and Run (1 minute)

1. Select iPad simulator or physical device
2. **Product** → **Build** (⌘B)
3. **Product** → **Run** (⌘R)
4. App should launch successfully!

### Step 3: Download Model (2 minutes)

**On iPad:**
1. Tap **Settings** (gear icon)
2. In "AI Model" section, tap **"Download Model"**
3. Wait 2-5 minutes (~1.5GB download)
4. Model loads automatically when complete
5. Start asking questions!

## ✅ That's It!

No complex setup, no C++ configuration, just works! 🎉

## Usage

### Voice Input
1. Say **"Hey, Kai"** to activate wake word
2. Wait for confirmation beep
3. Ask your recipe question
4. Get AI-powered response

### Text Input
1. Tap segmented control to switch to **Text** mode
2. Type your question
3. Press return or tap send
4. Get AI-powered response

### Example Questions
- "What ingredients are in McAlister's Club?"
- "How do I make the kids pizza?"
- "What recipes use bacon?"
- "Can I substitute turkey for chicken?"
- "Show me all sandwich recipes"

## Troubleshooting

### "Model not downloaded"
- Go to Settings → AI Model → Download Model
- Ensure WiFi connection
- Need 2GB free storage

### "LLM.swift not found" build error
- Make sure you added the Swift package
- URL: https://github.com/eastriverlee/LLM.swift
- Clean build folder: **Product** → **Clean Build Folder**
- Rebuild

### "Out of memory" on device
- Close other apps
- Restart iPad
- Model needs ~2GB RAM

## Technical Details

### Architecture
```
User Query → LLMQueryProcessor
           → LocalLLMManager
           → LLMSwiftClient (LLM.swift)
           → Llama 3.2 1B Model
           → Response
```

### Model Information
- **Name**: Llama 3.2 1B Instruct Q4_K_M
- **Size**: ~1.5 GB
- **Format**: GGUF
- **Performance**: 10-20 tokens/second
- **Source**: HuggingFace

### Storage
- **Model**: 1.5 GB (in Documents/Models/)
- **App**: ~10 MB
- **Total**: ~1.6 GB

## Development Notes

### Why LLM.swift?
- ✅ **Pure Swift** - No C++ interop needed
- ✅ **Simple API** - `try await llm.generate()`
- ✅ **Same Performance** - Uses llama.cpp internally
- ✅ **Easy Setup** - Just add Swift package
- ✅ **Type Safe** - Swift error handling
- ✅ **Well Maintained** - Active development

### Code Structure
```swift
// Load model (that's all you need!)
let llm = try await LLM(from: modelPath)

// Generate response (so simple!)
let response = try await llm.generate(
    query,
    maxTokens: 512,
    temperature: 0.7
)

// Streaming support
for try await token in llm.generate(query) {
    print(token, terminator: "")
}
```

### Files Overview
- **LLMSwiftClient.swift** - Clean wrapper around LLM.swift
- **LocalLLMManager.swift** - State management & coordination
- **ModelDownloadManager.swift** - Download from HuggingFace
- **RecipeContextBuilder.swift** - Build prompts with recipes
- **LLMQueryProcessor.swift** - High-level query interface

## Next Steps

### For Users
1. Download model in Settings
2. Start asking questions!
3. Works completely offline after download

### For Developers
1. Review code in Managers/ folder
2. Customize in LLMSwiftClient.swift:
   - Temperature (creativity)
   - MaxTokens (response length)
   - Context size
3. Modify RecipeContextBuilder for custom prompts
4. Add new features in LLMQueryProcessor

## Resources

- **LLM.swift**: https://github.com/eastriverlee/LLM.swift
- **Documentation**: See LLM_INTEGRATION.md
- **Model**: https://huggingface.co/hugging-quants/Llama-3.2-1B-Instruct-Q4_K_M-GGUF

## Support

Issues? Check:
1. Package added correctly (Build Phases → Link Binary)
2. Model downloaded (Settings → AI Model)
3. Sufficient storage (2GB free)
4. Sufficient RAM (2GB available)

---

**Setup Time**: 5 minutes total
**Ready to use**: Immediately after model download
**Completely offline**: After initial setup

✨ Enjoy your AI-powered Kitchen Assistant! ✨
