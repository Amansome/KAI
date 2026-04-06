"""
Recipe extraction prompt templates for Ollama integration.
Provides structured prompts for extracting recipe data from PDF text.
"""

import json
import re
from typing import Dict, List, Any, Optional
from dataclasses import dataclass


@dataclass
class PromptTemplate:
    """Template for generating prompts with validation"""
    template: str
    required_fields: List[str]
    validation_schema: Dict[str, Any]


class RecipePromptTemplates:
    """Collection of prompt templates for recipe extraction"""
    
    # Base recipe extraction template
    RECIPE_EXTRACTION_TEMPLATE = PromptTemplate(
        template="""You are a recipe extraction assistant. Extract structured data from the following recipe text.

Return a JSON object with this exact structure:
{{
  "name": "Recipe Name",
  "category": "sandwich|salad|kids|prep|other",
  "ingredients": [
    {{
      "name": "ingredient name (lowercase)",
      "amount": "standardized amount (e.g., '2 slices', '1/4 cup')",
      "notes": "preparation notes (lowercase)"
    }}
  ],
  "steps": [
    "Step 1 description",
    "Step 2 description"
  ],
  "equipment": ["tool1", "tool2"],
  "scoops": ["Blue scoop", "Yellow scoop"]
}}

Important guidelines:
- Extract ALL ingredients mentioned in the text
- Standardize amounts (e.g., "1/2 cup" not "half cup")
- Include preparation notes (e.g., "diced", "cooked", "room temperature")
- List equipment and tools mentioned
- Identify any colored scoops mentioned (Blue, Yellow, Grey, Purple, Red)
- Steps should be clear and actionable
- Category should be one of: sandwich, salad, kids, prep, other

Recipe text:
{recipe_text}""",
        required_fields=["name", "category", "ingredients", "steps", "equipment", "scoops"],
        validation_schema={
            "type": "object",
            "required": ["name", "category", "ingredients", "steps", "equipment", "scoops"],
            "properties": {
                "name": {"type": "string", "minLength": 1},
                "category": {"type": "string", "enum": ["sandwich", "salad", "kids", "prep", "other"]},
                "ingredients": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "required": ["name", "amount", "notes"],
                        "properties": {
                            "name": {"type": "string", "minLength": 1},
                            "amount": {"type": "string", "minLength": 1},
                            "notes": {"type": "string"}
                        }
                    }
                },
                "steps": {
                    "type": "array",
                    "items": {"type": "string", "minLength": 1}
                },
                "equipment": {
                    "type": "array",
                    "items": {"type": "string"}
                },
                "scoops": {
                    "type": "array",
                    "items": {"type": "string"}
                }
            }
        }
    )
    
    # Ingredient normalization template
    INGREDIENT_NORMALIZATION_TEMPLATE = PromptTemplate(
        template="""Normalize these ingredients to a consistent format. Extract the ingredient name, amount, and any preparation notes.

Guidelines:
- Standardize amounts (e.g., "2 slices" not "2 slice", "1/4 cup" not "quarter cup")
- Convert ingredient names to lowercase
- Extract preparation notes (e.g., "diced", "cooked", "room temperature")
- If no amount is specified, use "as needed"
- If no notes, use empty string

Ingredients:
{ingredients_text}

Return a JSON array with this format:
[
  {{
    "name": "ingredient name (lowercase)",
    "amount": "standardized amount",
    "notes": "preparation notes (lowercase)"
  }}
]""",
        required_fields=["name", "amount", "notes"],
        validation_schema={
            "type": "array",
            "items": {
                "type": "object",
                "required": ["name", "amount", "notes"],
                "properties": {
                    "name": {"type": "string", "minLength": 1},
                    "amount": {"type": "string", "minLength": 1},
                    "notes": {"type": "string"}
                }
            }
        }
    )
    
    # Text cleaning template
    TEXT_CLEANING_TEMPLATE = PromptTemplate(
        template="""Clean and structure this raw text from a recipe PDF. Remove formatting artifacts, fix line breaks, and organize the content logically.

Tasks:
- Remove extra whitespace and line breaks
- Fix broken words split across lines
- Organize content into logical sections (ingredients, steps, etc.)
- Remove page numbers, headers, footers
- Keep all recipe information intact
- Make text more readable while preserving meaning

Raw text:
{raw_text}

Return the cleaned and structured text:""",
        required_fields=[],
        validation_schema={"type": "string", "minLength": 1}
    )
    
    # Recipe name extraction template
    RECIPE_NAME_TEMPLATE = PromptTemplate(
        template="""Extract the recipe name from this text. Look for the main title or dish name.

Guidelines:
- Return only the recipe name, nothing else
- Use proper capitalization (Title Case)
- Remove any extra formatting or symbols
- If multiple names are present, choose the most prominent one

Text:
{text}

Recipe name:""",
        required_fields=[],
        validation_schema={"type": "string", "minLength": 1, "maxLength": 100}
    )
    
    # Multi-recipe separation template
    RECIPE_SEPARATION_TEMPLATE = PromptTemplate(
        template="""This text may contain multiple recipes. Identify and separate them.

Return a JSON array where each element contains:
- "recipe_number": Sequential number (1, 2, 3...)
- "name": Recipe name
- "start_marker": Text that indicates where this recipe starts
- "content": The full text content for this recipe

If only one recipe is found, return an array with one element.

Text:
{text}

Return format:
[
  {{
    "recipe_number": 1,
    "name": "Recipe Name",
    "start_marker": "text that marks the start",
    "content": "full recipe text content"
  }}
]""",
        required_fields=["recipe_number", "name", "start_marker", "content"],
        validation_schema={
            "type": "array",
            "minItems": 1,
            "items": {
                "type": "object",
                "required": ["recipe_number", "name", "start_marker", "content"],
                "properties": {
                    "recipe_number": {"type": "integer", "minimum": 1},
                    "name": {"type": "string", "minLength": 1},
                    "start_marker": {"type": "string", "minLength": 1},
                    "content": {"type": "string", "minLength": 1}
                }
            }
        }
    )


