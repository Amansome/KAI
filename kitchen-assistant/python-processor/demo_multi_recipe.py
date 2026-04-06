#!/usr/bin/env python3
"""
Demo script for multi-recipe PDF processing functionality.
Shows how the enhanced processor handles PDFs with multiple recipes.
"""

import json
from pathlib import Path
from enhanced_recipe_processor import EnhancedRecipeProcessor
from recipe_prompts import format_recipe_separation_prompt, PromptFormatter


def demo_recipe_separation_prompt():
    """Demonstrate recipe separation prompt generation"""
    print("=" * 60)
    print("DEMO: Recipe Separation Prompt Generation")
    print("=" * 60)
    
    # Sample multi-recipe text
    multi_recipe_text = """
    RECIPE COLLECTION - SANDWICHES
    
    Recipe 1: Classic Grilled Cheese
    
    Ingredients:
    - 2 slices white bread
    - 1 slice American cheese
    - 1 tbsp butter
    - Salt to taste
    
    Procedure:
    1. Butter one side of each bread slice
    2. Place cheese between unbuttered sides
    3. Cook in pan over medium heat until golden
    4. Flip and cook other side
    5. Serve hot
    
    Equipment: Pan, spatula
    
    ---
    
    Recipe 2: BLT Sandwich
    
    Ingredients:
    - 2 slices sourdough bread
    - 3 strips bacon
    - 2 leaves lettuce
    - 2 slices tomato
    - 1 tbsp mayonnaise
    
    Procedure:
    1. Cook bacon until crispy
    2. Toast bread slices
    3. Spread mayo on one slice
    4. Layer lettuce, tomato, and bacon
    5. Top with second slice
    6. Cut diagonally and serve
    
    Equipment: Pan, toaster
    
    ---
    
    Recipe 3: Club Sandwich
    
    Ingredients:
    - 3 slices white bread
    - 2 slices turkey
    - 2 strips bacon
    - 1 leaf lettuce
    - 2 slices tomato
    - 1 tbsp mayo
    
    Procedure:
    1. Toast bread slices
    2. Cook bacon until crispy
    3. Spread mayo on bread
    4. Layer turkey, bacon, lettuce, tomato
    5. Stack with toothpicks
    6. Cut into quarters
    
    Equipment: Toaster, pan
    """
    
    # Generate separation prompt
    prompt = format_recipe_separation_prompt(multi_recipe_text)
    
    print(f"📝 Generated separation prompt ({len(prompt)} characters)")
    print("\nPrompt preview:")
    print("-" * 40)
    print(prompt[:300] + "..." if len(prompt) > 300 else prompt)
    print("-" * 40)
    
    return multi_recipe_text


def demo_response_parsing():
    """Demonstrate parsing of recipe separation response"""
    print("\n" + "=" * 60)
    print("DEMO: Recipe Separation Response Parsing")
    print("=" * 60)
    
    # Mock response from Ollama
    mock_response = """
    I found 3 recipes in this document. Here they are separated:
    
    [
        {
            "recipe_number": 1,
            "name": "Classic Grilled Cheese",
            "start_marker": "Recipe 1: Classic Grilled Cheese",
            "content": "Recipe 1: Classic Grilled Cheese\\n\\nIngredients:\\n- 2 slices white bread\\n- 1 slice American cheese\\n- 1 tbsp butter\\n- Salt to taste\\n\\nProcedure:\\n1. Butter one side of each bread slice\\n2. Place cheese between unbuttered sides\\n3. Cook in pan over medium heat until golden\\n4. Flip and cook other side\\n5. Serve hot\\n\\nEquipment: Pan, spatula"
        },
        {
            "recipe_number": 2,
            "name": "BLT Sandwich",
            "start_marker": "Recipe 2: BLT Sandwich",
            "content": "Recipe 2: BLT Sandwich\\n\\nIngredients:\\n- 2 slices sourdough bread\\n- 3 strips bacon\\n- 2 leaves lettuce\\n- 2 slices tomato\\n- 1 tbsp mayonnaise\\n\\nProcedure:\\n1. Cook bacon until crispy\\n2. Toast bread slices\\n3. Spread mayo on one slice\\n4. Layer lettuce, tomato, and bacon\\n5. Top with second slice\\n6. Cut diagonally and serve\\n\\nEquipment: Pan, toaster"
        },
        {
            "recipe_number": 3,
            "name": "Club Sandwich",
            "start_marker": "Recipe 3: Club Sandwich",
            "content": "Recipe 3: Club Sandwich\\n\\nIngredients:\\n- 3 slices white bread\\n- 2 slices turkey\\n- 2 strips bacon\\n- 1 leaf lettuce\\n- 2 slices tomato\\n- 1 tbsp mayo\\n\\nProcedure:\\n1. Toast bread slices\\n2. Cook bacon until crispy\\n3. Spread mayo on bread\\n4. Layer turkey, bacon, lettuce, tomato\\n5. Stack with toothpicks\\n6. Cut into quarters\\n\\nEquipment: Toaster, pan"
        }
    ]
    
    These recipes are now ready for individual processing.
    """
    
    # Parse the response
    extracted_recipes = PromptFormatter.extract_json_from_response(mock_response)
    
    if extracted_recipes:
        print(f"✅ Successfully parsed {len(extracted_recipes)} recipes:")
        
        for recipe in extracted_recipes:
            print(f"\n📄 Recipe {recipe['recipe_number']}: {recipe['name']}")
            print(f"   Start marker: {recipe['start_marker']}")
            print(f"   Content length: {len(recipe['content'])} characters")
            
            # Show content preview
            content_preview = recipe['content'][:100].replace('\\n', ' ')
            print(f"   Content preview: {content_preview}...")
    else:
        print("❌ Failed to parse recipes from response")
    
    return extracted_recipes


