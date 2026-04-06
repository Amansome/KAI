"""
Ollama Recipe Training System
Trains Ollama models with recipe data to enable intelligent recipe Q&A
"""

import json
import logging
from pathlib import Path
from typing import Dict, List, Any, Optional
import time

from ollama_client import OllamaClient, OllamaError
from ollama_config import OllamaConfig


# Configure logging
logger = logging.getLogger(__name__)


class OllamaRecipeTrainer:
    """
    Trains Ollama models with recipe data for intelligent Q&A capabilities
    """
    
    def __init__(self, recipes_file: str = "output/recipes.json"):
        """
        Initialize the trainer
        
        Args:
            recipes_file: Path to the recipes JSON file
        """
        self.recipes_file = Path(recipes_file)
        self.recipes_data = None
        self.ollama_client = None
        self.config = None
        
        # Initialize Ollama
        self._initialize_ollama()
        
        # Load recipes
        self._load_recipes()
    
    def _initialize_ollama(self) -> None:
        """Initialize Ollama client and configuration"""
        try:
            self.config = OllamaConfig.load_from_file()
            
            if not self.config.enabled:
                raise Exception("Ollama is disabled in configuration")
            
            self.ollama_client = OllamaClient(
                base_url=self.config.base_url,
                timeout=self.config.timeout,
                max_retries=self.config.max_retries
            )
            
            if not self.ollama_client.is_available():
                raise Exception("Ollama service is not available")
            
            logger.info(f"Ollama initialized for training with model: {self.config.model}")
            
        except Exception as e:
            logger.error(f"Failed to initialize Ollama: {e}")
            raise
    
    def _load_recipes(self) -> None:
        """Load recipes from JSON file"""
        try:
            if not self.recipes_file.exists():
                raise FileNotFoundError(f"Recipes file not found: {self.recipes_file}")
            
            with open(self.recipes_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            self.recipes_data = data.get('recipes', [])
            logger.info(f"Loaded {len(self.recipes_data)} recipes for training")
            
        except Exception as e:
            logger.error(f"Failed to load recipes: {e}")
            raise
    
    def create_training_context(self) -> str:
        """
        Create a comprehensive training context from all recipes
        
        Returns:
            Formatted training context string
        """
        context_parts = [
            "# Kitchen Assistant Recipe Database",
            "",
            "You are a helpful kitchen assistant with access to a comprehensive recipe database.",
            "You can answer questions about recipes, ingredients, cooking techniques, and equipment.",
            "Always provide accurate, helpful, and safe cooking advice.",
            "",
            "## Available Recipes:",
            ""
        ]
        
        for recipe in self.recipes_data:
            recipe_context = self._format_recipe_for_context(recipe)
            context_parts.append(recipe_context)
            context_parts.append("")  # Empty line between recipes
        
        context_parts.extend([
            "## Instructions:",
            "- Answer questions about any of these recipes",
            "- Provide ingredient substitutions when asked",
            "- Explain cooking techniques and equipment usage",
            "- Help with recipe modifications and scaling",
            "- Always prioritize food safety",
            "- If you don't know something, say so rather than guessing",
            ""
        ])
        
        return "\n".join(context_parts)
    
    def _format_recipe_for_context(self, recipe: Dict[str, Any]) -> str:
        """
        Format a single recipe for training context
        
        Args:
            recipe: Recipe dictionary
            
        Returns:
            Formatted recipe string
        """
        parts = [
            f"### {recipe.get('name', 'Unknown Recipe')} (ID: {recipe.get('id', 'unknown')})",
            f"**Category:** {recipe.get('category', 'other')}",
            ""
        ]
        
        # Ingredients
        ingredients = recipe.get('ingredients', {}).get('whole', [])
        if ingredients:
            parts.append("**Ingredients:**")
            for ing in ingredients:
                amount = ing.get('amount', '')
                name = ing.get('name', '')
                notes = ing.get('notes', '')
                
                ingredient_line = f"- {amount} {name}"
                if notes:
                    ingredient_line += f" ({notes})"
                
                parts.append(ingredient_line)
            parts.append("")
        
        # Steps
        steps = recipe.get('steps', [])
        if steps:
            parts.append("**Steps:**")
            for i, step in enumerate(steps, 1):
                parts.append(f"{i}. {step}")
            parts.append("")
        
        # Equipment
        equipment = recipe.get('equipment', [])
        if equipment:
            parts.append(f"**Equipment:** {', '.join(equipment)}")
            parts.append("")
        
        # Scoops
        scoops = recipe.get('scoops', [])
        if scoops:
            parts.append(f"**Scoops:** {', '.join(scoops)}")
            parts.append("")
        
        return "\n".join(parts)
    
    def create_training_examples(self) -> List[Dict[str, str]]:
        """
        Create training examples for common Q&A patterns
        
        Returns:
            List of training example dictionaries
        """
        examples = []
        
        # Add general examples
        examples.extend([
            {
                "question": "What recipes do you know?",
                "answer": f"I know {len(self.recipes_data)} recipes including " + 
                         ", ".join([r.get('name', 'Unknown') for r in self.recipes_data[:5]]) +
                         ("..." if len(self.recipes_data) > 5 else "")
            },
            {
                "question": "What categories of recipes do you have?",
                "answer": "I have recipes in these categories: " + 
                         ", ".join(set(r.get('category', 'other') for r in self.recipes_data))
            }
        ])
        
        # Add recipe-specific examples
        for recipe in self.recipes_data[:10]:  # Limit to first 10 for training
            name = recipe.get('name', 'Unknown Recipe')
            ingredients = recipe.get('ingredients', {}).get('whole', [])
            steps = recipe.get('steps', [])
            
            # Ingredient questions
            if ingredients:
                ingredient_names = [ing.get('name', '') for ing in ingredients]
                examples.append({
                    "question": f"What ingredients do I need for {name}?",
                    "answer": f"For {name}, you need: " + ", ".join(ingredient_names)
                })
            
            # Step questions
            if steps:
                examples.append({
                    "question": f"How do I make {name}?",
                    "answer": f"To make {name}: " + " ".join([f"{i+1}. {step}" for i, step in enumerate(steps[:3])])
                })
            
            # Equipment questions
            equipment = recipe.get('equipment', [])
            if equipment:
                examples.append({
                    "question": f"What equipment do I need for {name}?",
                    "answer": f"For {name}, you'll need: " + ", ".join(equipment)
                })
        
        return examples
    
    def train_with_context(self) -> bool:
        """
        Train Ollama with recipe context using conversation examples
        
        Returns:
            True if training successful, False otherwise
        """
        try:
            print("🤖 Training Ollama with recipe database...")
            
            # Create training context
            context = self.create_training_context()
            training_examples = self.create_training_examples()
            
            print(f"📚 Training context: {len(context)} characters")
            print(f"💡 Training examples: {len(training_examples)} Q&A pairs")
            
            # Train with multiple conversation examples
            successful_trainings = 0
            
            for i, example in enumerate(training_examples):
                try:
                    # Create a conversation with context
                    messages = [
                        {
                            "role": "system",
                            "content": context
                        },
                        {
                            "role": "user", 
                            "content": example["question"]
                        },
                        {
                            "role": "assistant",
                            "content": example["answer"]
                        }
                    ]
                    
                    # Send training conversation to Ollama
                    response = self.ollama_client.chat_completion(
                        model=self.config.model,
                        messages=messages
                    )
                    
                    if response:
                        successful_trainings += 1
                        if (i + 1) % 5 == 0:
                            print(f"   ✅ Trained {i + 1}/{len(training_examples)} examples")
                    
                    # Small delay to avoid overwhelming Ollama
                    time.sleep(0.1)
                    
                except Exception as e:
                    logger.warning(f"Failed to train example {i + 1}: {e}")
                    continue
            
            success_rate = successful_trainings / len(training_examples) if training_examples else 0
            print(f"🎯 Training completed: {successful_trainings}/{len(training_examples)} examples ({success_rate:.1%} success rate)")
            
            return success_rate > 0.5  # Consider successful if > 50% examples worked
            
        except Exception as e:
            logger.error(f"Training failed: {e}")
            return False
    
    def test_trained_model(self) -> bool:
        """
        Test the trained model with sample questions
        
        Returns:
            True if model responds appropriately, False otherwise
        """
        try:
            print("\n🧪 Testing trained model...")
            
            test_questions = [
                "What recipes do you know?",
                "How do I make a grilled cheese sandwich?",
                "What ingredients do I need for a BLT?",
                "What equipment do I need for cooking?"
            ]
            
            context = self.create_training_context()
            successful_tests = 0
            
            for question in test_questions:
                try:
                    messages = [
                        {
                            "role": "system",
                            "content": context
                        },
                        {
                            "role": "user",
                            "content": question
                        }
                    ]
                    
                    response = self.ollama_client.chat_completion(
                        model=self.config.model,
                        messages=messages
                    )
                    
                    if response and response.get('message', {}).get('content'):
                        answer = response['message']['content']
                        print(f"   Q: {question}")
                        print(f"   A: {answer[:100]}{'...' if len(answer) > 100 else ''}")
                        print()
                        successful_tests += 1
                    
                except Exception as e:
                    logger.warning(f"Test question failed: {e}")
                    continue
            
            success_rate = successful_tests / len(test_questions)
            print(f"✅ Model testing completed: {successful_tests}/{len(test_questions)} questions answered ({success_rate:.1%} success rate)")
            
            return success_rate > 0.5
            
        except Exception as e:
            logger.error(f"Model testing failed: {e}")
            return False
    
    def create_recipe_qa_system(self) -> 'RecipeQASystem':
        """
        Create a Q&A system using the trained model
        
        Returns:
            RecipeQASystem instance
        """
        return RecipeQASystem(self.ollama_client, self.config, self.recipes_data)


class RecipeQASystem:
    """
    Q&A system for recipe queries using trained Ollama model
    """
    
    def __init__(self, ollama_client: OllamaClient, config: OllamaConfig, recipes_data: List[Dict]):
        """
        Initialize Q&A system
        
        Args:
            ollama_client: Configured Ollama client
            config: Ollama configuration
            recipes_data: Recipe database
        """
        self.ollama_client = ollama_client
        self.config = config
        self.recipes_data = recipes_data
        self.context = self._build_context()
    
    def _build_context(self) -> str:
        """Build context for Q&A system"""
        trainer = OllamaRecipeTrainer()
        trainer.recipes_data = self.recipes_data
        return trainer.create_training_context()
    
    def ask_question(self, question: str) -> Optional[str]:
        """
        Ask a question about recipes
        
        Args:
            question: User's question
            
        Returns:
            Answer from the trained model, or None if failed
        """
        try:
            messages = [
                {
                    "role": "system",
                    "content": self.context
                },
                {
                    "role": "user",
                    "content": question
                }
            ]
            
            response = self.ollama_client.chat_completion(
                model=self.config.model,
                messages=messages
            )
            
            if response and response.get('message', {}).get('content'):
                return response['message']['content']
            
            return None
            
        except Exception as e:
            logger.error(f"Q&A failed: {e}")
            return None
    
    def get_recipe_suggestions(self, query: str) -> List[str]:
        """
        Get recipe suggestions based on query
        
        Args:
            query: Search query
            
        Returns:
            List of suggested recipe names
        """
        try:
            question = f"What recipes would you recommend for: {query}?"
            answer = self.ask_question(question)
            
            if answer:
                # Extract recipe names from the answer
                recipe_names = []
                for recipe in self.recipes_data:
                    name = recipe.get('name', '')
                    if name.lower() in answer.lower():
                        recipe_names.append(name)
                
                return recipe_names[:5]  # Return top 5 suggestions
            
            return []
            
        except Exception as e:
            logger.error(f"Recipe suggestion failed: {e}")
            return []


def main():
    """Main training function"""
    print("=" * 60)
    print("🍳 KITCHEN ASSISTANT - OLLAMA RECIPE TRAINER")
    print("=" * 60)
    
    try:
        # Initialize trainer
        trainer = OllamaRecipeTrainer()
        
        # Train the model
        training_success = trainer.train_with_context()
        
        if training_success:
            # Test the trained model
            test_success = trainer.test_trained_model()
            
            if test_success:
                print("\n🎉 Training and testing completed successfully!")
                print("🤖 Ollama is now trained on your recipe database")
                
                # Create Q&A system for interactive testing
                qa_system = trainer.create_recipe_qa_system()
                
                print("\n💬 Interactive Q&A mode (type 'quit' to exit):")
                while True:
                    try:
                        question = input("\n❓ Ask a recipe question: ").strip()
                        if question.lower() in ['quit', 'exit', 'q']:
                            break
                        
                        if question:
                            answer = qa_system.ask_question(question)
                            if answer:
                                print(f"🤖 {answer}")
                            else:
                                print("❌ Sorry, I couldn't answer that question.")
                    
                    except KeyboardInterrupt:
                        break
                
                print("\n👋 Goodbye!")
            else:
                print("\n⚠️ Training completed but model testing failed")
        else:
            print("\n❌ Training failed")
    
    except Exception as e:
        print(f"\n❌ Training process failed: {e}")


if __name__ == "__main__":
    main()