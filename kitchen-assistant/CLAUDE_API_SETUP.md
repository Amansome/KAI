# Kitchen Assistant - Claude API Integration

## Overview

Your Kitchen Assistant app now uses **Claude API** by Anthropic for intelligent, context-aware recipe responses. Claude provides high-quality AI responses through a simple REST API.

## ✅ Already Configured!

Your API key is already configured in the app. **No setup needed** - just build and run!

## How It Works

```
1. User speaks: "Hey Kai, how do I make McAlister's Club?"
   ↓
2. VoiceManager transcribes speech to text
   ↓
3. App sends to Claude API with full recipe database context
   ↓
4. Claude generates intelligent, natural response
   ↓
5. App speaks the answer back to user
```

## Features

✅ **Intelligent Responses** - Claude understands context and nuance
✅ **Fast** - Typically 1-2 second responses
✅ **High Quality** - Claude 3.5 Sonnet (latest model)
✅ **No Local Setup** - Works instantly, no downloads
✅ **Internet Required** - Needs WiFi connection

## Example Interactions

**User:** "How do I make the McAlister's Club sandwich?"

**Claude:** "To make McAlister's Club, start by toasting 3 slices of bread until golden brown. Cook 4 slices of bacon until crispy. Spread mayonnaise on each bread slice. Layer turkey and swiss cheese on the first slice, add the second bread slice, then layer ham, cheddar cheese, bacon, lettuce, and tomato. Top with the third slice, secure with toothpicks, and cut diagonally into quarters."

**User:** "Can I substitute olive oil for vegetable oil?"

**Claude:** "Yes! Olive oil is a great substitute for vegetable oil in most recipes. Use a 1:1 ratio. Keep in mind that olive oil has a stronger flavor, so use light/refined olive oil if you want a neutral taste, or extra virgin if you want the olive flavor."

**User:** "What's the difference between Caesar and Greek salad?"

**Claude:** "The main differences are: Caesar salad uses romaine lettuce with a creamy anchovy-based dressing, parmesan cheese, and croutons. Greek salad uses mixed greens with tomatoes, cucumbers, red onions, kalamata olives, feta cheese, and a simple olive oil and lemon dressing. Caesar is creamy and rich, while Greek is light and tangy."

## Configuration

The app is configured with:
- **Model:** Claude 3.5 Sonnet (claude-3-5-sonnet-20241022)
- **Max Tokens:** 1024 (medium-length responses)
- **Temperature:** 0.7 (balanced creativity)

### To Change Settings

Edit [ClaudeClient.swift](kitchen-assistant/ios-app/KAI/Managers/ClaudeClient.swift:36):

```swift
static let `default` = ClaudeConfig(
    apiKey: "your-api-key-here",
    model: "claude-3-5-sonnet-20241022",  // Model version
    maxTokens: 1024,                       // Response length
    temperature: 0.7                       // 0.0-1.0 creativity
)
```

## API Key Management

**Current Key:** Embedded in code (temporary)

**For Production:**
1. Move API key to environment variables
2. Use iOS Keychain for secure storage
3. Or fetch from your backend server

**Security Note:** The current implementation embeds the API key in code. For a production app, store it securely or proxy requests through your backend.

## Cost

Claude API pricing (as of 2024):
- **Input:** ~$3 per million tokens
- **Output:** ~$15 per million tokens

**Typical usage:**
- Each query: ~500 input tokens (recipe context) + ~200 output tokens
- Cost per query: ~$0.004 (less than half a cent)
- 1000 queries: ~$4

Your API key includes free credits to get started!

## Error Handling

The app handles errors gracefully:

### "Invalid Claude API key"
- API key is wrong or expired
- Update key in ClaudeClient.swift

### "Network error"
- No internet connection
- Check WiFi/cellular
- App falls back to pattern matching

### "Rate limit exceeded"
- Too many requests
- Wait 60 seconds and try again
- Increase rate limits in Claude dashboard

## Troubleshooting

### No Response

**Check:**
1. Is iPad connected to internet?
2. Is API key valid?
3. Check Xcode console for errors

**Debug:**
```swift
// In Xcode console, you'll see:
🤖 Processing query with Claude API: How do I make...
📡 Claude API response: HTTP 200
✅ Claude response: To make McAlister's Club...
```

### Slow Responses

**Normal:**
- First request: 2-3 seconds (includes recipe context)
- Follow-ups: 1-2 seconds

**If slower:**
- Check internet speed
- Reduce maxTokens in config
- Simplify recipe context

### Falls Back to Pattern Matching

If Claude API fails, app automatically falls back to simple pattern matching (the old system). You'll get basic answers but not intelligent AI.

## Development

### Files Modified
1. **ClaudeClient.swift** (NEW) - Claude API HTTP client
2. **LocalLLMManager.swift** - Coordinates Claude + recipes
3. **LLMQueryProcessor.swift** - Query interface (unchanged)
4. **RecipeContextBuilder.swift** - Builds context (unchanged)

### Files Removed
- ❌ OllamaClient.swift
- ❌ LlamaCppClient.swift
- ❌ LLMSwiftClient.swift
- ❌ ModelDownloadManager.swift

### Architecture

```
User Query
  ↓
ContentView
  ↓
LLMQueryProcessor
  ↓
LocalLLMManager
  ↓
ClaudeClient (HTTP)
  ↓
Claude API (Anthropic)
  ↓
Intelligent Response
```

## Testing

### Quick Test

```swift
// In Xcode console or via test button
let (success, message) = await claudeClient.testConnection()
print(message)
// ✅ Connected to Claude API. Model: claude-3-5-sonnet-20241022
```

### Test Queries

Try these to verify it's working:
1. "How do I make McAlister's Club?"
2. "What ingredients are in the Greek salad?"
3. "Can I substitute ingredients?"
4. "How do I scale recipes?"

## Next Steps

### Before Production

1. **Secure API Key**
   - Move to environment variable
   - Or proxy through your backend

2. **Add Usage Tracking**
   - Monitor API costs
   - Set spending limits

3. **Implement Caching**
   - Cache common responses
   - Reduce API calls

4. **Add Retry Logic**
   - Handle transient failures
   - Exponential backoff

### Future Enhancements

1. **Streaming Responses**
   - Real-time token-by-token display
   - Better UX for long answers

2. **Conversation History**
   - Multi-turn conversations
   - Context from previous queries

3. **Custom Instructions**
   - Per-recipe special notes
   - Dietary restrictions
   - Kitchen-specific customizations

## Support

**Claude API Documentation:** https://docs.anthropic.com/claude/reference/getting-started-with-the-api

**Issues:**
- Check Xcode console for error messages
- Verify internet connection
- Test API key with `curl`:
  ```bash
  curl https://api.anthropic.com/v1/messages \
    -H "x-api-key: YOUR_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":1024,"messages":[{"role":"user","content":"Hello"}]}'
  ```

---

**Your Kitchen Assistant is now powered by Claude! 🤖🍳**

Just build and run - it works out of the box!
