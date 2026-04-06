# Kitchen Assistant

A voice-activated kitchen assistant app for restaurant employees that works offline on iPad. Employees can ask questions like "How many slices of bacon go in McAlister's Club?" and get spoken answers instantly.

## 🎯 Project Overview

This project consists of two main components:

1. **Python Recipe Processor** - Extracts recipe data from PDF files and converts to structured JSON
2. **iOS App** - SwiftUI iPad app with voice recognition and text-to-speech for hands-free recipe assistance

## 📁 Project Structure

```
kitchen-assistant/
├── python-processor/          # Python PDF processing tools
│   ├── process_recipes.py     # Main processing script
│   ├── requirements.txt       # Python dependencies
│   ├── input/                 # Put recipe PDFs here
│   └── output/                # Generated recipes.json
├── ios-app/                   # iOS application
│   ├── SETUP_INSTRUCTIONS.md  # Xcode project setup guide
│   └── CODE_STRUCTURE.md      # Swift code implementation guide
├── update_recipes.sh          # Automation script
└── README.md                  # This file
```

## 🚀 Quick Start

### Prerequisites

- **Mac** running macOS 13.0 or later
- **Python 3.8+** installed
- **Xcode 14.0+** for iOS development
- **iPad** running iOS 16.0+ (for deployment)

### Installation

1. **Clone or download this project**

2. **Install Python dependencies:**
   ```bash
   cd python-processor
   pip3 install -r requirements.txt
   ```

3. **Add your recipe PDFs:**
   - Place recipe PDF files in `python-processor/input/`

4. **Process the PDFs:**
   ```bash
   python3 process_recipes.py
   ```

   This will generate `output/recipes.json`

5. **Set up the iOS app:**
   - Follow the detailed instructions in `ios-app/SETUP_INSTRUCTIONS.md`
   - Implement the Swift code as described in `ios-app/CODE_STRUCTURE.md`

## 🔄 Workflow

### Adding New Recipes

When you have new recipe PDFs to add:

1. **Add PDFs** to `python-processor/input/` folder

2. **Run the automation script:**
   ```bash
   ./update_recipes.sh
   ```

   Or manually:
   ```bash
   cd python-processor
   python3 process_recipes.py
   cp output/recipes.json ../ios-app/KitchenAssistant/Resources/recipes.json
   ```

3. **Rebuild the iOS app** in Xcode (⌘B)

4. **Deploy** to your iPads

## 📄 Python Recipe Processor

### What It Does

The Python processor (`process_recipes.py`) extracts structured data from recipe PDF files:

- **Recipe name** and ID
- **Category** (sandwich, salad, kids, prep)
- **Ingredients** with amounts and notes
- **Procedure steps** in order
- **Equipment** needed (MerryChef, toaster, scoops, etc.)

### PDF Format Expected

The processor works best with PDFs that contain:

- Clear recipe title
- Ingredients section with measurements
- Numbered procedure steps
- Text (not scanned images)

### Output Format

Creates `recipes.json` with this structure:

```json
{
  "recipes": [
    {
      "id": "mcalisters-club",
      "name": "McAlister's Club",
      "category": "sandwich",
      "ingredients": {
        "whole": [
          {
            "name": "sliced wheat",
            "amount": "3 slices",
            "notes": "toasted"
          }
        ]
      },
      "steps": [
        "Toast the sliced wheat on the toaster",
        "Using a rubber spatula, spread mayonnaise..."
      ],
      "equipment": ["toaster", "rubber spatula"],
      "scoops": ["Blue scoop", "Yellow scoop"]
    }
  ]
}
```

### Usage

```bash
cd python-processor

# Process all PDFs in input folder
python3 process_recipes.py

# Output will be in output/recipes.json
```

## 📱 iOS App

### Features

- ✅ **Voice Recognition** - Tap and ask questions hands-free
- ✅ **Text-to-Speech** - Spoken answers
- ✅ **Offline Operation** - No internet required
- ✅ **Natural Language** - Ask questions naturally
- ✅ **Recipe Search** - Find recipes by name or ingredient
- ✅ **Conversation History** - Review past questions

### Supported Questions

The app can answer questions like:

| Question Type | Example |
|---------------|---------|
| Ingredient quantity | "How many slices of bacon go in McAlister's Club?" |
| Ingredients list | "What do I need to make the club sandwich?" |
| Recipe steps | "How do I make the club?" |
| Recipes by ingredient | "What recipes have bacon?" |
| Recipe info | "Tell me about the McAlister's Club" |
| Category recipes | "What sandwich recipes do we have?" |

### Setup

Detailed setup instructions are in `ios-app/SETUP_INSTRUCTIONS.md`, including:

- Creating the Xcode project
- Setting up permissions
- Adding recipes.json as a resource
- Building and deploying

### Implementation

Full Swift code is provided in `ios-app/CODE_STRUCTURE.md`:

- **RecipeModel.swift** - Data structures matching JSON
- **RecipeManager.swift** - Load and search recipes
- **VoiceManager.swift** - Speech recognition and TTS
- **QueryProcessor.swift** - Natural language processing
- **ContentView.swift** - Main UI with mic button
- Additional views for recipe list, details, settings

