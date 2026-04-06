"""
Unit tests for Ollama client
"""

import json
import unittest
from unittest.mock import Mock, patch, MagicMock
import requests
from requests.exceptions import ConnectionError, Timeout, RequestException

from ollama_client import (
    OllamaClient, 
    OllamaError, 
    ServiceUnavailableError, 
    ModelNotFoundError, 
    TimeoutError, 
    InvalidResponseError
)


class TestOllamaClient(unittest.TestCase):
    """Test cases for OllamaClient"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.client = OllamaClient()
        self.mock_session = Mock()
        self.client.session = self.mock_session
    
    def test_init_default_values(self):
        """Test client initialization with default values"""
        client = OllamaClient()
        self.assertEqual(client.base_url, "http://localhost:11434")
        self.assertEqual(client.timeout, 30)
        self.assertEqual(client.max_retries, 3)
    
    def test_init_custom_values(self):
        """Test client initialization with custom values"""
        client = OllamaClient(
            base_url="http://custom:8080/",
            timeout=60,
            max_retries=5
        )
        self.assertEqual(client.base_url, "http://custom:8080")
        self.assertEqual(client.timeout, 60)
        self.assertEqual(client.max_retries, 5)
    
    def test_is_available_success(self):
        """Test successful availability check"""
        mock_response = Mock()
        mock_response.status_code = 200
        self.mock_session.get.return_value = mock_response
        
        result = self.client.is_available()
        
        self.assertTrue(result)
        self.mock_session.get.assert_called_once_with(
            "http://localhost:11434/api/tags",
            timeout=5
        )
    
    def test_is_available_failure(self):
        """Test availability check when service is down"""
        self.mock_session.get.side_effect = ConnectionError()
        
        result = self.client.is_available()
        
        self.assertFalse(result)
    
    def test_is_available_non_200_status(self):
        """Test availability check with non-200 status"""
        mock_response = Mock()
        mock_response.status_code = 500
        self.mock_session.get.return_value = mock_response
        
        result = self.client.is_available()
        
        self.assertFalse(result)
    
    def test_get_models_success(self):
        """Test successful model retrieval"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "models": [
                {"name": "llama3.2:3b"},
                {"name": "llama3.2:1b"}
            ]
        }
        mock_response.raise_for_status.return_value = None
        self.mock_session.get.return_value = mock_response
        
        models = self.client.get_models()
        
        self.assertEqual(models, ["llama3.2:3b", "llama3.2:1b"])
    
    def test_get_models_connection_error(self):
        """Test model retrieval with connection error"""
        self.mock_session.get.side_effect = ConnectionError()
        
        with self.assertRaises(ServiceUnavailableError):
            self.client.get_models()
    
    def test_get_models_timeout(self):
        """Test model retrieval with timeout"""
        self.mock_session.get.side_effect = Timeout()
        
        with self.assertRaises(TimeoutError):
            self.client.get_models()
    
    def test_get_models_invalid_json(self):
        """Test model retrieval with invalid JSON response"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.side_effect = json.JSONDecodeError("Invalid JSON", "", 0)
        mock_response.raise_for_status.return_value = None
        self.mock_session.get.return_value = mock_response
        
        with self.assertRaises(InvalidResponseError):
            self.client.get_models()
    
    def test_get_models_missing_models_field(self):
        """Test model retrieval with missing models field"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"invalid": "response"}
        mock_response.raise_for_status.return_value = None
        self.mock_session.get.return_value = mock_response
        
        with self.assertRaises(InvalidResponseError):
            self.client.get_models()
    
    @patch('time.sleep')
    def test_make_request_with_retry_success_after_retry(self, mock_sleep):
        """Test successful request after retry"""
        # First call fails, second succeeds
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.raise_for_status.return_value = None
        
        self.mock_session.request.side_effect = [
            ConnectionError("Connection failed"),
            mock_response
        ]
        
        result = self.client._make_request_with_retry("GET", "http://test.com")
        
        self.assertEqual(result, mock_response)
        self.assertEqual(self.mock_session.request.call_count, 2)
        mock_sleep.assert_called_once_with(1)  # 2^0 = 1
    
    @patch('time.sleep')
    def test_make_request_with_retry_all_fail(self, mock_sleep):
        """Test request failure after all retries"""
        self.mock_session.request.side_effect = ConnectionError("Connection failed")
        
        with self.assertRaises(ServiceUnavailableError):
            self.client._make_request_with_retry("GET", "http://test.com")
        
        self.assertEqual(self.mock_session.request.call_count, 3)  # max_retries
        self.assertEqual(mock_sleep.call_count, 2)  # retries - 1
    
    def test_make_request_with_retry_timeout(self):
        """Test request timeout (no retry)"""
        self.mock_session.request.side_effect = Timeout()
        
        with self.assertRaises(TimeoutError):
            self.client._make_request_with_retry("GET", "http://test.com")
        
        self.assertEqual(self.mock_session.request.call_count, 1)  # No retry on timeout
    
    def test_chat_completion_success(self):
        """Test successful chat completion"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "message": {"content": "Test response"}
        }
        mock_response.raise_for_status.return_value = None
        self.mock_session.request.return_value = mock_response
        
        messages = [{"role": "user", "content": "Test message"}]
        result = self.client.chat_completion("llama3.2:3b", messages)
        
        self.assertEqual(result, {"message": {"content": "Test response"}})
        
        # Verify request payload
        call_args = self.mock_session.request.call_args
        self.assertEqual(call_args[0], ("POST", "http://localhost:11434/api/chat"))
        payload = call_args[1]["json"]
        self.assertEqual(payload["model"], "llama3.2:3b")
        self.assertEqual(payload["messages"], messages)
        self.assertFalse(payload["stream"])
    
    def test_chat_completion_invalid_response(self):
        """Test chat completion with invalid response format"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"invalid": "response"}
        mock_response.raise_for_status.return_value = None
        self.mock_session.request.return_value = mock_response
        
        messages = [{"role": "user", "content": "Test message"}]
        
        with self.assertRaises(InvalidResponseError):
            self.client.chat_completion("llama3.2:3b", messages)
    
    def test_chat_completion_service_unavailable(self):
        """Test chat completion with service unavailable"""
        with patch.object(self.client, '_make_request_with_retry', side_effect=ServiceUnavailableError("Service down")):
            messages = [{"role": "user", "content": "Test message"}]
            
            with self.assertRaises(ServiceUnavailableError):
                self.client.chat_completion("llama3.2:3b", messages)
    
    def test_extract_recipe_data_success(self):
        """Test successful recipe data extraction"""
        mock_response = {
            "message": {
                "content": '''Here's the extracted data:
                {
                    "name": "Test Recipe",
                    "category": "sandwich",
                    "ingredients": [
                        {
                            "name": "bread",
                            "amount": "2 slices",
                            "notes": "toasted"
                        }
                    ],
                    "steps": ["Toast bread", "Serve"],
                    "equipment": ["toaster"],
                    "scoops": []
                }'''
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.extract_recipe_data("Test recipe text")
        
        self.assertIsNotNone(result)
        self.assertEqual(result["name"], "Test Recipe")
        self.assertEqual(result["category"], "sandwich")
        self.assertEqual(len(result["ingredients"]), 1)
    
    def test_extract_recipe_data_no_json(self):
        """Test recipe extraction with no JSON in response"""
        mock_response = {
            "message": {
                "content": "No JSON here, just text"
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.extract_recipe_data("Test recipe text")
        
        self.assertIsNone(result)
    
    def test_extract_recipe_data_invalid_json(self):
        """Test recipe extraction with invalid JSON"""
        mock_response = {
            "message": {
                "content": "{ invalid json }"
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.extract_recipe_data("Test recipe text")
        
        self.assertIsNone(result)
    
    def test_extract_recipe_data_ollama_error(self):
        """Test recipe extraction with Ollama error"""
        with patch.object(self.client, 'chat_completion', side_effect=ServiceUnavailableError("Service down")):
            result = self.client.extract_recipe_data("Test recipe text")
        
        self.assertIsNone(result)
    
    def test_normalize_ingredients_success(self):
        """Test successful ingredient normalization"""
        mock_response = {
            "message": {
                "content": '''[
                    {
                        "name": "bread",
                        "amount": "2 slices",
                        "notes": "white bread"
                    }
                ]'''
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.normalize_ingredients(["2 slices white bread"])
        
        self.assertIsNotNone(result)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["name"], "bread")
    
    def test_clean_and_structure_text_success(self):
        """Test successful text cleaning"""
        mock_response = {
            "message": {
                "content": "Cleaned and structured text"
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.clean_and_structure_text("Raw messy text")
        
        self.assertEqual(result, "Cleaned and structured text")
    
    def test_clean_and_structure_text_error(self):
        """Test text cleaning with error"""
        with patch.object(self.client, 'chat_completion', side_effect=ServiceUnavailableError("Service down")):
            result = self.client.clean_and_structure_text("Raw messy text")
        
        self.assertIsNone(result)


class TestEnhancedExtractionMethods(unittest.TestCase):
    """Test cases for enhanced extraction methods"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.client = OllamaClient()
        self.mock_session = Mock()
        self.client.session = self.mock_session
    
    def test_extract_recipe_data_enhanced_success(self):
        """Test enhanced recipe data extraction with validation"""
        mock_response = {
            "message": {
                "content": '''Here's the extracted data:
                {
                    "name": "Grilled Cheese Sandwich",
                    "category": "sandwich",
                    "ingredients": [
                        {
                            "name": "bread",
                            "amount": "2 slices",
                            "notes": "white bread"
                        },
                        {
                            "name": "cheese",
                            "amount": "1 slice",
                            "notes": "american"
                        }
                    ],
                    "steps": [
                        "Heat pan over medium heat",
                        "Butter bread slices",
                        "Place cheese between bread",
                        "Cook until golden brown"
                    ],
                    "equipment": ["pan", "spatula"],
                    "scoops": []
                }
                Additional text after JSON'''
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.extract_recipe_data("Test recipe text")
        
        self.assertIsNotNone(result)
        self.assertEqual(result["name"], "Grilled Cheese Sandwich")
        self.assertEqual(result["category"], "sandwich")
        
        # Check ingredients structure
        self.assertIn("ingredients", result)
        self.assertIn("whole", result["ingredients"])
        self.assertEqual(len(result["ingredients"]["whole"]), 2)
        
        # Check ingredient processing
        bread_ingredient = result["ingredients"]["whole"][0]
        self.assertEqual(bread_ingredient["name"], "bread")
        self.assertEqual(bread_ingredient["amount"], "2 slices")
        self.assertEqual(bread_ingredient["notes"], "white bread")
        
        # Check steps
        self.assertEqual(len(result["steps"]), 4)
        self.assertIn("Heat pan over medium heat", result["steps"])
    
    def test_extract_recipe_data_invalid_category(self):
        """Test recipe extraction with invalid category gets corrected"""
        mock_response = {
            "message": {
                "content": '''{
                    "name": "Test Recipe",
                    "category": "invalid_category",
                    "ingredients": [],
                    "steps": [],
                    "equipment": [],
                    "scoops": []
                }'''
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.extract_recipe_data("Test recipe text")
        
        self.assertIsNotNone(result)
        self.assertEqual(result["category"], "other")  # Should be corrected to "other"
    
    def test_extract_recipe_data_schema_validation_failure(self):
        """Test recipe extraction with schema validation failure"""
        mock_response = {
            "message": {
                "content": '''{
                    "name": "Test Recipe"
                    // Missing required fields
                }'''
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.extract_recipe_data("Test recipe text")
        
        self.assertIsNone(result)  # Should return None due to validation failure
    
    def test_normalize_ingredients_enhanced_success(self):
        """Test enhanced ingredient normalization with validation"""
        mock_response = {
            "message": {
                "content": '''Here are the normalized ingredients:
                [
                    {
                        "name": "bread",
                        "amount": "2 slices",
                        "notes": "white bread"
                    },
                    {
                        "name": "butter",
                        "amount": "1 tbsp",
                        "notes": "room temperature"
                    }
                ]
                Additional text after JSON'''
            }
        }
        
        ingredients = ["2 slice white bread", "1 tablespoon butter, room temp"]
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.normalize_ingredients(ingredients)
        
        self.assertIsNotNone(result)
        self.assertEqual(len(result), 2)
        
        # Check first ingredient
        self.assertEqual(result[0]["name"], "bread")
        self.assertEqual(result[0]["amount"], "2 slices")
        self.assertEqual(result[0]["notes"], "white bread")
        
        # Check second ingredient
        self.assertEqual(result[1]["name"], "butter")
        self.assertEqual(result[1]["amount"], "1 tbsp")
        self.assertEqual(result[1]["notes"], "room temperature")
    
    def test_normalize_ingredients_empty_list(self):
        """Test ingredient normalization with empty list"""
        result = self.client.normalize_ingredients([])
        self.assertEqual(result, [])
    
    def test_normalize_ingredients_schema_validation_failure(self):
        """Test ingredient normalization with schema validation failure"""
        mock_response = {
            "message": {
                "content": '''[
                    {
                        "name": "bread"
                        // Missing required fields
                    }
                ]'''
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.normalize_ingredients(["bread"])
        
        self.assertIsNone(result)
    
    def test_clean_and_structure_text_enhanced_success(self):
        """Test enhanced text cleaning with validation"""
        raw_text = "Messy    text\n\n\nwith   extra\nspaces and formatting issues"
        cleaned_text = "Messy text with extra spaces and formatting issues"
        
        mock_response = {
            "message": {
                "content": cleaned_text
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.clean_and_structure_text(raw_text)
        
        self.assertEqual(result, cleaned_text)
    
    def test_clean_and_structure_text_too_short_result(self):
        """Test text cleaning when result is suspiciously short"""
        raw_text = "This is a long recipe text with lots of content that should not be lost during cleaning process"
        short_result = "Short"  # Much shorter than original
        
        mock_response = {
            "message": {
                "content": short_result
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.clean_and_structure_text(raw_text)
        
        # Should return original text if cleaned version is too short
        self.assertEqual(result, raw_text)
    
    def test_clean_and_structure_text_empty_input(self):
        """Test text cleaning with empty input"""
        result = self.client.clean_and_structure_text("")
        self.assertIsNone(result)
    
    def test_extract_recipe_name_success(self):
        """Test recipe name extraction"""
        text = "GRILLED CHEESE SANDWICH\n\nThis is a delicious recipe..."
        expected_name = "Grilled Cheese Sandwich"
        
        mock_response = {
            "message": {
                "content": expected_name
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.extract_recipe_name(text)
        
        self.assertEqual(result, expected_name)
    
    def test_extract_recipe_name_invalid_length(self):
        """Test recipe name extraction with invalid length"""
        text = "Some recipe text"
        
        # Test too long name
        mock_response = {
            "message": {
                "content": "A" * 150  # Too long
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.extract_recipe_name(text)
        
        self.assertIsNone(result)
        
        # Test too short name
        mock_response = {
            "message": {
                "content": "A"  # Too short
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.extract_recipe_name(text)
        
        self.assertIsNone(result)
    
    def test_extract_recipe_name_empty_input(self):
        """Test recipe name extraction with empty input"""
        result = self.client.extract_recipe_name("")
        self.assertIsNone(result)
    
    def test_separate_recipes_success(self):
        """Test recipe separation"""
        text = "Recipe 1: Grilled Cheese\n\nRecipe 2: BLT Sandwich"
        
        mock_response = {
            "message": {
                "content": '''[
                    {
                        "recipe_number": 1,
                        "name": "Grilled Cheese",
                        "start_marker": "Recipe 1:",
                        "content": "Recipe 1: Grilled Cheese content..."
                    },
                    {
                        "recipe_number": 2,
                        "name": "BLT Sandwich",
                        "start_marker": "Recipe 2:",
                        "content": "Recipe 2: BLT Sandwich content..."
                    }
                ]'''
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.separate_recipes(text)
        
        self.assertIsNotNone(result)
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]["recipe_number"], 1)
        self.assertEqual(result[0]["name"], "Grilled Cheese")
        self.assertEqual(result[1]["recipe_number"], 2)
        self.assertEqual(result[1]["name"], "BLT Sandwich")
    
    def test_separate_recipes_single_recipe(self):
        """Test recipe separation with single recipe"""
        text = "Single recipe content"
        
        mock_response = {
            "message": {
                "content": '''[
                    {
                        "recipe_number": 1,
                        "name": "Single Recipe",
                        "start_marker": "Single recipe",
                        "content": "Single recipe content"
                    }
                ]'''
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.separate_recipes(text)
        
        self.assertIsNotNone(result)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["recipe_number"], 1)
    
    def test_separate_recipes_schema_validation_failure(self):
        """Test recipe separation with schema validation failure"""
        mock_response = {
            "message": {
                "content": '''[
                    {
                        "recipe_number": 1
                        // Missing required fields
                    }
                ]'''
            }
        }
        
        with patch.object(self.client, 'chat_completion', return_value=mock_response):
            result = self.client.separate_recipes("Some text")
        
        self.assertIsNone(result)
    
    def test_separate_recipes_empty_input(self):
        """Test recipe separation with empty input"""
        result = self.client.separate_recipes("")
        self.assertIsNone(result)
    
    def test_post_process_recipe_data(self):
        """Test recipe data post-processing"""
        raw_data = {
            "name": "Test Recipe",
            "category": "sandwich",
            "ingredients": [
                {"name": "BREAD", "amount": " 2 slices ", "notes": " TOASTED "},
                {"name": "cheese", "amount": "1 slice", "notes": ""}
            ],
            "steps": [" Step 1 ", "", " Step 2 "],
            "equipment": ["pan"],
            "scoops": []
        }
        
        result = self.client._post_process_recipe_data(raw_data)
        
        # Check ingredients structure
        self.assertIn("ingredients", result)
        self.assertIn("whole", result["ingredients"])
        
        # Check ingredient processing
        ingredients = result["ingredients"]["whole"]
        self.assertEqual(ingredients[0]["name"], "bread")  # Lowercase
        self.assertEqual(ingredients[0]["amount"], "2 slices")  # Trimmed
        self.assertEqual(ingredients[0]["notes"], "toasted")  # Lowercase and trimmed
        
        # Check steps processing
        self.assertEqual(result["steps"], ["Step 1", "Step 2"])  # Empty strings removed
        
        # Check category validation
        self.assertEqual(result["category"], "sandwich")
    
    def test_post_process_recipe_data_invalid_category(self):
        """Test recipe data post-processing with invalid category"""
        raw_data = {
            "name": "Test Recipe",
            "category": "invalid",
            "ingredients": [],
            "steps": [],
            "equipment": [],
            "scoops": []
        }
        
        result = self.client._post_process_recipe_data(raw_data)
        self.assertEqual(result["category"], "other")
    
    def test_post_process_ingredients(self):
        """Test ingredient post-processing"""
        raw_ingredients = [
            {"name": " BREAD ", "amount": " 2 slices ", "notes": " TOASTED "},
            {"name": "cheese", "amount": "1 slice", "notes": ""}
        ]
        
        result = self.client._post_process_ingredients(raw_ingredients)
        
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]["name"], "bread")
        self.assertEqual(result[0]["amount"], "2 slices")
        self.assertEqual(result[0]["notes"], "toasted")


if __name__ == '__main__':
    unittest.main()