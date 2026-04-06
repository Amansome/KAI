"""
Unit tests for recipe extraction prompt templates.
Tests prompt generation, validation, and JSON extraction functionality.
"""

import json
import pytest
from typing import Dict, Any, List

from recipe_prompts import (
    RecipePromptTemplates,
    PromptFormatter,
    format_recipe_extraction_prompt,
    format_ingredient_normalization_prompt,
    format_text_cleaning_prompt,
    format_recipe_name_prompt,
    format_recipe_separation_prompt
)


class TestPromptFormatter:
    """Test PromptFormatter functionality"""
    
    def test_format_prompt_success(self):
        """Test successful prompt formatting"""
        template = RecipePromptTemplates.RECIPE_EXTRACTION_TEMPLATE
        result = PromptFormatter.format_prompt(template, recipe_text="Test recipe")
        
        assert "Test recipe" in result
        assert "JSON object" in result
        assert "ingredients" in result
    
    def test_format_prompt_missing_variable(self):
        """Test prompt formatting with missing variable"""
        template = RecipePromptTemplates.RECIPE_EXTRACTION_TEMPLATE
        
        with pytest.raises(ValueError, match="Missing required template variable"):
            PromptFormatter.format_prompt(template)
    
    def test_escape_text_for_prompt(self):
        """Test text escaping for prompts"""
        # Test whitespace normalization
        text = "Multiple   spaces\n\n\nand   newlines"
        escaped = PromptFormatter.escape_text_for_prompt(text)
        assert "Multiple spaces and newlines" in escaped
        
        # Test control character removal
        text_with_control = "Normal text\x00\x08\x1F"
        escaped = PromptFormatter.escape_text_for_prompt(text_with_control)
        assert escaped == "Normal text"
        
        # Test length limiting
        long_text = "a" * 15000
        escaped = PromptFormatter.escape_text_for_prompt(long_text)
        assert len(escaped) <= 10020  # 10000 + "... [truncated]"
        assert escaped.endswith("... [truncated]")
    
    def test_extract_json_from_response_object(self):
        """Test JSON object extraction from response"""
        response = 'Here is the result: {"name": "Test Recipe", "category": "sandwich"} and some more text'
        result = PromptFormatter.extract_json_from_response(response)
        
        assert result is not None
        assert result["name"] == "Test Recipe"
        assert result["category"] == "sandwich"
    
    def test_extract_json_from_response_array(self):
        """Test JSON array extraction from response"""
        response = 'The ingredients are: [{"name": "bread", "amount": "2 slices"}] as shown above'
        result = PromptFormatter.extract_json_from_response(response)
        
        assert result is not None
        assert isinstance(result, list)
        assert len(result) == 1
        assert result[0]["name"] == "bread"
    
    def test_extract_json_from_response_no_json(self):
        """Test JSON extraction when no JSON present"""
        response = "This is just plain text with no JSON"
        result = PromptFormatter.extract_json_from_response(response)
        
        assert result is None
    
    def test_extract_json_from_response_invalid_json(self):
        """Test JSON extraction with malformed JSON"""
        response = 'Invalid JSON: {"name": "Test", "invalid": } more text'
        result = PromptFormatter.extract_json_from_response(response)
        
        assert result is None
    
    def test_validate_json_response_valid_object(self):
        """Test JSON validation with valid object"""
        schema = RecipePromptTemplates.RECIPE_EXTRACTION_TEMPLATE.validation_schema
        response = json.dumps({
            "name": "Test Recipe",
            "category": "sandwich",
            "ingredients": [{"name": "bread", "amount": "2 slices", "notes": ""}],
            "steps": ["Step 1"],
            "equipment": ["knife"],
            "scoops": []
        })
        
        assert PromptFormatter.validate_json_response(response, schema)
    
    def test_validate_json_response_missing_required_field(self):
        """Test JSON validation with missing required field"""
        schema = RecipePromptTemplates.RECIPE_EXTRACTION_TEMPLATE.validation_schema
        response = json.dumps({
            "name": "Test Recipe",
            "category": "sandwich"
            # Missing required fields
        })
        
        assert not PromptFormatter.validate_json_response(response, schema)
    
    def test_validate_json_response_valid_array(self):
        """Test JSON validation with valid array"""
        schema = RecipePromptTemplates.INGREDIENT_NORMALIZATION_TEMPLATE.validation_schema
        response = json.dumps([
            {"name": "bread", "amount": "2 slices", "notes": ""},
            {"name": "butter", "amount": "1 tbsp", "notes": "room temperature"}
        ])
        
        assert PromptFormatter.validate_json_response(response, schema)
    
    def test_create_ingredient_list_text(self):
        """Test ingredient list formatting"""
        ingredients = ["2 slices bread", "1 tbsp butter", "1 slice cheese"]
        result = PromptFormatter.create_ingredient_list_text(ingredients)
        
        expected = "- 2 slices bread\n- 1 tbsp butter\n- 1 slice cheese"
        assert result == expected


