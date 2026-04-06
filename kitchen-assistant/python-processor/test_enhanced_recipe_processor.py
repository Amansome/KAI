"""
Unit tests for EnhancedRecipeProcessor.
Tests Ollama integration, fallback behavior, and enhanced processing capabilities.
"""

import json
import unittest
from unittest.mock import Mock, patch, MagicMock
from pathlib import Path
import tempfile
import shutil

from enhanced_recipe_processor import EnhancedRecipeProcessor
from ollama_client import OllamaError, ServiceUnavailableError
from ollama_config import OllamaConfig


class TestEnhancedRecipeProcessor(unittest.TestCase):
    """Test cases for EnhancedRecipeProcessor"""
    
    def setUp(self):
        """Set up test fixtures"""
        # Create temporary directories
        self.temp_dir = tempfile.mkdtemp()
        self.input_dir = Path(self.temp_dir) / "input"
        self.output_dir = Path(self.temp_dir) / "output"
        self.input_dir.mkdir()
        self.output_dir.mkdir()
        
        # Create processor with temporary directories
        self.processor = EnhancedRecipeProcessor(
            input_dir=str(self.input_dir),
            output_dir=str(self.output_dir),
            use_ollama=False  # Start with Ollama disabled for basic tests
        )
    
    def tearDown(self):
        """Clean up test fixtures"""
        shutil.rmtree(self.temp_dir)
    
    def test_init_default_values(self):
        """Test processor initialization with default values"""
        processor = EnhancedRecipeProcessor()
        self.assertEqual(processor.input_dir, Path("input"))
        self.assertEqual(processor.output_dir, Path("output"))
        self.assertTrue(processor.use_ollama)  # Default is True
    
    def test_init_custom_values(self):
        """Test processor initialization with custom values"""
        processor = EnhancedRecipeProcessor(
            input_dir="custom_input",
            output_dir="custom_output",
            use_ollama=False
        )
        self.assertEqual(processor.input_dir, Path("custom_input"))
        self.assertEqual(processor.output_dir, Path("custom_output"))
        self.assertFalse(processor.use_ollama)
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    @patch('enhanced_recipe_processor.OllamaClient')
    def test_initialize_ollama_success(self, mock_client_class, mock_config_load):
        """Test successful Ollama initialization"""
        # Mock configuration
        mock_config = Mock()
        mock_config.enabled = True
        mock_config.base_url = "http://localhost:11434"
        mock_config.timeout = 30
        mock_config.max_retries = 3
        mock_config.model = "llama3.2:3b"
        mock_config_load.return_value = mock_config
        
        # Mock client
        mock_client = Mock()
        mock_client.is_available.return_value = True
        mock_client_class.return_value = mock_client
        
        # Initialize processor with Ollama
        processor = EnhancedRecipeProcessor(use_ollama=True)
        
        self.assertTrue(processor.use_ollama)
        self.assertIsNotNone(processor.ollama_client)
        self.assertEqual(processor.ollama_config, mock_config)
        mock_client.is_available.assert_called_once()
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    def test_initialize_ollama_disabled_in_config(self, mock_config_load):
        """Test Ollama initialization when disabled in config"""
        # Mock configuration with Ollama disabled
        mock_config = Mock()
        mock_config.enabled = False
        mock_config_load.return_value = mock_config
        
        processor = EnhancedRecipeProcessor(use_ollama=True)
        
        self.assertFalse(processor.use_ollama)
        self.assertIsNone(processor.ollama_client)
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    @patch('enhanced_recipe_processor.OllamaClient')
    def test_initialize_ollama_service_unavailable(self, mock_client_class, mock_config_load):
        """Test Ollama initialization when service is unavailable"""
        # Mock configuration
        mock_config = Mock()
        mock_config.enabled = True
        mock_config_load.return_value = mock_config
        
        # Mock client that reports service unavailable
        mock_client = Mock()
        mock_client.is_available.return_value = False
        mock_client_class.return_value = mock_client
        
        processor = EnhancedRecipeProcessor(use_ollama=True)
        
        self.assertFalse(processor.use_ollama)
        self.assertIsNone(processor.ollama_client)
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    def test_initialize_ollama_config_error(self, mock_config_load):
        """Test Ollama initialization with configuration error"""
        mock_config_load.side_effect = Exception("Config error")
        
        processor = EnhancedRecipeProcessor(use_ollama=True)
        
        self.assertFalse(processor.use_ollama)
        self.assertIsNone(processor.ollama_client)
    
    def test_fallback_to_regex(self):
        """Test fallback to regex-based extraction"""
        sample_text = """
        GRILLED CHEESE SANDWICH
        
        Ingredients:
        2 slices bread
        1 slice cheese
        1 tbsp butter
        
        Procedure:
        1. Butter bread
        2. Add cheese
        3. Cook until golden
        """
        
        pdf_path = Path("test_recipe.pdf")
        result = self.processor.fallback_to_regex(sample_text, pdf_path)
        
        self.assertIsNotNone(result)
        self.assertIn("name", result)
        self.assertIn("ingredients", result)
        self.assertIn("steps", result)
        self.assertEqual(result["name"], "Grilled Cheese Sandwich")
    
    def test_fallback_to_regex_error(self):
        """Test fallback to regex with error"""
        # Mock parent class method to raise exception
        with patch.object(self.processor, 'extract_recipe_name', side_effect=Exception("Extraction error")):
            result = self.processor.fallback_to_regex("test text", Path("test.pdf"))
            self.assertIsNone(result)
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    @patch('enhanced_recipe_processor.OllamaClient')
    def test_process_pdf_with_ollama_success(self, mock_client_class, mock_config_load):
        """Test successful PDF processing with Ollama"""
        # Setup mocks
        mock_config = Mock()
        mock_config.enabled = True
        mock_config.model = "llama3.2:3b"
        mock_config_load.return_value = mock_config
        
        mock_client = Mock()
        mock_client.is_available.return_value = True
        mock_client.clean_and_structure_text.return_value = "Cleaned text"
        mock_client.extract_recipe_data.return_value = {
            "name": "Test Recipe",
            "category": "sandwich",
            "ingredients": [{"name": "bread", "amount": "2 slices", "notes": ""}],
            "steps": ["Step 1"],
            "equipment": [],
            "scoops": []
        }
        mock_client_class.return_value = mock_client
        
        # Create processor with Ollama enabled
        processor = EnhancedRecipeProcessor(use_ollama=True)
        
        sample_text = "Sample recipe text"
        pdf_path = Path("test_recipe.pdf")
        
        result = processor.process_pdf_with_ollama(sample_text, pdf_path)
        
        self.assertIsNotNone(result)
        self.assertEqual(result["name"], "Test Recipe")
        self.assertIn("id", result)
        mock_client.clean_and_structure_text.assert_called_once()
        mock_client.extract_recipe_data.assert_called_once()
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    @patch('enhanced_recipe_processor.OllamaClient')
    def test_process_pdf_with_ollama_extraction_failure(self, mock_client_class, mock_config_load):
        """Test PDF processing when Ollama extraction fails"""
        # Setup mocks
        mock_config = Mock()
        mock_config.enabled = True
        mock_config.model = "llama3.2:3b"
        mock_config_load.return_value = mock_config
        
        mock_client = Mock()
        mock_client.is_available.return_value = True
        mock_client.clean_and_structure_text.return_value = "Cleaned text"
        mock_client.extract_recipe_data.return_value = None  # Extraction fails
        mock_client_class.return_value = mock_client
        
        processor = EnhancedRecipeProcessor(use_ollama=True)
        
        result = processor.process_pdf_with_ollama("Sample text", Path("test.pdf"))
        
        self.assertIsNone(result)
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    @patch('enhanced_recipe_processor.OllamaClient')
    def test_process_pdf_with_ollama_error(self, mock_client_class, mock_config_load):
        """Test PDF processing with Ollama error"""
        # Setup mocks
        mock_config = Mock()
        mock_config.enabled = True
        mock_config_load.return_value = mock_config
        
        mock_client = Mock()
        mock_client.is_available.return_value = True
        mock_client.clean_and_structure_text.side_effect = ServiceUnavailableError("Service down")
        mock_client_class.return_value = mock_client
        
        processor = EnhancedRecipeProcessor(use_ollama=True)
        
        result = processor.process_pdf_with_ollama("Sample text", Path("test.pdf"))
        
        self.assertIsNone(result)
    
    def test_validate_and_enhance_recipe_data(self):
        """Test recipe data validation and enhancement"""
        recipe_data = {
            "name": "Test Recipe",
            "category": "sandwich",
            "ingredients": [
                {"name": "bread", "amount": "2 slices", "notes": ""}
            ],
            "steps": ["Step 1"]
        }
        
        original_text = "Test recipe with MerryChef and Blue scoop"
        pdf_path = Path("test.pdf")
        
        result = self.processor._validate_and_enhance_recipe_data(
            recipe_data, original_text, pdf_path
        )
        
        # Check that missing fields were added
        self.assertIn("equipment", result)
        self.assertIn("scoops", result)
        
        # Check that equipment and scoops were extracted from text
        self.assertIn("MerryChef", result["equipment"])
        self.assertIn("Blue scoop", result["scoops"])
    
    def test_validate_and_enhance_recipe_data_missing_name(self):
        """Test recipe data validation when name is missing"""
        recipe_data = {
            "category": "sandwich",
            "ingredients": [],
            "steps": []
        }
        
        original_text = "GRILLED CHEESE SANDWICH\n\nIngredients..."
        pdf_path = Path("grilled-cheese.pdf")
        
        result = self.processor._validate_and_enhance_recipe_data(
            recipe_data, original_text, pdf_path
        )
        
        # Name should be extracted from text or filename
        self.assertIn("name", result)
        self.assertTrue(result["name"])
    
    def test_validate_and_enhance_recipe_data_ingredient_structure(self):
        """Test recipe data validation with different ingredient structures"""
        # Test with list format ingredients
        recipe_data = {
            "name": "Test Recipe",
            "category": "sandwich",
            "ingredients": [
                {"name": "bread", "amount": "2 slices", "notes": ""}
            ],
            "steps": []
        }
        
        result = self.processor._validate_and_enhance_recipe_data(
            recipe_data, "test text", Path("test.pdf")
        )
        
        # Should convert to expected structure
        self.assertIn("ingredients", result)
        self.assertIn("whole", result["ingredients"])
        self.assertEqual(len(result["ingredients"]["whole"]), 1)
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    @patch('enhanced_recipe_processor.OllamaClient')
    def test_process_multi_recipe_pdf_success(self, mock_client_class, mock_config_load):
        """Test successful multi-recipe PDF processing"""
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
                "name": "Recipe 1",
                "start_marker": "Recipe 1:",
                "content": "Recipe 1 content"
            },
            {
                "recipe_number": 2,
                "name": "Recipe 2",
                "start_marker": "Recipe 2:",
                "content": "Recipe 2 content"
            }
        ]
        mock_client_class.return_value = mock_client
        
        processor = EnhancedRecipeProcessor(use_ollama=True)
        
        # Mock the process_pdf_with_ollama method
        with patch.object(processor, 'process_pdf_with_ollama') as mock_process:
            mock_process.return_value = {
                "name": "Test Recipe",
                "id": "test-recipe",
                "category": "sandwich",
                "ingredients": {"whole": []},
                "steps": [],
                "equipment": [],
                "scoops": []
            }
            
            # Mock extract_text_from_pdf
            with patch.object(processor, 'extract_text_from_pdf', return_value="Multi recipe text"):
                result = processor.process_multi_recipe_pdf(Path("multi_recipe.pdf"))
        
        self.assertEqual(len(result), 2)
        self.assertEqual(mock_process.call_count, 2)
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    @patch('enhanced_recipe_processor.OllamaClient')
    def test_process_multi_recipe_pdf_single_recipe_fallback(self, mock_client_class, mock_config_load):
        """Test multi-recipe PDF processing fallback to single recipe"""
        # Setup mocks
        mock_config = Mock()
        mock_config.enabled = True
        mock_config_load.return_value = mock_config
        
        mock_client = Mock()
        mock_client.is_available.return_value = True
        mock_client.separate_recipes.return_value = None  # Separation fails
        mock_client_class.return_value = mock_client
        
        processor = EnhancedRecipeProcessor(use_ollama=True)
        
        # Mock the process_pdf method
        with patch.object(processor, 'process_pdf') as mock_process:
            mock_process.return_value = {
                "name": "Single Recipe",
                "id": "single-recipe"
            }
            
            # Mock extract_text_from_pdf
            with patch.object(processor, 'extract_text_from_pdf', return_value="Single recipe text"):
                result = processor.process_multi_recipe_pdf(Path("single_recipe.pdf"))
        
        self.assertEqual(len(result), 1)
        mock_process.assert_called_once()
    
    def test_get_processing_stats_ollama_disabled(self):
        """Test processing statistics when Ollama is disabled"""
        stats = self.processor.get_processing_stats()
        
        self.assertFalse(stats["ollama_enabled"])
        self.assertFalse(stats["ollama_available"])
        self.assertEqual(stats["processing_method"], "regex")
        self.assertEqual(stats["total_recipes"], 0)
    
    @patch('enhanced_recipe_processor.OllamaConfig.load_from_file')
    @patch('enhanced_recipe_processor.OllamaClient')
    def test_get_processing_stats_ollama_enabled(self, mock_client_class, mock_config_load):
        """Test processing statistics when Ollama is enabled"""
        # Setup mocks
        mock_config = Mock()
        mock_config.enabled = True
        mock_config.model = "llama3.2:3b"
        mock_config.base_url = "http://localhost:11434"
        mock_config_load.return_value = mock_config
        
        mock_client = Mock()
        mock_client.is_available.return_value = True
        mock_client_class.return_value = mock_client
        
        processor = EnhancedRecipeProcessor(use_ollama=True)
        stats = processor.get_processing_stats()
        
        self.assertTrue(stats["ollama_enabled"])
        self.assertTrue(stats["ollama_available"])
        self.assertEqual(stats["processing_method"], "ollama")
        self.assertEqual(stats["ollama_model"], "llama3.2:3b")
        self.assertEqual(stats["ollama_base_url"], "http://localhost:11434")
    
    def test_save_json_enhanced_metadata(self):
        """Test JSON saving with enhanced metadata"""
        # Add a test recipe
        self.processor.recipes = [{
            "id": "test-recipe",
            "name": "Test Recipe",
            "category": "sandwich",
            "ingredients": {"whole": []},
            "steps": [],
            "equipment": [],
            "scoops": []
        }]
        
        self.processor.save_json()
        
        # Check that file was created
        output_file = self.output_dir / "recipes.json"
        self.assertTrue(output_file.exists())
        
        # Check content
        with open(output_file, 'r') as f:
            data = json.load(f)
        
        self.assertIn("recipes", data)
        self.assertIn("metadata", data)
        self.assertIn("processing_stats", data["metadata"])
        self.assertEqual(len(data["recipes"]), 1)
        self.assertEqual(data["metadata"]["total_recipes"], 1)
    
    def test_process_all_pdfs_no_files(self):
        """Test processing when no PDF files are found"""
        result = self.processor.process_all_pdfs()
        self.assertEqual(result, 0)
    
    def test_process_all_pdfs_with_multi_recipe_detection(self):
        """Test processing with multi-recipe PDF detection"""
        # Create test PDF files
        regular_pdf = self.input_dir / "regular_recipe.pdf"
        multi_pdf = self.input_dir / "multi_recipe_collection.pdf"
        
        # Create empty files (we'll mock the actual processing)
        regular_pdf.touch()
        multi_pdf.touch()
        
        # Mock processing methods
        with patch.object(self.processor, 'process_pdf') as mock_single:
            with patch.object(self.processor, 'process_multi_recipe_pdf') as mock_multi:
                mock_single.return_value = {"name": "Regular Recipe"}
                mock_multi.return_value = [
                    {"name": "Multi Recipe 1"},
                    {"name": "Multi Recipe 2"}
                ]
                
                result = self.processor.process_all_pdfs()
        
        # Should process regular PDF with single method and multi PDF with multi method
        mock_single.assert_called_once()
        mock_multi.assert_called_once()
        self.assertEqual(result, 3)  # 1 regular + 2 multi recipes


