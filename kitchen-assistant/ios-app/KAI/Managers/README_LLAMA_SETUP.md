# KAI - Kitchen Assistant Integration Setup

## llama.cpp Swift Package Setup

This project supports both LLM.swift (simple wrapper) and native llama.cpp (better performance and control) implementations.

### 1. Add llama.cpp Swift Package

1. In Xcode, go to **File → Add Package Dependencies**
2. Enter the URL: `https://github.com/StanfordBDHG/llama.cpp`
3. Choose the latest version and add to your target

### 2. Enable C++ Interoperability

1. Select your project in Xcode
2. Go to **Build Settings**
3. Search for **"C++ and Objective-C Interoperability"**
4. Set it to: **C++ / Objective-C++**

### 3. Implementation Details

The project now includes both implementations:

#### Native llama.cpp (`LlamaCppClient.swift`)
- Direct C++ integration with llama.cpp
- Better performance and memory control
- More configuration options
- GPU acceleration support
- Real-time streaming
- Context management

#### LLM.swift wrapper (`LLMSwiftClient.swift`)
- Simplified Swift interface
- Easier to use but less control
- Fallback option if llama.cpp isn't available

### 4. Configuration

The `LLMSwiftClient` automatically chooses the implementation:

```swift
// Use native llama.cpp (recommended)
let client = LLMSwiftClient(config: .default, clientType: .llamaCpp)

// Use LLM.swift wrapper
let client = LLMSwiftClient(config: .default, clientType: .llamaSwift)
```

### 5. Model Requirements

The app expects Llama 3.2 1B model in GGUF format:
- Model will be downloaded automatically
- Stored in app's Documents directory
- Requires ~2GB storage space
- ~2GB RAM during inference

### 6. Features

- **Wake word detection**: "Hey, Kai"
- **Voice recognition**: Speech-to-text
- **Text-to-speech**: Spoken responses
- **Recipe context**: Kitchen-specific knowledge
- **Streaming responses**: Real-time text generation
- **Memory management**: Automatic context clearing
- **Error handling**: Graceful fallbacks

### 7. Troubleshooting

#### C++ Interop Issues
- Ensure "C++ and Objective-C Interoperability" is set correctly
- Clean and rebuild the project
- Check that llama.cpp package is properly added

#### Model Loading Issues
- Verify model file exists and is valid GGUF format
- Check available storage space (needs ~4GB free)
- Monitor memory usage during loading

#### Performance Issues
- Use `.fast` configuration for lower-end devices
- Reduce context size if memory is limited
- Enable GPU acceleration if available

### 8. Code Structure

```
KAI/
├── LlamaCppClient.swift      # Native llama.cpp integration
├── LLMSwiftClient.swift      # Unified client interface
├── LocalLLMManager.swift     # Model management
├── LLMQueryProcessor.swift   # Query processing
├── VoiceManager.swift        # Voice I/O
├── ModelDownloadManager.swift # Model downloading
└── RecipeManager.swift       # Recipe data
```

### 9. Build Configuration

Make sure your project has these settings:
- **Deployment Target**: iOS 16.0+ (for modern Swift features)
- **Swift Language Version**: Swift 6.0
- **C++ Language Dialect**: C++17 or later
- **Enable Modules**: Yes

### 10. Testing

Run the app and check the console for:
```
🔧 Using native llama.cpp implementation
📦 Loading llama.cpp model from: [path]
✅ llama.cpp model loaded successfully
👂 Wake word listening started - say 'Hey, Kai' to activate
```

If you see these logs, the integration is working correctly!

## Error Resolution

All the compilation errors have been fixed:

1. ✅ **Main actor isolation**: Fixed async/await patterns
2. ✅ **Equatable conformance**: Added to `LLMManagerState`
3. ✅ **String multiplication**: Replaced with `String(repeating:count:)`
4. ✅ **Optional handling**: Proper nil checking for `llmQueryProcessor`
5. ✅ **Type compatibility**: Unified error handling

The app should now compile and run successfully with both LLM implementations available.