class PromptFormatter:
    """Handles prompt formatting and validation"""
    
    @staticmethod
    def format_prompt(template: PromptTemplate, **kwargs) -> str:
        """
        Format a prompt template with provided variables
        
        Args:
            template: PromptTemplate to format
            **kwargs: Variables to substitute in template
            
        Returns:
            Formatted prompt string
            
        Raises:
            ValueError: If required variables are missing
        """
        try:
            # Escape any curly braces that aren't template variables
            formatted_prompt = template.template.format(**kwargs)
            return formatted_prompt
        except KeyError as e:
            raise ValueError(f"Missing required template variable: {e}")
    
    @staticmethod
    def escape_text_for_prompt(text: str) -> str:
        """
        Escape text to prevent prompt injection and formatting issues
        
        Args:
            text: Text to escape
            
        Returns:
            Escaped text safe for use in prompts
        """
        # Remove or escape potentially problematic characters
        # Replace multiple whitespace with single space
        text = re.sub(r'\s+', ' ', text)
        
        # Remove control characters except newlines and tabs
        text = re.sub(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '', text)
        
        # Limit length to prevent extremely long prompts
        if len(text) > 10000:
            text = text[:10000] + "... [truncated]"
        
        return text.strip()
    
    @staticmethod
    def validate_json_response(response: str, schema: Dict[str, Any]) -> bool:
        """
        Validate JSON response against schema
        
        Args:
            response: JSON response string
            schema: JSON schema to validate against
            
        Returns:
            True if valid, False otherwise
        """
        try:
            # Extract JSON from response
            json_data = PromptFormatter.extract_json_from_response(response)
            if json_data is None:
                return False
            
            # Basic validation - check required fields exist
            if schema.get("type") == "object":
                required_fields = schema.get("required", [])
                if not all(field in json_data for field in required_fields):
                    return False
            elif schema.get("type") == "array":
                if not isinstance(json_data, list):
                    return False
                if len(json_data) < schema.get("minItems", 0):
                    return False
            
            return True
            
        except (json.JSONDecodeError, TypeError, AttributeError):
            return False
    
    @staticmethod
    def extract_json_from_response(response: str) -> Optional[Dict[str, Any]]:
        """
        Extract JSON object or array from LLM response
        
        Args:
            response: Raw response from LLM
            
        Returns:
            Parsed JSON data or None if extraction fails
        """
        try:
            # Look for JSON object
            start_obj = response.find('{')
            end_obj = response.rfind('}') + 1
            
            # Look for JSON array
            start_arr = response.find('[')
            end_arr = response.rfind(']') + 1
            
            # Choose the first valid JSON structure found
            json_str = None
            if start_obj != -1 and end_obj > start_obj:
                if start_arr == -1 or start_obj < start_arr:
                    json_str = response[start_obj:end_obj]
            
            if json_str is None and start_arr != -1 and end_arr > start_arr:
                json_str = response[start_arr:end_arr]
            
            if json_str is None:
                return None
            
            return json.loads(json_str)
            
        except (json.JSONDecodeError, ValueError):
            return None
    
    @staticmethod
    def create_ingredient_list_text(ingredients: List[str]) -> str:
        """
        Format ingredient list for prompt templates
        
        Args:
            ingredients: List of ingredient strings
            
        Returns:
            Formatted ingredient text
        """
        return "\n".join(f"- {ingredient}" for ingredient in ingredients)


# Convenience functions for common prompt operations
def format_recipe_extraction_prompt(recipe_text: str) -> str:
    """Format recipe extraction prompt with escaped text"""
    escaped_text = PromptFormatter.escape_text_for_prompt(recipe_text)
    return PromptFormatter.format_prompt(
        RecipePromptTemplates.RECIPE_EXTRACTION_TEMPLATE,
        recipe_text=escaped_text
    )


def format_ingredient_normalization_prompt(ingredients: List[str]) -> str:
    """Format ingredient normalization prompt"""
    ingredients_text = PromptFormatter.create_ingredient_list_text(ingredients)
    return PromptFormatter.format_prompt(
        RecipePromptTemplates.INGREDIENT_NORMALIZATION_TEMPLATE,
        ingredients_text=ingredients_text
    )


def format_text_cleaning_prompt(raw_text: str) -> str:
    """Format text cleaning prompt with escaped text"""
    escaped_text = PromptFormatter.escape_text_for_prompt(raw_text)
    return PromptFormatter.format_prompt(
        RecipePromptTemplates.TEXT_CLEANING_TEMPLATE,
        raw_text=escaped_text
    )


def format_recipe_name_prompt(text: str) -> str:
    """Format recipe name extraction prompt"""
    escaped_text = PromptFormatter.escape_text_for_prompt(text)
    return PromptFormatter.format_prompt(
        RecipePromptTemplates.RECIPE_NAME_TEMPLATE,
        text=escaped_text
    )


def format_recipe_separation_prompt(text: str) -> str:
    """Format recipe separation prompt"""
    escaped_text = PromptFormatter.escape_text_for_prompt(text)
    return PromptFormatter.format_prompt(
        RecipePromptTemplates.RECIPE_SEPARATION_TEMPLATE,
        text=escaped_text
    )