def demo_multi_recipe_processing():
    """Demonstrate multi-recipe processing workflow"""
    print("\n" + "=" * 60)
    print("DEMO: Multi-Recipe Processing Workflow")
    print("=" * 60)
    
    # Create processor (without Ollama for demo)
    processor = EnhancedRecipeProcessor(use_ollama=False)
    
    # Simulate multi-recipe PDF processing
    print("🔍 Simulating multi-recipe PDF processing...")
    
    # Sample filenames and their detection
    test_files = [
        "grilled_cheese.pdf",
        "multi_recipe_collection.pdf",
        "combined_sandwiches.pdf",
        "recipe_collection.pdf",
        "single_blt.pdf"
    ]
    
    multi_keywords = ['multi', 'combined', 'collection']
    
    print("\n📁 File processing decisions:")
    for filename in test_files:
        is_multi = any(keyword in filename.lower() for keyword in multi_keywords)
        processing_type = "Multi-recipe" if is_multi else "Single recipe"
        print(f"   {filename:<25} → {processing_type} processing")
    
    # Show processing stats
    stats = processor.get_processing_stats()
    print(f"\n📊 Processing configuration:")
    print(f"   Ollama enabled: {stats['ollama_enabled']}")
    print(f"   Ollama available: {stats['ollama_available']}")
    print(f"   Processing method: {stats['processing_method']}")
    print(f"   Total recipes processed: {stats['total_recipes']}")


def demo_validation_and_enhancement():
    """Demonstrate recipe validation and enhancement"""
    print("\n" + "=" * 60)
    print("DEMO: Recipe Validation and Enhancement")
    print("=" * 60)
    
    # Sample recipe data that needs validation/enhancement
    raw_recipe_data = {
        "name": "Grilled Cheese",
        "category": "sandwich",
        "ingredients": [
            {"name": "BREAD", "amount": " 2 slices ", "notes": " WHITE BREAD "},
            {"name": "cheese", "amount": "1 slice", "notes": "american"}
        ],
        "steps": [
            " Butter the bread ",
            "",  # Empty step
            " Cook until golden ",
            "   Serve hot   "
        ]
        # Missing equipment and scoops
    }
    
    print("📝 Raw recipe data:")
    print(json.dumps(raw_recipe_data, indent=2))
    
    # Create processor and simulate validation
    processor = EnhancedRecipeProcessor(use_ollama=False)
    
    # Simulate the validation process
    enhanced_data = processor._validate_and_enhance_recipe_data(
        raw_recipe_data,
        "Original text with MerryChef and Blue scoop mentioned",
        Path("grilled_cheese.pdf")
    )
    
    print("\n✅ Enhanced recipe data:")
    print(json.dumps(enhanced_data, indent=2))
    
    print("\n🔧 Enhancements applied:")
    print("   - Ingredient names converted to lowercase")
    print("   - Amounts and notes trimmed")
    print("   - Empty steps removed")
    print("   - Steps trimmed")
    print("   - Equipment extracted from original text")
    print("   - Scoops extracted from original text")
    print("   - Ingredients structure standardized")


def main():
    """Run all demos"""
    print("🍳 KITCHEN ASSISTANT - MULTI-RECIPE PROCESSING DEMO")
    print("=" * 70)
    
    try:
        # Demo 1: Prompt generation
        multi_recipe_text = demo_recipe_separation_prompt()
        
        # Demo 2: Response parsing
        extracted_recipes = demo_response_parsing()
        
        # Demo 3: Processing workflow
        demo_multi_recipe_processing()
        
        # Demo 4: Validation and enhancement
        demo_validation_and_enhancement()
        
        print("\n" + "=" * 70)
        print("✅ ALL DEMOS COMPLETED SUCCESSFULLY")
        print("=" * 70)
        
        print("\n🎯 Key Features Demonstrated:")
        print("   ✓ Multi-recipe separation prompt generation")
        print("   ✓ JSON response parsing and validation")
        print("   ✓ Filename-based multi-recipe detection")
        print("   ✓ Recipe data validation and enhancement")
        print("   ✓ Graceful fallback to single-recipe processing")
        
        print("\n📚 Next Steps:")
        print("   1. Test with real Ollama service")
        print("   2. Process actual multi-recipe PDFs")
        print("   3. Validate extraction accuracy")
        print("   4. Fine-tune prompts based on results")
        
    except Exception as e:
        print(f"\n❌ Demo failed with error: {e}")
        raise


if __name__ == "__main__":
    main()