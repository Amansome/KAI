"""
Configuration management for Ollama integration in Kitchen Assistant Python processor.
"""

import json
import logging
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Optional, Dict, Any


logger = logging.getLogger(__name__)


@dataclass
class OllamaConfig:
    """Configuration settings for Ollama integration"""
    
    # Connection settings
    enabled: bool = True
    base_url: str = "http://localhost:11434"
    timeout: int = 30
    max_retries: int = 3
    
    # Model settings
    model: str = "llama3.2:3b"
    fallback_model: str = "llama3.2:1b"
    
    # Processing settings
    use_for_extraction: bool = True
    use_for_normalization: bool = True
    use_for_cleaning: bool = True
    
    # Performance settings
    max_context_length: int = 4000
    temperature: float = 0.1
    
    def __post_init__(self):
        """Validate configuration after initialization"""
        self.validate()
    
    def validate(self) -> None:
        """Validate configuration values"""
        if self.timeout <= 0:
            raise ValueError("Timeout must be positive")
        
        if self.max_retries < 0:
            raise ValueError("Max retries cannot be negative")
        
        if not self.base_url:
            raise ValueError("Base URL cannot be empty")
        
        if not self.model:
            raise ValueError("Model cannot be empty")
        
        if self.max_context_length <= 0:
            raise ValueError("Max context length must be positive")
        
        if not 0 <= self.temperature <= 2:
            raise ValueError("Temperature must be between 0 and 2")
        
        # Normalize base URL
        self.base_url = self.base_url.rstrip('/')
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert configuration to dictionary"""
        return asdict(self)
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'OllamaConfig':
        """Create configuration from dictionary"""
        # Filter out unknown keys
        valid_keys = {field.name for field in cls.__dataclass_fields__.values()}
        filtered_data = {k: v for k, v in data.items() if k in valid_keys}
        
        return cls(**filtered_data)
    
    def to_json(self) -> str:
        """Convert configuration to JSON string"""
        return json.dumps(self.to_dict(), indent=2)
    
    @classmethod
    def from_json(cls, json_str: str) -> 'OllamaConfig':
        """Create configuration from JSON string"""
        data = json.loads(json_str)
        return cls.from_dict(data)


class OllamaConfigManager:
    """Manager for Ollama configuration loading and saving"""
    
    DEFAULT_CONFIG_PATH = Path("ollama_config.json")
    
    def __init__(self, config_path: Optional[Path] = None):
        """
        Initialize configuration manager
        
        Args:
            config_path: Path to configuration file. If None, uses default.
        """
        self.config_path = config_path or self.DEFAULT_CONFIG_PATH
        self._config: Optional[OllamaConfig] = None
    
    def load_config(self) -> OllamaConfig:
        """
        Load configuration from file or create default
        
        Returns:
            OllamaConfig instance
        """
        if self._config is not None:
            return self._config
        
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    config_data = json.load(f)
                
                self._config = OllamaConfig.from_dict(config_data)
                logger.info(f"Loaded Ollama configuration from {self.config_path}")
                
            except (json.JSONDecodeError, ValueError, KeyError) as e:
                logger.warning(f"Failed to load config from {self.config_path}: {e}")
                logger.info("Using default configuration")
                self._config = OllamaConfig()
                
        else:
            logger.info(f"Configuration file {self.config_path} not found, using defaults")
            self._config = OllamaConfig()
        
        return self._config
    
    def save_config(self, config: Optional[OllamaConfig] = None) -> None:
        """
        Save configuration to file
        
        Args:
            config: Configuration to save. If None, saves current config.
        """
        if config is None:
            config = self._config
        
        if config is None:
            raise ValueError("No configuration to save")
        
        try:
            # Ensure directory exists
            self.config_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(self.config_path, 'w') as f:
                json.dump(config.to_dict(), f, indent=2)
            
            logger.info(f"Saved Ollama configuration to {self.config_path}")
            self._config = config
            
        except (OSError, json.JSONEncodeError) as e:
            logger.error(f"Failed to save config to {self.config_path}: {e}")
            raise
    
    def update_config(self, **kwargs) -> OllamaConfig:
        """
        Update configuration with new values
        
        Args:
            **kwargs: Configuration values to update
            
        Returns:
            Updated configuration
        """
        current_config = self.load_config()
        config_dict = current_config.to_dict()
        config_dict.update(kwargs)
        
        new_config = OllamaConfig.from_dict(config_dict)
        self.save_config(new_config)
        
        return new_config
    
    def reset_to_defaults(self) -> OllamaConfig:
        """
        Reset configuration to defaults
        
        Returns:
            Default configuration
        """
        default_config = OllamaConfig()
        self.save_config(default_config)
        return default_config
    
    @property
    def config(self) -> OllamaConfig:
        """Get current configuration (loads if not already loaded)"""
        return self.load_config()


def get_config(config_path: Optional[Path] = None) -> OllamaConfig:
    """
    Convenience function to get Ollama configuration
    
    Args:
        config_path: Path to configuration file
        
    Returns:
        OllamaConfig instance
    """
    manager = OllamaConfigManager(config_path)
    return manager.load_config()


def create_default_config(config_path: Optional[Path] = None) -> None:
    """
    Create a default configuration file
    
    Args:
        config_path: Path where to create the configuration file
    """
    manager = OllamaConfigManager(config_path)
    default_config = OllamaConfig()
    manager.save_config(default_config)
    
    print(f"Created default Ollama configuration at {manager.config_path}")
    print("Configuration contents:")
    print(default_config.to_json())


if __name__ == "__main__":
    # Create default configuration when run as script
    create_default_config()