class TestRecipeExtractionPrompt:
    """Test recipe extraction prompt formatting"""
    
    def test_format_recipe_extraction_prompt(self):
        """Test recipe extraction prompt formatting"""
        recipe_text = "Grilled Cheese Sandwich\n\nIngredients:\n2 slices bread\n1 slice cheese"
        prompt = format_recipe_extraction_prompt(recipe_text)
        
        assert "Grilled Cheese Sandwich" in prompt
        assert "2 slices bread" in prompt
        assert "JSON object" in prompt
        assert "sandwich|salad|kids|prep|other" in prompt
    
    def test_format_recipe_extraction_prompt_with_special_chars(self):
        """Test recipe extraction with special characters"""
        recipe_text = "Recipe with special chars: café, naïve, résumé"
        prompt = format_recipe_extraction_prompt(recipe_text)
        
        assert "café" in prompt
        assert "naïve" in prompt
        assert "résumé" in prompt
    
    def test_format_recipe_extraction_prompt_long_text(self):
        """Test recipe extraction with very long text"""
        recipe_text = "Long recipe text " * 1000  # Very long text
        prompt = format_recipe_extraction_prompt(recipe_text)
        
        # Should be truncated
        assert len(prompt) < len(recipe_text) + 1000
        assert "truncated" in prompt


class TestIngredientNormalizationPrompt:
    """Test ingredient normalization prompt formatting"""
    
    def test_format_ingredient_normalization_prompt(self):
        """Test ingredient normalization prompt formatting"""
        ingredients = ["2 slice bread", "half cup milk", "1 egg beaten"]
        prompt = format_ingredient_normalization_prompt(ingredients)
        
        assert "- 2 slice bread" in prompt
        assert "- half cup milk" in prompt
        assert "- 1 egg beaten" in prompt
        assert "JSON array" in prompt
        assert "standardized amount" in prompt
    
    def test_format_ingredient_normalization_prompt_empty_list(self):
        """Test ingredient normalization with empty list"""
        ingredients = []
        prompt = format_ingredient_normalization_prompt(ingredients)
        
        assert "JSON array" in prompt
        # Should not crash with empty list


class TestTextCleaningPrompt:
    """Test text cleaning prompt formatting"""
    
    def test_format_text_cleaning_prompt(self):
        """Test text cleaning prompt formatting"""
        raw_text = "Messy    text\n\n\nwith   extra\nspaces"
        prompt = format_text_cleaning_prompt(raw_text)
        
        assert "Messy text with extra spaces" in prompt
        assert "Clean and structure" in prompt
        assert "formatting artifacts" in prompt
    
    def test_format_text_cleaning_prompt_with_control_chars(self):
        """Test text cleaning with control characters"""
        raw_text = "Text with\x00control\x08chars\x1F"
        prompt = format_text_cleaning_prompt(raw_text)
        
        assert "Text withcontrolchars" in prompt
        # Control characters should be removed


class TestRecipeNamePrompt:
    """Test recipe name extraction prompt formatting"""
    
    def test_format_recipe_name_prompt(self):
        """Test recipe name prompt formatting"""
        text = "GRILLED CHEESE SANDWICH\n\nThis is a delicious recipe..."
        prompt = format_recipe_name_prompt(text)
        
        assert "GRILLED CHEESE SANDWICH" in prompt
        assert "Extract the recipe name" in prompt
        assert "Title Case" in prompt


class TestRecipeSeparationPrompt:
    """Test recipe separation prompt formatting"""
    
    def test_format_recipe_separation_prompt(self):
        """Test recipe separation prompt formatting"""
        text = "Recipe 1: Grilled Cheese\n\nRecipe 2: BLT Sandwich"
        prompt = format_recipe_separation_prompt(text)
        
        assert "Recipe 1: Grilled Cheese" in prompt
        assert "Recipe 2: BLT Sandwich" in prompt
        assert "multiple recipes" in prompt
        assert "JSON array" in prompt


