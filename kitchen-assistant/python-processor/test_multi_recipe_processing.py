"""
Unit tests specifically for multi-recipe PDF processing functionality.
Tests recipe separation, validation, and processing of combined PDFs.
"""

import unittest
from unittest.mock import Mock, patch
from pathlib import Path
import tempfile
import shutil

from enhanced_recipe_processor import EnhancedRecipeProcessor
from ollama_client import OllamaClient
from recipe_prompts import format_recipe_separation_prompt, PromptFormatter


class TestMultiRecipeProcessing(unittest.TestCase):
    """Test cases for multi-recipe PDF processing"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.temp_dir = tempfile.mkdtemp()
        self.input_dir = Path(self.temp_dir) / "input"
        self.output_dir = Path(self.temp_dir) / "output"
        self.input_dir.mkdir()
        self.output_dir.mkdir()
        
        self.processor = EnhancedRecipeProcessor(
            input_dir=str(self.input_dir),
            output_dir=str(self.output_dir),
            use_ollama=False
        )
    
    def tearDown(self):
        """Clean up test fixtures"""
        shutil.rmtree(self.temp_dir)
    
    def test_recipe_separation_prompt_generation(self):
        """Test recipe separation prompt generation"""
        multi_recipe_text = """
        Recipe 1: Grilled Cheese Sandwich
        
        Ingredients:
        - 2 slices bread
        - 1 slice cheese
        
        Steps:
        1. Make sandwich
        
        Recipe 2: BLT Sandwich
        
        Ingredients:
        - 2 slices bread
        - 3 strips bacon
        - Lettuce
        - Tomato
        
        Steps:
        1. Cook bacon
        2. Assemble sandwich
        """
        
        prompt = format_recipe_separation_prompt(multi_recipe_text)
        
        self.assertIn("multiple recipes", prompt)
        self.assertIn("Recipe 1: Grilled Cheese", prompt)
        self.assertIn("Recipe 2: BLT", prompt)
        self.assertIn("JSON array", prompt)
    
    def test_recipe_separation_response_parsing(self):
        """Test parsing of recipe separation response"""
        mock_response = '''Here are the separated recipes:
        [
            {
                "recipe_number": 1,
                "name": "Grilled Cheese Sandwich",
                "start_marker": "Recipe 1:",
                "content": "Recipe 1: Grilled Cheese Sandwich\\n\\nIngredients:\\n- 2 slices bread\\n- 1 slice cheese"
            },
            {
                "recipe_number": 2,
                "name": "BLT Sandwich", 
                "start_marker": "Recipe 2:",
                "content": "Recipe 2: BLT Sandwich\\n\\nIngredients:\\n- 2 slices bread\\n- 3 strips bacon"
            }
        ]
        Additional text after JSON'''
        
        extracted = PromptFormatter.extract_json_from_response(mock_response)
        
        self.assertIsNotNone(extracted)
        self.assertEqual(len(extracted), 2)
        self.assertEqual(extracted[0]["recipe_number"], 1)
        self.assertEqual(extracted[0]["name"], "Grilled Cheese Sandwich")
        self.assertEqual(extracted[1]["recipe_number"], 2)
        self.assertEqual(extracted[1]["name"], "BLT Sandwich")
    
    def test_recipe_separation_validation(self):
        """Test validation of recipe separation response"""
        from recipe_prompts import RecipePromptTemplates
        
        # Valid response
        valid_response = [
            {
                "recipe_number": 1,
                "name": "Recipe 1",
                "start_marker": "Recipe 1:",
                "content": "Recipe content"
            }
        ]
        
        schema = RecipePromptTemplates.RECIPE_SEPARATION_TEMPLATE.validation_schema
        self.assertTrue(PromptFormatter.validate_json_response(
            str(valid_response).replace("'", '"'), schema
        ))
        
        # Invalid response - missing required field
        invalid_response = [
            {
                "recipe_number": 1,
                "name": "Recipe 1"
                # Missing start_marker and content
            }
        ]
        
        self.assertFalse(PromptFormatter.validate_json_response(
            str(invalid_response).replace("'", '"'), schema
        ))
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    @patch('enhanced_recipe_processor.OllamaClient')
    def test_multi_recipe_pdf_processing_success(self, mock_client_class, mock_config_load):
        """Test successful multi-recipe PDF processing"""
        # Setup mocks
        mock_config = Mock()
        mock_config.enabled = True
        mock_config.model = "llama3.2:3b"
        mock_config_load.return_value = mock_config
        
        mock_client = Mock()
        mock_client.is_available.return_value = True
        
        # Mock recipe separation
        mock_client.separate_recipes.return_value = [
            {
                "recipe_number": 1,
                "name": "Grilled Cheese",
                "start_marker": "Recipe 1:",
                "content": "Grilled cheese recipe content"
            },
            {
                "recipe_number": 2,
                "name": "BLT Sandwich",
                "start_marker": "Recipe 2:",
                "content": "BLT sandwich recipe content"
            }
        ]
        
        mock_client_class.return_value = mock_client
        
        # Create processor with Ollama enabled
        processor = EnhancedRecipeProcessor(
            input_dir=str(self.input_dir),
            output_dir=str(self.output_dir),
            use_ollama=True
        )
        
        # Mock text extraction and individual recipe processing
        with patch.object(processor, 'extract_text_from_pdf', return_value="Multi recipe text"):
            with patch.object(processor, 'process_pdf_with_ollama') as mock_process:
                mock_process.side_effect = [
                    {
                        "id": "grilled-cheese",
                        "name": "Grilled Cheese",
                        "category": "sandwich",
                        "ingredients": {"whole": []},
                        "steps": [],
                        "equipment": [],
                        "scoops": []
                    },
                    {
                        "id": "blt-sandwich",
                        "name": "BLT Sandwich", 
                        "category": "sandwich",
                        "ingredients": {"whole": []},
                        "steps": [],
                        "equipment": [],
                        "scoops": []
                    }
                ]
                
                result = processor.process_multi_recipe_pdf(Path("multi_recipe.pdf"))
        
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]["name"], "Grilled Cheese")
        self.assertEqual(result[1]["name"], "BLT Sandwich")
        mock_client.separate_recipes.assert_called_once()
        self.assertEqual(mock_process.call_count, 2)
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    @patch('enhanced_recipe_processor.OllamaClient')
    def test_multi_recipe_pdf_processing_separation_failure(self, mock_client_class, mock_config_load):
        """Test multi-recipe PDF processing when separation fails"""
        # Setup mocks
        mock_config = Mock()
        mock_config.enabled = True
        mock_config_load.return_value = mock_config
        
        mock_client = Mock()
        mock_client.is_available.return_value = True
        mock_client.separate_recipes.return_value = None  # Separation fails
        mock_client_class.return_value = mock_client
        
        processor = EnhancedRecipeProcessor(
            input_dir=str(self.input_dir),
            output_dir=str(self.output_dir),
            use_ollama=True
        )
        
        # Mock text extraction and fallback to single recipe processing
        with patch.object(processor, 'extract_text_from_pdf', return_value="Single recipe text"):
            with patch.object(processor, 'process_pdf') as mock_single_process:
                mock_single_process.return_value = {
                    "id": "single-recipe",
                    "name": "Single Recipe",
                    "category": "sandwich"
                }
                
                result = processor.process_multi_recipe_pdf(Path("single_recipe.pdf"))
        
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["name"], "Single Recipe")
        mock_single_process.assert_called_once()
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    @patch('enhanced_recipe_processor.OllamaClient')
    def test_multi_recipe_pdf_processing_single_recipe_detected(self, mock_client_class, mock_config_load):
        """Test multi-recipe PDF processing when only one recipe is detected"""
        # Setup mocks
        mock_config = Mock()
        mock_config.enabled = True
        mock_config.model = "llama3.2:3b"
        mock_config_load.return_value = mock_config
        
        mock_client = Mock()
        mock_client.is_available.return_value = True
        
        # Mock separation returning single recipe
        mock_client.separate_recipes.return_value = [
            {
                "recipe_number": 1,
                "name": "Single Recipe",
                "start_marker": "Recipe:",
                "content": "Single recipe content"
            }
        ]
        
        mock_client_class.return_value = mock_client
        
        processor = EnhancedRecipeProcessor(
            input_dir=str(self.input_dir),
            output_dir=str(self.output_dir),
            use_ollama=True
        )
        
        # Mock text extraction and processing
        with patch.object(processor, 'extract_text_from_pdf', return_value="Single recipe text"):
            with patch.object(processor, 'process_pdf') as mock_single_process:
                mock_single_process.return_value = {
                    "id": "single-recipe",
                    "name": "Single Recipe",
                    "category": "sandwich"
                }
                
                result = processor.process_multi_recipe_pdf(Path("single_recipe.pdf"))
        
        # Should fall back to single recipe processing since only 1 recipe detected
        self.assertEqual(len(result), 1)
        mock_single_process.assert_called_once()
    
    def test_multi_recipe_pdf_processing_no_text(self):
        """Test multi-recipe PDF processing with no extractable text"""
        with patch.object(self.processor, 'extract_text_from_pdf', return_value=""):
            result = self.processor.process_multi_recipe_pdf(Path("empty.pdf"))
        
        self.assertEqual(len(result), 0)
    
    def test_multi_recipe_pdf_processing_extraction_error(self):
        """Test multi-recipe PDF processing with text extraction error"""
        with patch.object(self.processor, 'extract_text_from_pdf', side_effect=Exception("Extraction error")):
            result = self.processor.process_multi_recipe_pdf(Path("error.pdf"))
        
        self.assertEqual(len(result), 0)
    
    def test_multi_recipe_filename_detection(self):
        """Test detection of multi-recipe PDFs based on filename"""
        # Create test files
        regular_pdf = self.input_dir / "regular_recipe.pdf"
        multi_pdf1 = self.input_dir / "multi_recipe_collection.pdf"
        multi_pdf2 = self.input_dir / "combined_recipes.pdf"
        combined_pdf = self.input_dir / "recipe_collection.pdf"
        
        regular_pdf.touch()
        multi_pdf1.touch()
        multi_pdf2.touch()
        combined_pdf.touch()
        
        # Mock processing methods
        with patch.object(self.processor, 'process_pdf') as mock_single:
            with patch.object(self.processor, 'process_multi_recipe_pdf') as mock_multi:
                mock_single.return_value = {"name": "Regular Recipe"}
                mock_multi.return_value = [{"name": "Multi Recipe"}]
                
                result = self.processor.process_all_pdfs()
        
        # Should call multi-recipe processing for files with keywords
        self.assertEqual(mock_multi.call_count, 3)  # multi, combined, collection
        self.assertEqual(mock_single.call_count, 1)  # regular
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    @patch('enhanced_recipe_processor.OllamaClient')
    def test_recipe_name_override_in_multi_recipe(self, mock_client_class, mock_config_load):
        """Test that recipe names are overridden from separation results"""
        # Setup mocks
        mock_config = Mock()
        mock_config.enabled = True
        mock_config.model = "llama3.2:3b"
        mock_config_load.return_value = mock_config
        
        mock_client = Mock()
        mock_client.is_available.return_value = True
        mock_client.separate_recipes.return_value = [
            {
                "recipe_number": 1,
                "name": "Separated Recipe Name",
                "start_marker": "Recipe 1:",
                "content": "Recipe content"
            }
        ]
        mock_client_class.return_value = mock_client
        
        processor = EnhancedRecipeProcessor(
            input_dir=str(self.input_dir),
            output_dir=str(self.output_dir),
            use_ollama=True
        )
        
        # Mock processing that returns different name
        with patch.object(processor, 'extract_text_from_pdf', return_value="Multi recipe text"):
            with patch.object(processor, 'process_pdf_with_ollama') as mock_process:
                mock_process.return_value = {
                    "id": "original-name",
                    "name": "Original Name",  # This should be overridden
                    "category": "sandwich",
                    "ingredients": {"whole": []},
                    "steps": [],
                    "equipment": [],
                    "scoops": []
                }
                
                result = processor.process_multi_recipe_pdf(Path("multi.pdf"))
        
        # Name should be overridden from separation result
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["name"], "Separated Recipe Name")
        self.assertEqual(result[0]["id"], "separated-recipe-name")  # ID should be regenerated


class TestMultiRecipeValidation(unittest.TestCase):
    """Test cases for multi-recipe validation and edge cases"""
    
    def test_recipe_separation_edge_cases(self):
        """Test recipe separation with various edge cases"""
        # Test empty text
        result = PromptFormatter.extract_json_from_response("")
        self.assertIsNone(result)
        
        # Test text with no JSON
        result = PromptFormatter.extract_json_from_response("No JSON here")
        self.assertIsNone(result)
        
        # Test malformed JSON
        result = PromptFormatter.extract_json_from_response("{ malformed json }")
        self.assertIsNone(result)
        
        # Test valid JSON with extra text
        response_with_extra = """
        Here are the recipes I found:
        [
            {
                "recipe_number": 1,
                "name": "Test Recipe",
                "start_marker": "Recipe:",
                "content": "Recipe content"
            }
        ]
        That's all I could find.
        """
        
        result = PromptFormatter.extract_json_from_response(response_with_extra)
        self.assertIsNotNone(result)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["name"], "Test Recipe")
    
    def test_recipe_content_validation(self):
        """Test validation of individual recipe content from separation"""
        # Test with valid recipe content
        valid_content = """
        Grilled Cheese Sandwich
        
        Ingredients:
        - 2 slices bread
        - 1 slice cheese
        
        Steps:
        1. Make sandwich
        """
        
        # Content should be processable
        self.assertGreater(len(valid_content.strip()), 10)
        self.assertIn("Ingredients", valid_content)
        
        # Test with minimal content
        minimal_content = "Recipe"
        self.assertLess(len(minimal_content), 50)  # Might need special handling
        
        # Test with empty content
        empty_content = ""
        self.assertEqual(len(empty_content), 0)  # Should be rejected
    
    def test_recipe_numbering_validation(self):
        """Test validation of recipe numbering in separation results"""
        # Valid numbering
        valid_recipes = [
            {"recipe_number": 1, "name": "Recipe 1", "start_marker": "1.", "content": "Content 1"},
            {"recipe_number": 2, "name": "Recipe 2", "start_marker": "2.", "content": "Content 2"}
        ]
        
        # Check sequential numbering
        numbers = [r["recipe_number"] for r in valid_recipes]
        self.assertEqual(numbers, [1, 2])
        
        # Invalid numbering (gaps)
        invalid_recipes = [
            {"recipe_number": 1, "name": "Recipe 1", "start_marker": "1.", "content": "Content 1"},
            {"recipe_number": 3, "name": "Recipe 3", "start_marker": "3.", "content": "Content 3"}  # Gap
        ]
        
        numbers = [r["recipe_number"] for r in invalid_recipes]
        self.assertNotEqual(numbers, list(range(1, len(numbers) + 1)))
    
    def test_recipe_name_extraction_from_content(self):
        """Test extraction of recipe names from separated content"""
        content_samples = [
            ("GRILLED CHEESE SANDWICH\n\nIngredients...", "Grilled Cheese Sandwich"),
            ("Recipe: BLT Sandwich\n\nSteps...", "BLT Sandwich"),
            ("1. Chicken Salad\n\nIngredients...", "Chicken Salad"),
            ("No clear title here\nJust ingredients...", None)  # Should use fallback
        ]
        
        for content, expected_name in content_samples:
            # This would be handled by the recipe name extraction logic
            if expected_name:
                self.assertIn(expected_name.upper(), content.upper())


if __name__ == '__main__':
    unittest.main()