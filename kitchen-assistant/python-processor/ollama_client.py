"""
Ollama client for Kitchen Assistant Python processor.
Provides HTTP communication with local Ollama service for recipe processing.
"""

import json
import logging
import time
from typing import Dict, List, Optional, Any
import requests
from requests.exceptions import RequestException, Timeout, ConnectionError

from recipe_prompts import (
    format_recipe_extraction_prompt,
    format_ingredient_normalization_prompt,
    format_text_cleaning_prompt,
    format_recipe_name_prompt,
    format_recipe_separation_prompt,
    PromptFormatter,
    RecipePromptTemplates
)


# Configure logging
logger = logging.getLogger(__name__)


class OllamaError(Exception):
    """Base exception for Ollama-related errors"""
    pass


class ServiceUnavailableError(OllamaError):
    """Ollama service is not running or accessible"""
    pass


class ModelNotFoundError(OllamaError):
    """Requested model is not available"""
    pass


class TimeoutError(OllamaError):
    """Request timed out"""
    pass


class InvalidResponseError(OllamaError):
    """Invalid response from Ollama"""
    pass


def safe_ollama_call(func):
    """Decorator for safe Ollama API calls with fallback"""
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except OllamaError as e:
            logger.warning(f"Ollama error: {e}, falling back to regex")
            return None
    return wrapper


