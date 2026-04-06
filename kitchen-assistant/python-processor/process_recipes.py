#!/usr/bin/env python3
"""
Recipe PDF Processor
Extracts recipe data from PDF files and converts to structured JSON format
for use in the Kitchen Assistant iOS app.
"""

import os
import json
import re
from pathlib import Path
from typing import List, Dict, Any, Optional

try:
    import pdfplumber
    PDF_LIBRARY = 'pdfplumber'
except ImportError:
    try:
        import PyPDF2
        PDF_LIBRARY = 'PyPDF2'
    except ImportError:
        print("❌ Error: Neither pdfplumber nor PyPDF2 is installed.")
        print("Please run: pip install -r requirements.txt")
        exit(1)


class RecipeProcessor:
    """Processes recipe PDFs and extracts structured data."""

    def __init__(self, input_dir: str = "input", output_dir: str = "output"):
        self.input_dir = Path(input_dir)
        self.output_dir = Path(output_dir)
        self.recipes = []

        # Ensure directories exist
        self.input_dir.mkdir(exist_ok=True)
        self.output_dir.mkdir(exist_ok=True)

    def extract_text_from_pdf(self, pdf_path: Path) -> str:
        """Extract text from PDF using available library."""
        try:
            if PDF_LIBRARY == 'pdfplumber':
                with pdfplumber.open(pdf_path) as pdf:
                    text = ""
                    for page in pdf.pages:
                        text += page.extract_text() + "\n"
                    return text
            else:  # PyPDF2
                with open(pdf_path, 'rb') as file:
                    reader = PyPDF2.PdfReader(file)
                    text = ""
                    for page in reader.pages:
                        text += page.extract_text() + "\n"
                    return text
        except Exception as e:
            raise Exception(f"Failed to extract text: {str(e)}")

    def generate_recipe_id(self, name: str) -> str:
        """Generate a URL-friendly ID from recipe name."""
        # Convert to lowercase, replace spaces and special chars with hyphens
        recipe_id = re.sub(r'[^\w\s-]', '', name.lower())
        recipe_id = re.sub(r'[-\s]+', '-', recipe_id)
        return recipe_id.strip('-')

    def extract_category(self, text: str, filename: str) -> str:
        """Determine recipe category from text or filename."""
        text_lower = text.lower()
        filename_lower = filename.lower()

        # Check for category keywords
        if any(word in text_lower or word in filename_lower
               for word in ['sandwich', 'club', 'wrap', 'panini']):
            return "sandwich"
        elif any(word in text_lower or word in filename_lower
                 for word in ['salad', 'greens']):
            return "salad"
        elif any(word in text_lower or word in filename_lower
                 for word in ['kids', 'child', 'junior']):
            return "kids"
        elif any(word in text_lower or word in filename_lower
                 for word in ['prep', 'sauce', 'dressing', 'marinade']):
            return "prep"
        else:
            return "other"

    def extract_recipe_name(self, text: str, filename: str) -> str:
        """Extract recipe name from text or use filename."""
        lines = text.split('\n')

        # Try to find a title in the first few lines
        for line in lines[:10]:
            line = line.strip()
            # Look for lines that might be titles (all caps, or specific format)
            if line and len(line) < 100:
                # Check if it looks like a title
                if line.isupper() or (line[0].isupper() and not line.endswith('.')):
                    # Avoid common non-title lines
                    if not any(word in line.lower() for word in
                              ['page', 'version', 'date', 'procedure', 'ingredients']):
                        return line.title()

        # Fallback to filename without extension
        return filename.replace('.pdf', '').replace('-', ' ').replace('_', ' ').title()

    def extract_ingredients(self, text: str) -> Dict[str, List[Dict[str, str]]]:
        """Extract ingredients from recipe text."""
        ingredients = {"whole": []}

        # Look for ingredient patterns
        # Pattern: amount unit/scoop ingredient, NOTES
        ingredient_pattern = r'([0-9./]+\s*(?:slices?|oz|cups?|tbsp|tsp|Grey scoop|Blue scoop|Yellow scoop|Purple scoop))\s+([^,\n]+)(?:,\s*([A-Z\s]+))?'

        matches = re.findall(ingredient_pattern, text, re.IGNORECASE)

        for match in matches:
            amount = match[0].strip()
            name = match[1].strip()
            notes = match[2].strip() if match[2] else ""

            ingredients["whole"].append({
                "name": name.lower(),
                "amount": amount,
                "notes": notes.lower() if notes else ""
            })

        # Also look for simple ingredient lists (lines starting with numbers or bullets)
        lines = text.split('\n')
        in_ingredient_section = False

        for line in lines:
            line = line.strip()

            # Detect ingredient section
            if 'ingredient' in line.lower():
                in_ingredient_section = True
                continue
            elif 'procedure' in line.lower() or 'steps' in line.lower():
                in_ingredient_section = False
                continue

            if in_ingredient_section and line:
                # Try to parse ingredient line
                # Format: "2 slices bacon, CRISPED"
                parts = re.match(r'^[•\-*]?\s*(.+)$', line)
                if parts and not line.startswith(('Note', 'Total', 'Portion')):
                    ingredient_text = parts.group(1)

                    # Parse amount and name
                    amount_match = re.match(r'^([0-9./]+(?:\s*[-]\s*[0-9./]+)?)\s+(.+)$', ingredient_text)
                    if amount_match:
                        amount = amount_match.group(1).strip()
                        rest = amount_match.group(2).strip()

                        # Check if there's a note after comma
                        if ',' in rest:
                            name, notes = rest.split(',', 1)
                            ingredients["whole"].append({
                                "name": name.strip().lower(),
                                "amount": amount,
                                "notes": notes.strip().lower()
                            })
                        else:
                            ingredients["whole"].append({
                                "name": rest.lower(),
                                "amount": amount,
                                "notes": ""
                            })

        return ingredients

    def extract_steps(self, text: str) -> List[str]:
        """Extract procedure steps from recipe text."""
        steps = []

        # Look for numbered steps
        step_pattern = r'^(\d+)[.)]\s+(.+)$'
        lines = text.split('\n')

        in_procedure_section = False
        current_step = None

        for line in lines:
            line = line.strip()

            # Detect procedure section
            if 'procedure' in line.lower() or 'instructions' in line.lower():
                in_procedure_section = True
                continue

            if in_procedure_section:
                # Check for numbered step
                match = re.match(step_pattern, line)
                if match:
                    # Save previous step if exists
                    if current_step:
                        steps.append(current_step.strip())

                    # Start new step
                    step_num = int(match.group(1))
                    step_text = match.group(2).strip()
                    current_step = step_text
                elif line and current_step is not None:
                    # Continue previous step (multi-line)
                    if not line.startswith(('Note:', 'IMPORTANT:', 'TIP:')):
                        current_step += " " + line
                elif not line and current_step:
                    # Empty line might end a step
                    steps.append(current_step.strip())
                    current_step = None

        # Add last step
        if current_step:
            steps.append(current_step.strip())

        return steps

    def extract_equipment(self, text: str) -> List[str]:
        """Extract equipment and tools mentioned in recipe."""
        equipment = []
        equipment_keywords = [
            'MerryChef', 'toaster', 'spatula', 'knife', 'cutting board',
            'bowl', 'pan', 'grill', 'oven', 'microwave', 'blender',
            'mixer', 'food processor', 'scale', 'thermometer'
        ]

        text_lower = text.lower()
        for item in equipment_keywords:
            if item.lower() in text_lower:
                equipment.append(item)

        return list(set(equipment))  # Remove duplicates

    def extract_scoops(self, text: str) -> List[str]:
        """Extract scoop types mentioned in recipe."""
        scoops = []
        scoop_types = ['Blue scoop', 'Yellow scoop', 'Grey scoop', 'Purple scoop', 'Red scoop']

        for scoop in scoop_types:
            if scoop.lower() in text.lower():
                scoops.append(scoop)

        return scoops

    def process_pdf(self, pdf_path: Path) -> Optional[Dict[str, Any]]:
        """Process a single PDF file and extract recipe data."""
        print(f"  📄 Processing: {pdf_path.name}")

        try:
            # Extract text from PDF
            text = self.extract_text_from_pdf(pdf_path)

            if not text.strip():
                print(f"    ⚠️  Warning: No text extracted from {pdf_path.name}")
                return None

            # Extract recipe data
            recipe_name = self.extract_recipe_name(text, pdf_path.stem)
            recipe_id = self.generate_recipe_id(recipe_name)
            category = self.extract_category(text, pdf_path.name)
            ingredients = self.extract_ingredients(text)
            steps = self.extract_steps(text)
            equipment = self.extract_equipment(text)
            scoops = self.extract_scoops(text)

            recipe = {
                "id": recipe_id,
                "name": recipe_name,
                "category": category,
                "ingredients": ingredients,
                "steps": steps,
                "equipment": equipment,
                "scoops": scoops
            }

            print(f"    ✅ Extracted: {recipe_name}")
            print(f"       - {len(ingredients['whole'])} ingredients")
            print(f"       - {len(steps)} steps")

            return recipe

        except Exception as e:
            print(f"    ❌ Error processing {pdf_path.name}: {str(e)}")
            return None

    def process_all_pdfs(self) -> int:
        """Process all PDF files in input directory."""
        pdf_files = list(self.input_dir.glob("*.pdf"))

        if not pdf_files:
            print(f"⚠️  No PDF files found in {self.input_dir}/")
            return 0

        print(f"\n🔍 Found {len(pdf_files)} PDF file(s) to process\n")

        successful = 0
        for pdf_path in pdf_files:
            recipe = self.process_pdf(pdf_path)
            if recipe:
                self.recipes.append(recipe)
                successful += 1

        return successful

    def save_json(self) -> None:
        """Save recipes to JSON file."""
        output_file = self.output_dir / "recipes.json"

        output_data = {
            "recipes": self.recipes,
            "metadata": {
                "total_recipes": len(self.recipes),
                "categories": list(set(r["category"] for r in self.recipes)),
                "generated_by": "Kitchen Assistant Recipe Processor"
            }
        }

        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, indent=2, ensure_ascii=False)

        print(f"\n💾 Saved {len(self.recipes)} recipes to {output_file}")


def main():
    """Main execution function."""
    print("=" * 60)
    print("🍳 KITCHEN ASSISTANT - RECIPE PDF PROCESSOR")
    print("=" * 60)

    processor = RecipeProcessor()

    # Process all PDFs
    successful = processor.process_all_pdfs()

    if successful > 0:
        # Save to JSON
        processor.save_json()

        print("\n" + "=" * 60)
        print(f"✅ SUCCESS: Processed {successful} recipe(s)")
        print("=" * 60)
        print(f"\n📱 Next steps:")
        print(f"   1. Check output/recipes.json")
        print(f"   2. Copy to iOS app: ../ios-app/KitchenAssistant/Resources/")
        print(f"   3. Rebuild the app in Xcode\n")
    else:
        print("\n" + "=" * 60)
        print("❌ No recipes were successfully processed")
        print("=" * 60)
        print("\nPlease check:")
        print("  - PDF files are in the input/ folder")
        print("  - PDFs contain readable text (not scanned images)")
        print("  - PDFs are not password protected\n")


if __name__ == "__main__":
    main()
