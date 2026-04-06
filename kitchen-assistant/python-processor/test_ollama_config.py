"""
Unit tests for Ollama configuration management
"""

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch, mock_open

from ollama_config import OllamaConfig, OllamaConfigManager, get_config, create_default_config


class TestOllamaConfig(unittest.TestCase):
    """Test cases for OllamaConfig"""
    
    def test_default_values(self):
        """Test default configuration values"""
        config = OllamaConfig()
        
        self.assertTrue(config.enabled)
        self.assertEqual(config.base_url, "http://localhost:11434")
        self.assertEqual(config.timeout, 30)
        self.assertEqual(config.max_retries, 3)
        self.assertEqual(config.model, "llama3.2:3b")
        self.assertEqual(config.fallback_model, "llama3.2:1b")
        self.assertTrue(config.use_for_extraction)
        self.assertTrue(config.use_for_normalization)
        self.assertTrue(config.use_for_cleaning)
        self.assertEqual(config.max_context_length, 4000)
        self.assertEqual(config.temperature, 0.1)
    
    def test_custom_values(self):
        """Test configuration with custom values"""
        config = OllamaConfig(
            enabled=False,
            base_url="http://custom:8080/",
            timeout=60,
            max_retries=5,
            model="custom:model",
            temperature=0.5
        )
        
        self.assertFalse(config.enabled)
        self.assertEqual(config.base_url, "http://custom:8080")  # Should be normalized
        self.assertEqual(config.timeout, 60)
        self.assertEqual(config.max_retries, 5)
        self.assertEqual(config.model, "custom:model")
        self.assertEqual(config.temperature, 0.5)
    
    def test_validation_positive_timeout(self):
        """Test validation of positive timeout"""
        with self.assertRaises(ValueError):
            OllamaConfig(timeout=0)
        
        with self.assertRaises(ValueError):
            OllamaConfig(timeout=-1)
    
    def test_validation_non_negative_retries(self):
        """Test validation of non-negative max retries"""
        with self.assertRaises(ValueError):
            OllamaConfig(max_retries=-1)
        
        # Zero retries should be allowed
        config = OllamaConfig(max_retries=0)
        self.assertEqual(config.max_retries, 0)
    
    def test_validation_non_empty_base_url(self):
        """Test validation of non-empty base URL"""
        with self.assertRaises(ValueError):
            OllamaConfig(base_url="")
    
    def test_validation_non_empty_model(self):
        """Test validation of non-empty model"""
        with self.assertRaises(ValueError):
            OllamaConfig(model="")
    
    def test_validation_positive_context_length(self):
        """Test validation of positive context length"""
        with self.assertRaises(ValueError):
            OllamaConfig(max_context_length=0)
        
        with self.assertRaises(ValueError):
            OllamaConfig(max_context_length=-1)
    
    def test_validation_temperature_range(self):
        """Test validation of temperature range"""
        with self.assertRaises(ValueError):
            OllamaConfig(temperature=-0.1)
        
        with self.assertRaises(ValueError):
            OllamaConfig(temperature=2.1)
        
        # Boundary values should be allowed
        config1 = OllamaConfig(temperature=0.0)
        self.assertEqual(config1.temperature, 0.0)
        
        config2 = OllamaConfig(temperature=2.0)
        self.assertEqual(config2.temperature, 2.0)
    
    def test_base_url_normalization(self):
        """Test base URL normalization (trailing slash removal)"""
        config = OllamaConfig(base_url="http://localhost:11434/")
        self.assertEqual(config.base_url, "http://localhost:11434")
        
        config2 = OllamaConfig(base_url="http://localhost:11434///")
        self.assertEqual(config2.base_url, "http://localhost:11434")
    
    def test_to_dict(self):
        """Test conversion to dictionary"""
        config = OllamaConfig(enabled=False, timeout=60)
        config_dict = config.to_dict()
        
        self.assertIsInstance(config_dict, dict)
        self.assertFalse(config_dict['enabled'])
        self.assertEqual(config_dict['timeout'], 60)
        self.assertEqual(config_dict['base_url'], "http://localhost:11434")
    
    def test_from_dict(self):
        """Test creation from dictionary"""
        data = {
            'enabled': False,
            'base_url': 'http://custom:8080',
            'timeout': 60,
            'model': 'custom:model'
        }
        
        config = OllamaConfig.from_dict(data)
        
        self.assertFalse(config.enabled)
        self.assertEqual(config.base_url, "http://custom:8080")
        self.assertEqual(config.timeout, 60)
        self.assertEqual(config.model, "custom:model")
        # Default values should be preserved
        self.assertEqual(config.max_retries, 3)
    
    def test_from_dict_filters_unknown_keys(self):
        """Test that from_dict filters out unknown keys"""
        data = {
            'enabled': False,
            'unknown_key': 'should_be_ignored',
            'another_unknown': 123
        }
        
        config = OllamaConfig.from_dict(data)
        
        self.assertFalse(config.enabled)
        # Should not raise an error and should use defaults for other values
        self.assertEqual(config.base_url, "http://localhost:11434")
    
    def test_to_json(self):
        """Test conversion to JSON"""
        config = OllamaConfig(enabled=False, timeout=60)
        json_str = config.to_json()
        
        self.assertIsInstance(json_str, str)
        
        # Parse back to verify
        data = json.loads(json_str)
        self.assertFalse(data['enabled'])
        self.assertEqual(data['timeout'], 60)
    
    def test_from_json(self):
        """Test creation from JSON"""
        json_str = '{"enabled": false, "timeout": 60, "model": "custom:model"}'
        
        config = OllamaConfig.from_json(json_str)
        
        self.assertFalse(config.enabled)
        self.assertEqual(config.timeout, 60)
        self.assertEqual(config.model, "custom:model")


