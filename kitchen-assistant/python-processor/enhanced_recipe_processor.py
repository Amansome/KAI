"""
Enhanced Recipe Processor with Ollama integration.
Extends the base RecipeProcessor to use Ollama for intelligent text extraction
while maintaining fallback to existing regex-based processing.
"""

import logging
from pathlib import Path
from typing import Dict, Any, Optional, List

from process_recipes import RecipeProcessor
from ollama_client import OllamaClient, OllamaError
from ollama_config import OllamaConfig


# Configure logging
logger = logging.getLogger(__name__)


class EnhancedRecipeProcessor(RecipeProcessor):
    """
    Enhanced recipe processor with Ollama integration for intelligent extraction.
    Inherits from RecipeProcessor and adds Ollama-powered extraction capabilities.
    """
    
    def __init__(self, input_dir: str = "input", output_dir: str = "output", use_ollama: bool = True):
        """
        Initialize enhanced recipe processor
        
        Args:
            input_dir: Directory containing PDF files
            output_dir: Directory for output JSON files
            use_ollama: Whether to use Ollama for extraction (defaults to True)
        """
        super().__init__(input_dir, output_dir)
        
        self.use_ollama = use_ollama
        self.ollama_client = None
        self.ollama_config = None
        
        # Initialize Ollama if requested
        if self.use_ollama:
            self._initialize_ollama()
    
    def _initialize_ollama(self) -> None:
        """Initialize Ollama client and configuration"""
        try:
            # Load configuration
            self.ollama_config = OllamaConfig.load_from_file()
            
            if not self.ollama_config.enabled:
                logger.info("Ollama is disabled in configuration, falling back to regex processing")
                self.use_ollama = False
                return
            
            # Initialize client
            self.ollama_client = OllamaClient(
                base_url=self.ollama_config.base_url,
                timeout=self.ollama_config.timeout,
                max_retries=self.ollama_config.max_retries
            )
            
            # Check availability
            if not self.ollama_client.is_available():
                logger.warning("Ollama service is not available, falling back to regex processing")
                self.use_ollama = False
                self.ollama_client = None
                return
            
            logger.info(f"Ollama initialized successfully with model: {self.ollama_config.model}")
            
        except Exception as e:
            logger.warning(f"Failed to initialize Ollama: {e}, falling back to regex processing")
            self.use_ollama = False
            self.ollama_client = None
    
    def process_pdf(self, pdf_path: Path) -> Optional[Dict[str, Any]]:
        """
        Process a single PDF file with Ollama integration and fallback
        
        Args:
            pdf_path: Path to PDF file to process
            
        Returns:
            Extracted recipe data or None if processing fails
        """
        print(f"  📄 Processing: {pdf_path.name}")
        
        try:
            # Extract text from PDF (using parent class method)
            text = self.extract_text_from_pdf(pdf_path)
            
            if not text.strip():
                print(f"    ⚠️  Warning: No text extracted from {pdf_path.name}")
                return None
            
            # Try Ollama processing first if available
            if self.use_ollama and self.ollama_client:
                recipe = self.process_pdf_with_ollama(text, pdf_path)
                if recipe:
                    print(f"    ✅ Extracted with Ollama: {recipe['name']}")
                    print(f"       - {len(recipe['ingredients']['whole'])} ingredients")
                    print(f"       - {len(recipe['steps'])} steps")
                    return recipe
                else:
                    print(f"    ⚠️  Ollama extraction failed, falling back to regex")
            
            # Fallback to regex processing
            recipe = self.fallback_to_regex(text, pdf_path)
            if recipe:
                print(f"    ✅ Extracted with regex: {recipe['name']}")
                print(f"       - {len(recipe['ingredients']['whole'])} ingredients")
                print(f"       - {len(recipe['steps'])} steps")
                return recipe
            
            print(f"    ❌ Both Ollama and regex extraction failed")
            return None
            
        except Exception as e:
            print(f"    ❌ Error processing {pdf_path.name}: {str(e)}")
            return None
    
    def process_pdf_with_ollama(self, text: str, pdf_path: Path) -> Optional[Dict[str, Any]]:
        """
        Process PDF text using Ollama for intelligent extraction
        
        Args:
            text: Raw text extracted from PDF
            pdf_path: Path to original PDF file
            
        Returns:
            Extracted recipe data or None if extraction fails
        """
        if not self.ollama_client:
            return None
        
        try:
            # Step 1: Clean and structure the text
            cleaned_text = self.ollama_client.clean_and_structure_text(
                text, 
                model=self.ollama_config.model
            )
            
            if cleaned_text:
                text = cleaned_text
                logger.debug("Text cleaned successfully with Ollama")
            else:
                logger.debug("Text cleaning failed, using original text")
            
            # Step 2: Extract structured recipe data
            recipe_data = self.ollama_client.extract_recipe_data(
                text,
                model=self.ollama_config.model
            )
            
            if not recipe_data:
                logger.warning("Ollama failed to extract recipe data")
                return None
            
            # Step 3: Generate recipe ID and validate
            recipe_name = recipe_data.get("name", "")
            if not recipe_name:
                # Try to extract name separately if missing
                extracted_name = self.ollama_client.extract_recipe_name(
                    text,
                    model=self.ollama_config.model
                )
                if extracted_name:
                    recipe_data["name"] = extracted_name
                else:
                    # Fallback to filename-based name
                    recipe_data["name"] = self.extract_recipe_name(text, pdf_path.stem)
            
            # Generate ID from name
            recipe_data["id"] = self.generate_recipe_id(recipe_data["name"])
            
            # Validate and enhance the extracted data
            recipe_data = self._validate_and_enhance_recipe_data(recipe_data, text, pdf_path)
            
            return recipe_data
            
        except OllamaError as e:
            logger.warning(f"Ollama error during PDF processing: {e}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error during Ollama processing: {e}")
            return None
    
    def fallback_to_regex(self, text: str, pdf_path: Path) -> Optional[Dict[str, Any]]:
        """
        Fallback to regex-based extraction using parent class methods
        
        Args:
            text: Raw text extracted from PDF
            pdf_path: Path to original PDF file
            
        Returns:
            Extracted recipe data using regex patterns
        """
        try:
            # Use parent class extraction methods
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
            
            return recipe
            
        except Exception as e:
            logger.error(f"Regex fallback failed: {e}")
            return None
    
    def _validate_and_enhance_recipe_data(
        self, 
        recipe_data: Dict[str, Any], 
        original_text: str, 
        pdf_path: Path
    ) -> Dict[str, Any]:
        """
        Validate and enhance recipe data extracted by Ollama
        
        Args:
            recipe_data: Recipe data from Ollama
            original_text: Original PDF text
            pdf_path: Path to original PDF file
            
        Returns:
            Validated and enhanced recipe data
        """
        # Ensure required fields exist
        if "name" not in recipe_data or not recipe_data["name"]:
            recipe_data["name"] = self.extract_recipe_name(original_text, pdf_path.stem)
        
        if "category" not in recipe_data or not recipe_data["category"]:
            recipe_data["category"] = self.extract_category(original_text, pdf_path.name)
        
        # Validate ingredients structure
        if "ingredients" not in recipe_data:
            recipe_data["ingredients"] = {"whole": []}
        elif not isinstance(recipe_data["ingredients"], dict) or "whole" not in recipe_data["ingredients"]:
            # Convert list format to expected structure if needed
            if isinstance(recipe_data["ingredients"], list):
                recipe_data["ingredients"] = {"whole": recipe_data["ingredients"]}
            else:
                recipe_data["ingredients"] = {"whole": []}
        
        # Ensure other fields exist
        recipe_data.setdefault("steps", [])
        recipe_data.setdefault("equipment", [])
        recipe_data.setdefault("scoops", [])
        
        # Try to enhance missing equipment and scoops using regex if Ollama missed them
        if not recipe_data["equipment"]:
            recipe_data["equipment"] = self.extract_equipment(original_text)
        
        if not recipe_data["scoops"]:
            recipe_data["scoops"] = self.extract_scoops(original_text)
        
        # Validate ingredient count - if too few, try to supplement with regex
        if len(recipe_data["ingredients"]["whole"]) < 2:
            regex_ingredients = self.extract_ingredients(original_text)
            if len(regex_ingredients["whole"]) > len(recipe_data["ingredients"]["whole"]):
                logger.info("Supplementing Ollama ingredients with regex extraction")
                # Merge ingredients, preferring Ollama format but adding missing ones
                existing_names = {ing["name"].lower() for ing in recipe_data["ingredients"]["whole"]}
                for regex_ing in regex_ingredients["whole"]:
                    if regex_ing["name"].lower() not in existing_names:
                        recipe_data["ingredients"]["whole"].append(regex_ing)
        
        return recipe_data
    
    def process_multi_recipe_pdf(self, pdf_path: Path) -> List[Dict[str, Any]]:
        """
        Process a PDF that may contain multiple recipes
        
        Args:
            pdf_path: Path to PDF file to process
            
        Returns:
            List of extracted recipe data dictionaries
        """
        print(f"  📄 Processing multi-recipe PDF: {pdf_path.name}")
        
        try:
            # Extract text from PDF
            text = self.extract_text_from_pdf(pdf_path)
            
            if not text.strip():
                print(f"    ⚠️  Warning: No text extracted from {pdf_path.name}")
                return []
            
            recipes = []
            
            # Try Ollama recipe separation if available
            if self.use_ollama and self.ollama_client:
                separated_recipes = self.ollama_client.separate_recipes(
                    text,
                    model=self.ollama_config.model
                )
                
                if separated_recipes and len(separated_recipes) > 1:
                    print(f"    🔍 Found {len(separated_recipes)} recipes in PDF")
                    
                    for recipe_info in separated_recipes:
                        recipe_text = recipe_info.get("content", "")
                        if recipe_text:
                            recipe = self.process_pdf_with_ollama(recipe_text, pdf_path)
                            if recipe:
                                # Override name with separated name if available
                                if recipe_info.get("name"):
                                    recipe["name"] = recipe_info["name"]
                                    recipe["id"] = self.generate_recipe_id(recipe["name"])
                                recipes.append(recipe)
                    
                    if recipes:
                        return recipes
                    else:
                        print(f"    ⚠️  Multi-recipe separation failed, trying single recipe processing")
            
            # Fallback to single recipe processing
            single_recipe = self.process_pdf(pdf_path)
            if single_recipe:
                recipes.append(single_recipe)
            
            return recipes
            
        except Exception as e:
            print(f"    ❌ Error processing multi-recipe PDF {pdf_path.name}: {str(e)}")
            return []
    
    def get_processing_stats(self) -> Dict[str, Any]:
        """
        Get statistics about the processing session
        
        Returns:
            Dictionary with processing statistics
        """
        stats = {
            "ollama_enabled": self.use_ollama,
            "ollama_available": self.ollama_client is not None,
            "total_recipes": len(self.recipes),
            "processing_method": "ollama" if self.use_ollama else "regex"
        }
        
        if self.ollama_config:
            stats["ollama_model"] = self.ollama_config.model
            stats["ollama_base_url"] = self.ollama_config.base_url
        
        return stats
    
    def process_all_pdfs(self) -> int:
        """
        Process all PDF files in input directory with enhanced capabilities
        
        Returns:
            Number of successfully processed recipes
        """
        pdf_files = list(self.input_dir.glob("*.pdf"))
        
        if not pdf_files:
            print(f"⚠️  No PDF files found in {self.input_dir}/")
            return 0
        
        print(f"\n🔍 Found {len(pdf_files)} PDF file(s) to process")
        
        if self.use_ollama:
            print(f"🤖 Using Ollama with model: {self.ollama_config.model}")
        else:
            print("📝 Using regex-based extraction")
        
        print()
        
        successful = 0
        for pdf_path in pdf_files:
            # Check if this might be a multi-recipe PDF based on filename
            if any(keyword in pdf_path.name.lower() for keyword in ['multi', 'combined', 'collection']):
                recipes = self.process_multi_recipe_pdf(pdf_path)
                if recipes:
                    self.recipes.extend(recipes)
                    successful += len(recipes)
            else:
                recipe = self.process_pdf(pdf_path)
                if recipe:
                    self.recipes.append(recipe)
                    successful += 1
        
        return successful
    
    def save_json(self) -> None:
        """Save recipes to JSON file with enhanced metadata"""
        output_file = self.output_dir / "recipes.json"
        
        # Get processing statistics
        stats = self.get_processing_stats()
        
        output_data = {
            "recipes": self.recipes,
            "metadata": {
                "total_recipes": len(self.recipes),
                "categories": list(set(r["category"] for r in self.recipes)),
                "generated_by": "Kitchen Assistant Enhanced Recipe Processor",
                "processing_stats": stats
            }
        }
        
        with open(output_file, 'w', encoding='utf-8') as f:
            import json
            json.dump(output_data, f, indent=2, ensure_ascii=False)
        
        print(f"\n💾 Saved {len(self.recipes)} recipes to {output_file}")
        
        # Print processing summary
        if stats["ollama_enabled"]:
            print(f"🤖 Processed using Ollama model: {stats.get('ollama_model', 'unknown')}")
        else:
            print("📝 Processed using regex-based extraction")


def main():
    """Main execution function for enhanced processor"""
    print("=" * 70)
    print("🍳 KITCHEN ASSISTANT - ENHANCED RECIPE PDF PROCESSOR")
    print("=" * 70)
    
    # Initialize enhanced processor
    processor = EnhancedRecipeProcessor()
    
    # Process all PDFs
    successful = processor.process_all_pdfs()
    
    if successful > 0:
        # Save to JSON
        processor.save_json()
        
        print("\n" + "=" * 70)
        print(f"✅ SUCCESS: Processed {successful} recipe(s)")
        print("=" * 70)
        print(f"\n📱 Next steps:")
        print(f"   1. Check output/recipes.json")
        print(f"   2. Copy to iOS app: ../ios-app/KAI/Resources/")
        print(f"   3. Rebuild the app in Xcode\n")
    else:
        print("\n" + "=" * 70)
        print("❌ No recipes were successfully processed")
        print("=" * 70)
        print("\nPlease check:")
        print("  - PDF files are in the input/ folder")
        print("  - PDFs contain readable text (not scanned images)")
        print("  - PDFs are not password protected")
        print("  - Ollama service is running (if enabled)\n")


if __name__ == "__main__":
    main()