## 🛠️ Customization

### Adding New Query Patterns

Edit `QueryProcessor.swift` to add new question patterns:

```swift
// Add new pattern in handleXxxQuery methods
let patterns = [
    #"your regex pattern here"#
]
```

### Adjusting Speech Settings

In the iOS app Settings view, users can adjust:

- Speech rate (speed)
- Volume
- Voice selection

### Categories

To add new recipe categories, update:

1. **Python**: `extract_category()` in `process_recipes.py`
2. **iOS**: `categoryDisplayName` in `RecipeModel.swift`

## 📋 Troubleshooting

### Python Issues

**"No PDF files found"**
- Check that PDFs are in `python-processor/input/`
- Ensure files have `.pdf` extension

**"No text extracted from PDF"**
- PDF might be scanned images (use OCR first)
- PDF might be password protected
- Try opening PDF in Preview to verify it's readable

**Import errors**
- Run `pip3 install -r requirements.txt`
- Make sure Python 3.8+ is installed: `python3 --version`

### iOS Issues

**"recipes.json not found"**
- Verify file is in Xcode project Resources folder
- Check Target Membership includes KitchenAssistant
- Rebuild project (⌘B)

**Speech recognition not working**
- Check permissions in Settings > Privacy > Speech Recognition
- Test on physical iPad (simulator has limitations)
- Ensure microphone permission granted

**App crashes on launch**
- Check recipes.json is valid JSON
- Verify all Swift files compile without errors
- Clean build folder (⇧⌘K) and rebuild

**Voice recognition inaccurate**
- Reduce background noise
- Speak clearly and at normal pace
- Adjust microphone position on iPad
- Add common misheard phrases to QueryProcessor patterns

## 🔐 Permissions Required (iOS)

The app requires these permissions:

- **Microphone** - To hear voice questions
- **Speech Recognition** - To convert speech to text

These are requested on first launch. Users must grant them in Settings if denied.

## 📊 Example Workflow

### Typical Restaurant Setup

1. **Initial Setup** (one-time):
   - Collect all recipe PDFs
   - Process them with Python script
   - Set up iOS app in Xcode
   - Deploy to restaurant iPads

2. **Daily Use**:
   - Employees ask questions while cooking
   - App provides instant spoken answers
   - No need to touch iPad with messy hands

3. **Adding New Recipes**:
   - Add new PDF to input folder
   - Run `./update_recipes.sh`
   - Update app on iPads

## 🎨 Future Enhancements

Potential improvements:

- [ ] Add recipe images
- [ ] Voice-activated next/previous step navigation
- [ ] Timer integration ("Set timer for 5 minutes")
- [ ] Multiple language support
- [ ] Recipe scaling ("Double this recipe")
- [ ] Ingredient substitutions
- [ ] Favorites/bookmarks
- [ ] Usage analytics (most asked questions)
- [ ] Cloud sync for recipe updates
- [ ] Support for allergy information

## 📝 Technical Details

### Python Libraries Used

- **pdfplumber** - Primary PDF text extraction (preferred)
- **PyPDF2** - Fallback PDF reading library

### iOS Frameworks Used

- **SwiftUI** - Modern UI framework
- **Speech** - Speech recognition (SFSpeechRecognizer)
- **AVFoundation** - Text-to-speech (AVSpeechSynthesizer)
- **Foundation** - JSON parsing and data handling

### Requirements

| Component | Minimum Version |
|-----------|----------------|
| Python | 3.8 |
| macOS | 13.0 |
| Xcode | 14.0 |
| iOS | 16.0 |
| iPad | Any model with microphone |

## 🤝 Contributing

To contribute improvements:

1. Test thoroughly with real recipe PDFs
2. Ensure code follows existing patterns
3. Update documentation
4. Add error handling for edge cases

## 📄 License

This project is provided as-is for restaurant use. Modify and distribute as needed.

## 💡 Tips for Best Results

### Recipe PDFs

- Use text-based PDFs (not scanned images)
- Keep consistent formatting across recipes
- Include clear section headers (Ingredients, Procedure)
- Number all steps sequentially

### Voice Recognition

- Mount iPad at comfortable height
- Position away from loud equipment
- Keep screen clean for easy tapping
- Train employees on clear pronunciation

### Maintenance

- Review conversation logs to find common questions
- Add new query patterns based on usage
- Update recipes when menu changes
- Keep backup of recipes.json

## 📞 Support

For issues with:

- **Python processing**: Check PDF format and Python version
- **iOS app**: Review Xcode console logs and permissions
- **Voice recognition**: Test with simple questions first

## 🎓 Learning Resources

- [Python PDF Processing](https://pypdf2.readthedocs.io/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Speech Framework Guide](https://developer.apple.com/documentation/speech)
- [Regular Expressions in Swift](https://nshipster.com/swift-regular-expressions/)

---

**Built for restaurant efficiency. Powered by voice. 🍳**