class TestOllamaConfigManager(unittest.TestCase):
    """Test cases for OllamaConfigManager"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.config_path = Path(self.temp_dir.name) / "test_config.json"
        self.manager = OllamaConfigManager(self.config_path)
    
    def tearDown(self):
        """Clean up test fixtures"""
        self.temp_dir.cleanup()
    
    def test_load_config_default_when_file_not_exists(self):
        """Test loading default config when file doesn't exist"""
        config = self.manager.load_config()
        
        self.assertIsInstance(config, OllamaConfig)
        self.assertTrue(config.enabled)
        self.assertEqual(config.base_url, "http://localhost:11434")
    
    def test_load_config_from_file(self):
        """Test loading config from existing file"""
        # Create a config file
        test_config = {
            'enabled': False,
            'base_url': 'http://test:8080',
            'timeout': 60
        }
        
        with open(self.config_path, 'w') as f:
            json.dump(test_config, f)
        
        config = self.manager.load_config()
        
        self.assertFalse(config.enabled)
        self.assertEqual(config.base_url, "http://test:8080")
        self.assertEqual(config.timeout, 60)
    
    def test_load_config_invalid_json(self):
        """Test loading config with invalid JSON falls back to defaults"""
        # Create invalid JSON file
        with open(self.config_path, 'w') as f:
            f.write("{ invalid json }")
        
        config = self.manager.load_config()
        
        # Should fall back to defaults
        self.assertTrue(config.enabled)
        self.assertEqual(config.base_url, "http://localhost:11434")
    
    def test_load_config_invalid_values(self):
        """Test loading config with invalid values falls back to defaults"""
        # Create config with invalid values
        test_config = {
            'enabled': True,
            'timeout': -1  # Invalid
        }
        
        with open(self.config_path, 'w') as f:
            json.dump(test_config, f)
        
        config = self.manager.load_config()
        
        # Should fall back to defaults
        self.assertTrue(config.enabled)
        self.assertEqual(config.timeout, 30)  # Default value
    
    def test_save_config(self):
        """Test saving configuration to file"""
        config = OllamaConfig(enabled=False, timeout=60)
        
        self.manager.save_config(config)
        
        # Verify file was created and contains correct data
        self.assertTrue(self.config_path.exists())
        
        with open(self.config_path, 'r') as f:
            saved_data = json.load(f)
        
        self.assertFalse(saved_data['enabled'])
        self.assertEqual(saved_data['timeout'], 60)
    
    def test_save_config_creates_directory(self):
        """Test that save_config creates parent directories"""
        nested_path = Path(self.temp_dir.name) / "nested" / "dir" / "config.json"
        manager = OllamaConfigManager(nested_path)
        
        config = OllamaConfig()
        manager.save_config(config)
        
        self.assertTrue(nested_path.exists())
    
    def test_save_config_no_config_raises_error(self):
        """Test that save_config raises error when no config provided"""
        with self.assertRaises(ValueError):
            self.manager.save_config()
    
    def test_update_config(self):
        """Test updating configuration"""
        # First save a config
        initial_config = OllamaConfig(enabled=True, timeout=30)
        self.manager.save_config(initial_config)
        
        # Update it
        updated_config = self.manager.update_config(enabled=False, timeout=60)
        
        self.assertFalse(updated_config.enabled)
        self.assertEqual(updated_config.timeout, 60)
        
        # Verify it was saved
        loaded_config = self.manager.load_config()
        self.assertFalse(loaded_config.enabled)
        self.assertEqual(loaded_config.timeout, 60)
    
    def test_reset_to_defaults(self):
        """Test resetting configuration to defaults"""
        # First save a custom config
        custom_config = OllamaConfig(enabled=False, timeout=60)
        self.manager.save_config(custom_config)
        
        # Reset to defaults
        default_config = self.manager.reset_to_defaults()
        
        self.assertTrue(default_config.enabled)
        self.assertEqual(default_config.timeout, 30)
        
        # Verify it was saved
        loaded_config = self.manager.load_config()
        self.assertTrue(loaded_config.enabled)
        self.assertEqual(loaded_config.timeout, 30)
    
    def test_config_property(self):
        """Test config property"""
        config = self.manager.config
        
        self.assertIsInstance(config, OllamaConfig)
        # Should be the same instance on subsequent calls
        self.assertIs(config, self.manager.config)


class TestUtilityFunctions(unittest.TestCase):
    """Test cases for utility functions"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.config_path = Path(self.temp_dir.name) / "test_config.json"
    
    def tearDown(self):
        """Clean up test fixtures"""
        self.temp_dir.cleanup()
    
    def test_get_config(self):
        """Test get_config utility function"""
        config = get_config(self.config_path)
        
        self.assertIsInstance(config, OllamaConfig)
        self.assertTrue(config.enabled)
    
    @patch('builtins.print')
    def test_create_default_config(self, mock_print):
        """Test create_default_config utility function"""
        create_default_config(self.config_path)
        
        # Verify file was created
        self.assertTrue(self.config_path.exists())
        
        # Verify it contains default values
        with open(self.config_path, 'r') as f:
            data = json.load(f)
        
        self.assertTrue(data['enabled'])
        self.assertEqual(data['base_url'], "http://localhost:11434")
        
        # Verify print was called
        self.assertTrue(mock_print.called)


if __name__ == '__main__':
    unittest.main()