class TestEnhancedRecipeProcessorIntegration(unittest.TestCase):
    """Integration tests for EnhancedRecipeProcessor"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.temp_dir = tempfile.mkdtemp()
        self.input_dir = Path(self.temp_dir) / "input"
        self.output_dir = Path(self.temp_dir) / "output"
        self.input_dir.mkdir()
        self.output_dir.mkdir()
    
    def tearDown(self):
        """Clean up test fixtures"""
        shutil.rmtree(self.temp_dir)
    
    def test_full_processing_workflow_regex_only(self):
        """Test complete processing workflow with regex only"""
        processor = EnhancedRecipeProcessor(
            input_dir=str(self.input_dir),
            output_dir=str(self.output_dir),
            use_ollama=False
        )
        
        # Mock PDF text extraction
        sample_text = """
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
        
        with patch.object(processor, 'extract_text_from_pdf', return_value=sample_text):
            # Create a dummy PDF file
            test_pdf = self.input_dir / "test_recipe.pdf"
            test_pdf.touch()
            
            # Process PDFs
            result = processor.process_all_pdfs()
            
            # Should successfully process 1 recipe
            self.assertEqual(result, 1)
            self.assertEqual(len(processor.recipes), 1)
            
            # Check recipe content
            recipe = processor.recipes[0]
            self.assertEqual(recipe["name"], "Grilled Cheese Sandwich")
            self.assertEqual(recipe["category"], "sandwich")
            self.assertGreater(len(recipe["ingredients"]["whole"]), 0)
            self.assertGreater(len(recipe["steps"]), 0)
            
            # Save and verify JSON
            processor.save_json()
            output_file = self.output_dir / "recipes.json"
            self.assertTrue(output_file.exists())
            
            with open(output_file, 'r') as f:
                data = json.load(f)
            
            self.assertEqual(len(data["recipes"]), 1)
            self.assertEqual(data["metadata"]["total_recipes"], 1)
            self.assertFalse(data["metadata"]["processing_stats"]["ollama_enabled"])


if __name__ == '__main__':
    unittest.main()