class TestPromptTemplateValidation:
    """Test prompt template validation schemas"""
    
    def test_recipe_extraction_schema(self):
        """Test recipe extraction validation schema"""
        template = RecipePromptTemplates.RECIPE_EXTRACTION_TEMPLATE
        schema = template.validation_schema
        
        assert schema["type"] == "object"
        assert "name" in schema["required"]
        assert "category" in schema["required"]
        assert "ingredients" in schema["required"]
        
        # Test category enum
        category_enum = schema["properties"]["category"]["enum"]
        assert "sandwich" in category_enum
        assert "salad" in category_enum
        assert "kids" in category_enum
        assert "prep" in category_enum
        assert "other" in category_enum
    
    def test_ingredient_normalization_schema(self):
        """Test ingredient normalization validation schema"""
        template = RecipePromptTemplates.INGREDIENT_NORMALIZATION_TEMPLATE
        schema = template.validation_schema
        
        assert schema["type"] == "array"
        item_schema = schema["items"]
        assert "name" in item_schema["required"]
        assert "amount" in item_schema["required"]
        assert "notes" in item_schema["required"]
    
    def test_recipe_separation_schema(self):
        """Test recipe separation validation schema"""
        template = RecipePromptTemplates.RECIPE_SEPARATION_TEMPLATE
        schema = template.validation_schema
        
        assert schema["type"] == "array"
        assert schema["minItems"] == 1
        item_schema = schema["items"]
        assert "recipe_number" in item_schema["required"]
        assert "name" in item_schema["required"]
        assert "start_marker" in item_schema["required"]
        assert "content" in item_schema["required"]


class TestPromptTemplateIntegration:
    """Integration tests for prompt templates"""
    
    def test_full_recipe_extraction_workflow(self):
        """Test complete recipe extraction workflow"""
        # Sample recipe text
        recipe_text = """
        GRILLED CHEESE SANDWICH
        
        Ingredients:
        2 slices bread
        1 slice American cheese
        1 tbsp butter
        
        Procedure:
        1. Butter one side of each bread slice
        2. Place cheese between bread slices
        3. Cook in pan until golden brown
        """
        
        # Format prompt
        prompt = format_recipe_extraction_prompt(recipe_text)
        
        # Verify prompt contains all necessary elements
        assert "GRILLED CHEESE SANDWICH" in prompt
        assert "2 slices bread" in prompt
        assert "JSON object" in prompt
        
        # Test that we can validate a proper response
        mock_response = {
            "name": "Grilled Cheese Sandwich",
            "category": "sandwich",
            "ingredients": [
                {"name": "bread", "amount": "2 slices", "notes": ""},
                {"name": "american cheese", "amount": "1 slice", "notes": ""},
                {"name": "butter", "amount": "1 tbsp", "notes": ""}
            ],
            "steps": [
                "Butter one side of each bread slice",
                "Place cheese between bread slices",
                "Cook in pan until golden brown"
            ],
            "equipment": ["pan"],
            "scoops": []
        }
        
        schema = RecipePromptTemplates.RECIPE_EXTRACTION_TEMPLATE.validation_schema
        response_json = json.dumps(mock_response)
        assert PromptFormatter.validate_json_response(response_json, schema)
    
    def test_ingredient_normalization_workflow(self):
        """Test ingredient normalization workflow"""
        ingredients = [
            "2 slice bread",
            "half cup milk", 
            "1 egg, beaten",
            "salt to taste"
        ]
        
        prompt = format_ingredient_normalization_prompt(ingredients)
        
        # Verify all ingredients are in prompt
        for ingredient in ingredients:
            assert ingredient in prompt
        
        # Test validation of normalized response
        mock_response = [
            {"name": "bread", "amount": "2 slices", "notes": ""},
            {"name": "milk", "amount": "1/2 cup", "notes": ""},
            {"name": "egg", "amount": "1", "notes": "beaten"},
            {"name": "salt", "amount": "to taste", "notes": ""}
        ]
        
        schema = RecipePromptTemplates.INGREDIENT_NORMALIZATION_TEMPLATE.validation_schema
        response_json = json.dumps(mock_response)
        assert PromptFormatter.validate_json_response(response_json, schema)


if __name__ == "__main__":
    # Run tests if script is executed directly
    pytest.main([__file__, "-v"])