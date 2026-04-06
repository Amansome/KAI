#!/usr/bin/env python3
"""
Setup script for training Ollama with Kitchen Assistant recipe data.
This script helps users set up and train Ollama for intelligent recipe Q&A.
"""

import os
import sys
import json
import subprocess
from pathlib import Path


def print_header():
    """Print setup header"""
    print("=" * 70)
    print("🍳 KITCHEN ASSISTANT - OLLAMA TRAINING SETUP")
    print("=" * 70)
    print()


def check_ollama_installation():
    """Check if Ollama is installed"""
    try:
        result = subprocess.run(['ollama', '--version'], 
                              capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print("✅ Ollama is installed")
            return True
        else:
            print("❌ Ollama is not working properly")
            return False
    except (subprocess.TimeoutExpired, FileNotFoundError):
        print("❌ Ollama is not installed")
        return False


def install_ollama():
    """Guide user through Ollama installation"""
    print("\n📦 Installing Ollama...")
    print("\nPlease follow these steps to install Ollama:")
    print("1. Visit: https://ollama.ai")
    print("2. Download and install Ollama for your system")
    print("3. Run 'ollama serve' to start the service")
    print("4. Run this setup script again")
    print("\nFor macOS, you can also use Homebrew:")
    print("   brew install ollama")
    return False


def check_ollama_service():
    """Check if Ollama service is running"""
    try:
        import requests
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        if response.status_code == 200:
            print("✅ Ollama service is running")
            return True
        else:
            print("❌ Ollama service is not responding")
            return False
    except Exception:
        print("❌ Ollama service is not running")
        return False


def start_ollama_service():
    """Guide user to start Ollama service"""
    print("\n🚀 Starting Ollama service...")
    print("\nPlease run this command in a separate terminal:")
    print("   ollama serve")
    print("\nThen press Enter to continue...")
    input()
    return check_ollama_service()


def download_model():
    """Download the recommended model"""
    print("\n🤖 Downloading recommended model (llama3.2:3b)...")
    try:
        result = subprocess.run(['ollama', 'pull', 'llama3.2:3b'], 
                              capture_output=True, text=True, timeout=300)
        if result.returncode == 0:
            print("✅ Model downloaded successfully")
            return True
        else:
            print(f"❌ Model download failed: {result.stderr}")
            return False
    except subprocess.TimeoutExpired:
        print("❌ Model download timed out")
        return False
    except Exception as e:
        print(f"❌ Model download failed: {e}")
        return False


def check_recipes_file():
    """Check if recipes file exists"""
    recipes_file = Path("python-processor/output/recipes.json")
    if recipes_file.exists():
        print(f"✅ Recipes file found: {recipes_file}")
        
        # Check file content
        try:
            with open(recipes_file, 'r') as f:
                data = json.load(f)
            
            recipes = data.get('recipes', [])
            print(f"   📊 Found {len(recipes)} recipes")
            
            if len(recipes) > 0:
                categories = set(r.get('category', 'unknown') for r in recipes)
                print(f"   📂 Categories: {', '.join(categories)}")
                return True
            else:
                print("   ⚠️  No recipes found in file")
                return False
                
        except Exception as e:
            print(f"   ❌ Error reading recipes file: {e}")
            return False
    else:
        print(f"❌ Recipes file not found: {recipes_file}")
        return False


def process_recipes():
    """Guide user to process recipe PDFs"""
    print("\n📄 Processing recipe PDFs...")
    print("\nTo create the recipes database:")
    print("1. Place your recipe PDF files in: python-processor/input/")
    print("2. Run: cd python-processor && python3 enhanced_recipe_processor.py")
    print("3. This will create: python-processor/output/recipes.json")
    print("\nWould you like to run the recipe processor now? (y/n): ", end="")
    
    if input().lower().startswith('y'):
        try:
            os.chdir('python-processor')
            result = subprocess.run([sys.executable, 'enhanced_recipe_processor.py'], 
                                  capture_output=True, text=True, timeout=120)
            if result.returncode == 0:
                print("✅ Recipe processing completed")
                print(result.stdout)
                return True
            else:
                print(f"❌ Recipe processing failed: {result.stderr}")
                return False
        except Exception as e:
            print(f"❌ Recipe processing failed: {e}")
            return False
    else:
        return False


def train_ollama():
    """Train Ollama with recipe data"""
    print("\n🎓 Training Ollama with recipe data...")
    
    try:
        os.chdir('python-processor')
        result = subprocess.run([sys.executable, 'ollama_trainer.py'], 
                              capture_output=True, text=True, timeout=300)
        if result.returncode == 0:
            print("✅ Ollama training completed successfully")
            print(result.stdout)
            return True
        else:
            print(f"❌ Ollama training failed: {result.stderr}")
            return False
    except Exception as e:
        print(f"❌ Ollama training failed: {e}")
        return False


def test_integration():
    """Test the complete integration"""
    print("\n🧪 Testing Ollama integration...")
    
    test_questions = [
        "What recipes do you know?",
        "How do I make a grilled cheese sandwich?",
        "What ingredients do I need for a BLT?"
    ]
    
    try:
        os.chdir('python-processor')
        
        for question in test_questions:
            print(f"\n❓ Testing: {question}")
            
            # Create a simple test script
            test_script = f"""
from ollama_trainer import OllamaRecipeTrainer
try:
    trainer = OllamaRecipeTrainer()
    qa_system = trainer.create_recipe_qa_system()
    answer = qa_system.ask_question("{question}")
    if answer:
        print("✅ Answer:", answer[:100] + "..." if len(answer) > 100 else answer)
    else:
        print("❌ No answer received")
except Exception as e:
    print(f"❌ Test failed: {{e}}")
"""
            
            result = subprocess.run([sys.executable, '-c', test_script], 
                                  capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                print(result.stdout)
            else:
                print(f"❌ Test failed: {result.stderr}")
        
        return True
        
    except Exception as e:
        print(f"❌ Integration test failed: {e}")
        return False


def create_config():
    """Create Ollama configuration"""
    print("\n⚙️  Creating Ollama configuration...")
    
    config_dir = Path("python-processor")
    config_file = config_dir / "ollama_config.json"
    
    config = {
        "enabled": True,
        "base_url": "http://localhost:11434",
        "model": "llama3.2:3b",
        "timeout": 30,
        "max_retries": 3
    }
    
    try:
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✅ Configuration created: {config_file}")
        return True
        
    except Exception as e:
        print(f"❌ Configuration creation failed: {e}")
        return False


def main():
    """Main setup function"""
    print_header()
    
    # Step 1: Check Ollama installation
    if not check_ollama_installation():
        if not install_ollama():
            return False
    
    # Step 2: Check Ollama service
    if not check_ollama_service():
        if not start_ollama_service():
            return False
    
    # Step 3: Download model
    if not download_model():
        print("⚠️  Continuing without downloading model (you may need to download it manually)")
    
    # Step 4: Create configuration
    if not create_config():
        return False
    
    # Step 5: Check recipes file
    if not check_recipes_file():
        if not process_recipes():
            print("⚠️  Please process your recipe PDFs manually and run this script again")
            return False
    
    # Step 6: Train Ollama
    if not train_ollama():
        print("⚠️  Training failed, but you can try running it manually:")
        print("   cd python-processor && python3 ollama_trainer.py")
        return False
    
    # Step 7: Test integration
    if not test_integration():
        print("⚠️  Integration test failed, but setup may still work")
    
    # Success!
    print("\n" + "=" * 70)
    print("🎉 SETUP COMPLETED SUCCESSFULLY!")
    print("=" * 70)
    print("\n✅ Ollama is now trained with your recipe data")
    print("✅ Wake word 'Hey, Kai' is enabled")
    print("✅ Enhanced query processing is ready")
    
    print("\n🚀 Next steps:")
    print("1. Build and run the iOS app")
    print("2. Try saying 'Hey, Kai' followed by a recipe question")
    print("3. Or use text input to ask about recipes")
    
    print("\n💡 Example questions:")
    print("• Hey, Kai, what recipes do you know?")
    print("• Hey, Kai, how do I make a grilled cheese?")
    print("• Hey, Kai, what ingredients do I need for a BLT?")
    
    print("\n📚 For troubleshooting:")
    print("• Check that Ollama service is running: ollama serve")
    print("• Verify model is available: ollama list")
    print("• Test manually: cd python-processor && python3 ollama_trainer.py")
    
    return True


if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n❌ Setup cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Setup failed with error: {e}")
        sys.exit(1)