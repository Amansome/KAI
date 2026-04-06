#!/bin/bash
# Kitchen Assistant - Recipe Update Automation Script
# This script processes recipe PDFs and updates the iOS app

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo ""
echo "======================================================================"
echo "🍳 KITCHEN ASSISTANT - RECIPE UPDATE AUTOMATION"
echo "======================================================================"
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Error: Python 3 is not installed${NC}"
    echo "Please install Python 3.8 or later"
    exit 1
fi

# Check if requirements are installed
echo -e "${BLUE}🔍 Checking Python dependencies...${NC}"
cd "$SCRIPT_DIR/python-processor"

if ! python3 -c "import pdfplumber" 2>/dev/null && ! python3 -c "import PyPDF2" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  PDF libraries not found. Installing dependencies...${NC}"
    pip3 install -r requirements.txt

    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to install dependencies${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Dependencies installed${NC}"
else
    echo -e "${GREEN}✅ Dependencies already installed${NC}"
fi

# Check for PDF files
PDF_COUNT=$(ls -1 input/*.pdf 2>/dev/null | wc -l)
if [ $PDF_COUNT -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Warning: No PDF files found in python-processor/input/${NC}"
    echo "Please add recipe PDFs to the input folder and run this script again."
    exit 0
fi

echo -e "${BLUE}📚 Found $PDF_COUNT PDF file(s) to process${NC}"
echo ""

# Run the Python processor
echo -e "${BLUE}🔄 Processing recipe PDFs...${NC}"
python3 process_recipes.py

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ PDF processing complete!${NC}"

    # Check if recipes.json was created
    if [ ! -f "output/recipes.json" ]; then
        echo -e "${RED}❌ Error: recipes.json was not created${NC}"
        exit 1
    fi

    # Check if iOS app exists
    if [ -d "$SCRIPT_DIR/ios-app/KitchenAssistant" ]; then
        echo ""
        echo -e "${BLUE}📱 Copying recipes.json to iOS app...${NC}"

        # Create Resources directory if it doesn't exist
        mkdir -p "$SCRIPT_DIR/ios-app/KitchenAssistant/Resources"

        # Copy the file
        cp output/recipes.json "$SCRIPT_DIR/ios-app/KitchenAssistant/Resources/recipes.json"

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Successfully copied recipes.json to iOS app${NC}"
            echo ""
            echo -e "${GREEN}🎉 All done!${NC}"
            echo ""
            echo "Next steps:"
            echo "  1. Open the Xcode project: ios-app/KitchenAssistant.xcodeproj"
            echo "  2. Rebuild the app (⌘B)"
            echo "  3. Run on iPad simulator or device"
        else
            echo -e "${RED}❌ Failed to copy recipes.json to iOS app${NC}"
            exit 1
        fi
    else
        echo ""
        echo -e "${YELLOW}⚠️  iOS app project not found at ios-app/KitchenAssistant${NC}"
        echo ""
        echo "The recipes.json file has been generated at:"
        echo "  python-processor/output/recipes.json"
        echo ""
        echo "To set up the iOS app:"
        echo "  1. Follow the instructions in ios-app/SETUP_INSTRUCTIONS.md"
        echo "  2. After creating the Xcode project, run this script again"
        echo "  3. Or manually copy recipes.json to the app's Resources folder"
    fi
else
    echo ""
    echo -e "${RED}❌ Error processing recipes${NC}"
    echo "Please check the error messages above and try again."
    exit 1
fi

echo ""
echo "======================================================================"