class OllamaClient:
    """Client for communicating with Ollama service"""
    
    def __init__(self, base_url: str = "http://localhost:11434", timeout: int = 30, max_retries: int = 3):
        """
        Initialize Ollama client
        
        Args:
            base_url: Base URL for Ollama service
            timeout: Request timeout in seconds
            max_retries: Maximum number of retry attempts
        """
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        self.max_retries = max_retries
        self.session = requests.Session()
        
    def is_available(self) -> bool:
        """
        Check if Ollama service is available
        
        Returns:
            True if service is available, False otherwise
        """
        try:
            response = self.session.get(
                f"{self.base_url}/api/tags",
                timeout=5  # Short timeout for availability check
            )
            return response.status_code == 200
        except RequestException:
            return False
    
    def get_models(self) -> List[str]:
        """
        Get list of available models
        
        Returns:
            List of model names
            
        Raises:
            ServiceUnavailableError: If service is not available
            InvalidResponseError: If response format is invalid
        """
        try:
            response = self.session.get(
                f"{self.base_url}/api/tags",
                timeout=self.timeout
            )
            response.raise_for_status()
            
            data = response.json()
            if 'models' not in data:
                raise InvalidResponseError("Invalid response format: missing 'models' field")
                
            return [model['name'] for model in data['models']]
            
        except ConnectionError:
            raise ServiceUnavailableError("Cannot connect to Ollama service")
        except Timeout:
            raise TimeoutError("Request timed out")
        except json.JSONDecodeError:
            raise InvalidResponseError("Invalid JSON response")
        except RequestException as e:
            raise ServiceUnavailableError(f"Request failed: {e}")
    
    def _make_request_with_retry(self, method: str, url: str, **kwargs) -> requests.Response:
        """
        Make HTTP request with retry logic
        
        Args:
            method: HTTP method (GET, POST, etc.)
            url: Request URL
            **kwargs: Additional request parameters
            
        Returns:
            Response object
            
        Raises:
            ServiceUnavailableError: If all retries fail
            TimeoutError: If request times out
        """
        last_exception = None
        
        for attempt in range(self.max_retries):
            try:
                response = self.session.request(method, url, timeout=self.timeout, **kwargs)
                response.raise_for_status()
                return response
                
            except Timeout:
                raise TimeoutError("Request timed out")
            except ConnectionError as e:
                last_exception = e
                if attempt < self.max_retries - 1:
                    # Exponential backoff
                    wait_time = 2 ** attempt
                    logger.warning(f"Connection failed, retrying in {wait_time}s (attempt {attempt + 1}/{self.max_retries})")
                    time.sleep(wait_time)
                continue
            except RequestException as e:
                raise ServiceUnavailableError(f"Request failed: {e}")
        
        raise ServiceUnavailableError(f"All retry attempts failed. Last error: {last_exception}")
    
    def chat_completion(self, model: str, messages: List[Dict[str, str]], stream: bool = False) -> Dict[str, Any]:
        """
        Send chat completion request to Ollama
        
        Args:
            model: Model name to use
            messages: List of message dictionaries with 'role' and 'content'
            stream: Whether to stream the response
            
        Returns:
            Response dictionary
            
        Raises:
            ModelNotFoundError: If model is not available
            ServiceUnavailableError: If service is not available
            InvalidResponseError: If response format is invalid
        """
        payload = {
            "model": model,
            "messages": messages,
            "stream": stream
        }
        
        try:
            response = self._make_request_with_retry(
                "POST",
                f"{self.base_url}/api/chat",
                json=payload
            )
            
            data = response.json()
            
            # Validate response format
            if 'message' not in data:
                raise InvalidResponseError("Invalid response format: missing 'message' field")
                
            return data
            
        except json.JSONDecodeError:
            raise InvalidResponseError("Invalid JSON response")
        except ServiceUnavailableError as e:
            # Check if it's a model not found error
            if self.is_available():
                # Service is available, might be a model issue
                try:
                    available_models = self.get_models()
                    if model not in available_models:
                        raise ModelNotFoundError(f"Model '{model}' not found. Available models: {available_models}")
                except OllamaError:
                    pass  # If we can't check models, assume it's a service issue
            
            # Re-raise the original error if not a model issue
            raise
    
    @safe_ollama_call
    def extract_recipe_data(self, text: str, model: str = "llama3.2:3b") -> Optional[Dict[str, Any]]:
        """
        Extract structured recipe data from text using Ollama with enhanced prompts
        
        Args:
            text: Raw recipe text to process
            model: Model to use for extraction
            
        Returns:
            Extracted recipe data as dictionary, or None if extraction fails
        """
        try:
            # Use structured prompt template
            prompt = format_recipe_extraction_prompt(text)
            
            messages = [
                {"role": "user", "content": prompt}
            ]
            
            response = self.chat_completion(model, messages)
            content = response['message']['content']
            
            # Extract and validate JSON using prompt formatter
            extracted_data = PromptFormatter.extract_json_from_response(content)
            
            if extracted_data is None:
                logger.warning("No valid JSON found in Ollama response")
                return None
            
            # Validate against schema
            schema = RecipePromptTemplates.RECIPE_EXTRACTION_TEMPLATE.validation_schema
            if not PromptFormatter.validate_json_response(json.dumps(extracted_data), schema):
                logger.warning("Extracted JSON does not match expected schema")
                return None
            
            # Post-process the extracted data
            return self._post_process_recipe_data(extracted_data)
            
        except (json.JSONDecodeError, KeyError) as e:
            logger.warning(f"Failed to parse Ollama response: {e}")
            return None
        except OllamaError as e:
            logger.warning(f"Ollama error during recipe extraction: {e}")
            return None
    
    def _post_process_recipe_data(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Post-process extracted recipe data for consistency
        
        Args:
            data: Raw extracted recipe data
            
        Returns:
            Processed recipe data
        """
        # Ensure ingredients have the correct structure
        if "ingredients" in data:
            processed_ingredients = {"whole": []}
            
            for ingredient in data["ingredients"]:
                if isinstance(ingredient, dict):
                    processed_ingredients["whole"].append({
                        "name": ingredient.get("name", "").lower().strip(),
                        "amount": ingredient.get("amount", "").strip(),
                        "notes": ingredient.get("notes", "").lower().strip()
                    })
            
            data["ingredients"] = processed_ingredients
        
        # Ensure steps are clean strings
        if "steps" in data:
            data["steps"] = [step.strip() for step in data["steps"] if step.strip()]
        
        # Ensure equipment and scoops are lists
        data["equipment"] = data.get("equipment", [])
        data["scoops"] = data.get("scoops", [])
        
        # Ensure category is valid
        valid_categories = ["sandwich", "salad", "kids", "prep", "other"]
        if data.get("category") not in valid_categories:
            data["category"] = "other"
        
        return data
    
    @safe_ollama_call
    def normalize_ingredients(self, ingredients: List[str], model: str = "llama3.2:3b") -> Optional[List[Dict[str, str]]]:
        """
        Normalize ingredient list to consistent format using enhanced prompts
        
        Args:
            ingredients: List of ingredient strings
            model: Model to use for normalization
            
        Returns:
            List of normalized ingredient dictionaries, or None if normalization fails
        """
        if not ingredients:
            return []
        
        try:
            # Use structured prompt template
            prompt = format_ingredient_normalization_prompt(ingredients)
            
            messages = [
                {"role": "user", "content": prompt}
            ]
            
            response = self.chat_completion(model, messages)
            content = response['message']['content']
            
            # Extract and validate JSON using prompt formatter
            extracted_data = PromptFormatter.extract_json_from_response(content)
            
            if extracted_data is None:
                logger.warning("No valid JSON found in Ollama response")
                return None
            
            # Validate against schema
            schema = RecipePromptTemplates.INGREDIENT_NORMALIZATION_TEMPLATE.validation_schema
            if not PromptFormatter.validate_json_response(json.dumps(extracted_data), schema):
                logger.warning("Extracted JSON does not match expected schema")
                return None
            
            # Post-process ingredients
            return self._post_process_ingredients(extracted_data)
            
        except (json.JSONDecodeError, KeyError) as e:
            logger.warning(f"Failed to parse Ollama response: {e}")
            return None
        except OllamaError as e:
            logger.warning(f"Ollama error during ingredient normalization: {e}")
            return None
    
    def _post_process_ingredients(self, ingredients: List[Dict[str, str]]) -> List[Dict[str, str]]:
        """
        Post-process normalized ingredients for consistency
        
        Args:
            ingredients: Raw normalized ingredients
            
        Returns:
            Processed ingredients
        """
        processed = []
        
        for ingredient in ingredients:
            if isinstance(ingredient, dict):
                processed.append({
                    "name": ingredient.get("name", "").lower().strip(),
                    "amount": ingredient.get("amount", "").strip(),
                    "notes": ingredient.get("notes", "").lower().strip()
                })
        
        return processed
    
    @safe_ollama_call
    def clean_and_structure_text(self, raw_text: str, model: str = "llama3.2:3b") -> Optional[str]:
        """
        Clean and structure raw PDF text for better processing using enhanced prompts
        
        Args:
            raw_text: Raw text extracted from PDF
            model: Model to use for cleaning
            
        Returns:
            Cleaned and structured text, or None if cleaning fails
        """
        if not raw_text.strip():
            return None
        
        try:
            # Use structured prompt template
            prompt = format_text_cleaning_prompt(raw_text)
            
            messages = [
                {"role": "user", "content": prompt}
            ]
            
            response = self.chat_completion(model, messages)
            cleaned_text = response['message']['content'].strip()
            
            # Basic validation - ensure we got meaningful text back
            if len(cleaned_text) < len(raw_text) * 0.3:  # Should not lose more than 70% of content
                logger.warning("Cleaned text is significantly shorter than original, may have lost content")
                return raw_text  # Return original if cleaning seems to have failed
            
            return cleaned_text
            
        except (KeyError, OllamaError) as e:
            logger.warning(f"Failed to clean text with Ollama: {e}")
            return None
    
    @safe_ollama_call
    def extract_recipe_name(self, text: str, model: str = "llama3.2:3b") -> Optional[str]:
        """
        Extract recipe name from text using Ollama
        
        Args:
            text: Text to extract recipe name from
            model: Model to use for extraction
            
        Returns:
            Extracted recipe name, or None if extraction fails
        """
        if not text.strip():
            return None
        
        try:
            # Use structured prompt template
            prompt = format_recipe_name_prompt(text)
            
            messages = [
                {"role": "user", "content": prompt}
            ]
            
            response = self.chat_completion(model, messages)
            recipe_name = response['message']['content'].strip()
            
            # Basic validation
            if len(recipe_name) > 100 or len(recipe_name) < 2:
                logger.warning(f"Extracted recipe name seems invalid: '{recipe_name}'")
                return None
            
            return recipe_name
            
        except (KeyError, OllamaError) as e:
            logger.warning(f"Failed to extract recipe name with Ollama: {e}")
            return None
    
    @safe_ollama_call
    def separate_recipes(self, text: str, model: str = "llama3.2:3b") -> Optional[List[Dict[str, Any]]]:
        """
        Separate multiple recipes from combined text using Ollama
        
        Args:
            text: Text that may contain multiple recipes
            model: Model to use for separation
            
        Returns:
            List of separated recipe dictionaries, or None if separation fails
        """
        if not text.strip():
            return None
        
        try:
            # Use structured prompt template
            prompt = format_recipe_separation_prompt(text)
            
            messages = [
                {"role": "user", "content": prompt}
            ]
            
            response = self.chat_completion(model, messages)
            content = response['message']['content']
            
            # Extract and validate JSON using prompt formatter
            extracted_data = PromptFormatter.extract_json_from_response(content)
            
            if extracted_data is None:
                logger.warning("No valid JSON found in recipe separation response")
                return None
            
            # Validate against schema
            schema = RecipePromptTemplates.RECIPE_SEPARATION_TEMPLATE.validation_schema
            if not PromptFormatter.validate_json_response(json.dumps(extracted_data), schema):
                logger.warning("Recipe separation JSON does not match expected schema")
                return None
            
            return extracted_data
            
        except (json.JSONDecodeError, KeyError) as e:
            logger.warning(f"Failed to parse recipe separation response: {e}")
            return None
        except OllamaError as e:
            logger.warning(f"Ollama error during recipe separation: {e}")
            return None