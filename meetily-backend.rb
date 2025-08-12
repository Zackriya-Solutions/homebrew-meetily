class MeetilyBackend < Formula
  desc "FastAPI backend for Meetily meeting transcription and analysis"
  homepage "https://github.com/Zackriya-Solutions/meeting-minutes"
  url "https://github.com/Zackriya-Solutions/meeting-minutes/archive/refs/heads/main.zip"
  version "0.0.5"
  sha256 "f6453947bfb90ecce91990f898e46f3f94d96b3eecba6176b9adea4efb989c70"

  depends_on "cmake" => :build
  depends_on "llvm" => :build
  depends_on "libomp" => :build
  depends_on "python@3.9"
  depends_on "ffmpeg"
  depends_on "git"

  def backup_existing_data_if_present
    # Check if user is upgrading from old version that stored data in installation directory
    # During upgrade, Homebrew keeps the old version until the new one is successfully installed
    old_cellar = "#{HOMEBREW_CELLAR}/meetily-backend"
    
    if Dir.exist?(old_cellar)
      # Find version directories (excluding the current one being installed)
      versions = Dir.glob("#{old_cellar}/*").select { |d| File.directory?(d) && File.basename(d) != version.to_s }
      
      if !versions.empty?
        # Sort by modification time and get the most recent old version
        latest_old_version = versions.max_by { |d| File.mtime(d) }
        old_backend_dir = "#{latest_old_version}/backend"
        
        ohai "Checking for data migration from #{File.basename(latest_old_version)}"
        
        if Dir.exist?(old_backend_dir)
          # Create var directories if they don't exist
          mkdir_p "#{var}/meetily"
          
          migrated_any = false
          
          # Migrate database if it exists and we don't already have one in var
          old_db = "#{old_backend_dir}/meeting_minutes.db"
          new_db = "#{var}/meetily/meeting_minutes.db"
          
          if File.exist?(old_db) && !File.exist?(new_db)
            cp old_db, new_db
            ohai "✅ Database migrated from #{File.basename(latest_old_version)} (#{File.size(old_db)} bytes)"
            migrated_any = true
          elsif File.exist?(old_db) && File.exist?(new_db)
            ohai "📋 Database already exists in var directory, keeping existing data"
          end
          
          # Migrate transcripts directory if it exists and has content
          old_transcripts = "#{old_backend_dir}/transcripts"
          new_transcripts = "#{var}/meetily/transcripts"
          
          if Dir.exist?(old_transcripts) && !Dir.empty?(old_transcripts)
            mkdir_p new_transcripts
            # Only copy files that don't already exist
            Dir["#{old_transcripts}/*"].each do |file|
              filename = File.basename(file)
              dest_file = "#{new_transcripts}/#{filename}"
              if !File.exist?(dest_file)
                cp file, dest_file
                migrated_any = true
              end
            end
            if migrated_any
              ohai "✅ Transcripts migrated from #{File.basename(latest_old_version)}"
            end
          end
          
          # Migrate chroma directory if it exists and has content
          old_chroma = "#{old_backend_dir}/chroma"
          new_chroma = "#{var}/meetily/chroma"
          
          if Dir.exist?(old_chroma) && !Dir.empty?(old_chroma)
            mkdir_p new_chroma
            # Only copy files that don't already exist
            Dir["#{old_chroma}/*"].each do |file|
              filename = File.basename(file)
              dest_file = "#{new_chroma}/#{filename}"
              if !File.exist?(dest_file)
                if File.directory?(file)
                  cp_r file, dest_file
                else
                  cp file, dest_file
                end
                migrated_any = true
              end
            end
            if migrated_any
              ohai "✅ Vector database migrated from #{File.basename(latest_old_version)}"
            end
          end
          
          if migrated_any
            ohai "🎉 Data migration completed successfully!"
            ohai "💾 Your meeting data is now stored in #{var}/meetily/ and will persist across upgrades"
          else
            ohai "📋 No new data found to migrate"
          end
        end
      else
        ohai "📱 Fresh installation - no previous data to migrate"
      end
    else
      ohai "📱 Fresh installation - no previous Meetily backend found"
    end
  end

  def install
    # CRITICAL: Backup data from previous installation before proceeding
    backup_existing_data_if_present
    
    # Create necessary directories
    mkdir_p "#{prefix}/backend"
    mkdir_p "#{prefix}/backend/app"
    mkdir_p "#{prefix}/backend/whisper-server-package/models"
    
    # Create persistent data directories in var (survives upgrades)
    mkdir_p "#{var}/meetily/transcripts"
    mkdir_p "#{var}/meetily/chroma"
    
    # Create symlinks so app finds data in expected locations
    ln_sf "#{var}/meetily/transcripts", "#{prefix}/backend/transcripts"
    ln_sf "#{var}/meetily/chroma", "#{prefix}/backend/chroma"
    
    # For the database, we need to handle it differently since it may or may not exist
    # Create a symlink from the backend directory to the var directory
    # The application will create the database file in the var directory when needed
    db_target = "#{var}/meetily/meeting_minutes.db"
    db_link = "#{prefix}/backend/meeting_minutes.db"
    
    # If a database already exists in var (from migration), don't overwrite
    # If no database exists, the symlink will be ready for when the app creates it
    if !File.exist?(db_target)
      # Create an empty file so the symlink target exists
      touch db_target
    end
    ln_sf db_target, db_link

    # Copy backend files
    cp_r "backend/app", "#{prefix}/backend/"
    cp_r "backend/whisper-custom", "#{prefix}/backend/"
    cp "backend/requirements.txt", "#{prefix}/backend/"
    cp "backend/.env", "#{prefix}/backend/" if File.exist?("backend/.env")
    cp "backend/download-ggml-model.sh", "#{prefix}/backend/"
    
    # Ensure transcript_processor module is copied if it exists
    if File.exist?("backend/transcript_processor.py")
      cp "backend/transcript_processor.py", "#{prefix}/backend/app/"
      ohai "Copied transcript_processor module to app directory"
    end

    # Create virtual environment and install dependencies
    system "python3", "-m", "venv", "#{prefix}/backend/venv"
    system "#{prefix}/backend/venv/bin/pip", "install", "--upgrade", "pip"
    system "#{prefix}/backend/venv/bin/pip", "install", "-r", "#{prefix}/backend/requirements.txt"

    # Build whisper.cpp from source
    # Use a specific version tag to ensure compatibility with our custom code
    mkdir_p "#{buildpath}/whisper.cpp"
    system "git", "clone", "--branch", "master", "--depth", "1", "https://github.com/Zackriya-Solutions/whisper.cpp.git", "#{buildpath}/whisper.cpp"
    
    # Copy custom server files - make sure we're copying all necessary files
    cp_r Dir["backend/whisper-custom/server/*"], "#{buildpath}/whisper.cpp/examples/server/"
    
    # Create necessary directories for the package
    mkdir_p "#{prefix}/backend/whisper-server-package"
    mkdir_p "#{prefix}/backend/whisper-server-package/models"
    
    # Build with CMake - following the approach in build_whisper.sh
    cd "#{buildpath}/whisper.cpp" do
      # Clean any previous build artifacts
      rm_rf "build"
      mkdir_p "build"
      
      cd "build" do
        # Build with static linking to avoid dependency issues
        system "cmake", "-DCMAKE_C_FLAGS=-w", "-DCMAKE_CXX_FLAGS=-w", "-DBUILD_SHARED_LIBS=OFF", ".."
        system "make", "-j4"
      end
      
      # Check if server binary was built successfully
      if File.exist?("build/bin/whisper-server")
        # Copy server binary to package directory
        cp "build/bin/whisper-server", "#{prefix}/backend/whisper-server-package/"
        
        # Also copy the libwhisper library if it exists
        if File.exist?("build/lib/libwhisper.1.dylib")
          cp "build/lib/libwhisper.1.dylib", "#{prefix}/backend/whisper-server-package/"
          # Fix the RPATH in the binary
          system "install_name_tool", "-add_rpath", "@executable_path", "#{prefix}/backend/whisper-server-package/whisper-server"
        end
        
        ohai "Whisper server binary copied successfully"
      else
        # If the build fails, try using the pre-compiled binary if available
        ohai "Whisper server build failed, checking for pre-compiled binary"
        if File.exist?("../backend/whisper-server-package/whisper-server")
          cp "../backend/whisper-server-package/whisper-server", "#{prefix}/backend/whisper-server-package/"
          # Also copy the libwhisper library if it exists
          if File.exist?("../backend/whisper-server-package/libwhisper.1.dylib")
            cp "../backend/whisper-server-package/libwhisper.1.dylib", "#{prefix}/backend/whisper-server-package/"
            # Fix the RPATH in the binary
            system "install_name_tool", "-add_rpath", "@executable_path", "#{prefix}/backend/whisper-server-package/whisper-server"
          end
          ohai "Using pre-compiled whisper-server binary"
        else
          opoo "No pre-compiled whisper-server binary found. The formula installation will continue, but the server may not work."
        end
      end
      
      # Create run script exactly as in build_whisper.sh
      (prefix/"backend/whisper-server-package/run-server.sh").write <<~EOS
        #!/bin/bash

        # Default configuration
        HOST="127.0.0.1"
        PORT="8178"
        MODEL="models/ggml-small.bin"
        LANGUAGE="en"

        # Parse command line arguments
        while [[ $# -gt 0 ]]; do
            case $1 in
                --host)
                    HOST="$2"
                    shift 2
                    ;;
                --port)
                    PORT="$2"
                    shift 2
                    ;;
                --model)
                    MODEL="$2"
                    shift 2
                    ;;
                --language)
                    LANGUAGE="$2"
                    shift 2
                    ;;
                *)
                    echo "Unknown option: $1"
                    exit 1
                    ;;
            esac
        done

        # Run the server
        ./whisper-server \\
            --model "$MODEL" \\
            --host "$HOST" \\
            --port "$PORT" \\
            --language "$LANGUAGE" \\
            --diarize \\
            --print-progress
      EOS
      
      # Make the run script executable
      chmod 0755, "#{prefix}/backend/whisper-server-package/run-server.sh"
    end

    # Create run scripts - update names to include backend
    (bin/"meetily-download-model").write <<~EOS
      #!/bin/bash
      cd #{prefix}/backend
      MODEL_SHORT_NAME=$1
      if [ -z "$MODEL_SHORT_NAME" ]; then
        echo "Please specify a model name (e.g. small, medium, base)"
        exit 1
      fi
      
      # Ensure the models directory exists
      mkdir -p whisper-server-package/models
      
      echo "Downloading ggml model $MODEL_SHORT_NAME from 'https://huggingface.co/ggerganov/whisper.cpp' ..."
      ./download-ggml-model.sh $MODEL_SHORT_NAME
      
      if [ -f "ggml-$MODEL_SHORT_NAME.bin" ]; then
        # Move the downloaded model to the models directory
        mv "ggml-$MODEL_SHORT_NAME.bin" "whisper-server-package/models/"
        echo "Done! Model '$MODEL_SHORT_NAME' saved in 'whisper-server-package/models/ggml-$MODEL_SHORT_NAME.bin'"
        echo "You can now start the Meetily backend server with: meetily-server"
      else
        echo "Failed to download model. Please try again later."
        exit 1
      fi
    EOS

    (bin/"meetily-server").write <<~EOS
      #!/bin/bash

      # Color codes
      GREEN='\\033[0;32m'
      BLUE='\\033[0;34m'
      YELLOW='\\033[1;33m'
      RED='\\033[0;31m'
      NC='\\033[0m' # No Color

      # Default values
      MODEL_NAME=""
      LANGUAGE="en"
      HOST="127.0.0.1"
      PORT_WHISPER="8178"
      PORT_FASTAPI="5167"

      # Help message
      function show_help {
        echo "Usage: meetily-server [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -m, --model NAME     Specify the model name to use (tiny, base, small, medium, large-v3)"
        echo "  -l, --language LANG  Specify the language code (default: en)"
        echo "  -h, --help           Show this help message"
        echo ""
        echo "Examples:"
        echo "  meetily-server --model medium --language fr"
        echo "  meetily-server -m small -l de"
        exit 0
      }

      # Parse command line arguments
      while [[ $# -gt 0 ]]; do
        case $1 in
          -m|--model)
            MODEL_NAME="$2"
            shift 2
            ;;
          -l|--language)
            LANGUAGE="$2"
            shift 2
            ;;
          -h|--help)
            show_help
            ;;
          *)
            echo -e "${RED}[ERROR] Unknown option: $1${NC}"
            show_help
            ;;
        esac
      done

      # Set paths
      BACKEND_DIR="#{prefix}/backend"
      WHISPER_DIR="$BACKEND_DIR/whisper-server-package"
      MODEL_DIR="$WHISPER_DIR/models"

      # Create models directory if it doesn't exist
      echo -e "[INFO] Creating models directory..."
      mkdir -p "$MODEL_DIR"

      # Check for Whisper models and handle model selection
      echo -e "[INFO] Checking for Whisper models..."
      
      # If a specific model was requested, try to use or download it first
      if [ -n "$MODEL_NAME" ]; then
        echo -e "[INFO] Requested model: $MODEL_NAME"
        
        # Check if the requested model already exists
        if [ -f "$MODEL_DIR/ggml-$MODEL_NAME.bin" ]; then
          echo -e "[SUCCESS] Found requested model: ggml-$MODEL_NAME.bin"
          MODEL="$MODEL_DIR/ggml-$MODEL_NAME.bin"
        else
          # Try to download the requested model
          echo -e "[INFO] Requested model not found. Attempting to download model: $MODEL_NAME"
          cd "$BACKEND_DIR"
          ./download-ggml-model.sh "$MODEL_NAME"
          
          if [ -f "$BACKEND_DIR/ggml-$MODEL_NAME.bin" ]; then
            mv "$BACKEND_DIR/ggml-$MODEL_NAME.bin" "$MODEL_DIR/"
            MODEL="$MODEL_DIR/ggml-$MODEL_NAME.bin"
            echo -e "[SUCCESS] Downloaded requested model: ggml-$MODEL_NAME.bin"
          else
            echo -e "[ERROR] Failed to download requested model: $MODEL_NAME"
            # Don't fall back to small automatically - let the user know
            echo -e "[INFO] Please try downloading the model manually with: meetily-download-model $MODEL_NAME"
            exit 1
          fi
        fi
      else
        # No specific model requested, check if any models exist
        MODEL_COUNT=$(find "$MODEL_DIR" -name "ggml-*.bin" | wc -l)
        
        if [ "$MODEL_COUNT" -eq 0 ]; then
          # No models found, download small as default
          echo -e "[INFO] No models found. Downloading the small model as default..."
          cd "$BACKEND_DIR"
          ./download-ggml-model.sh small
          
          if [ -f "$BACKEND_DIR/ggml-small.bin" ]; then
            mv "$BACKEND_DIR/ggml-small.bin" "$MODEL_DIR/"
            MODEL="$MODEL_DIR/ggml-small.bin"
            echo -e "[SUCCESS] Downloaded default model: ggml-small.bin"
          else
            echo -e "[ERROR] Failed to download default model."
            echo -e "[INFO] Please try downloading a model manually with: meetily-download-model [model_name]"
            exit 1
          fi
        else
          # Use the first available model
          MODEL=$(find "$MODEL_DIR" -name "ggml-*.bin" | head -n 1)
          MODEL_BASENAME=$(basename "$MODEL")
          echo -e "[INFO] Using existing model: $MODEL_BASENAME"
        fi
      fi
      
      # Final check to ensure we have a valid model
      if [ -z "$MODEL" ]; then
        echo -e "[ERROR] No model found or specified. Please run meetily-download-model first."
        exit 1
      fi
      
      MODEL_BASENAME=$(basename "$MODEL")
      echo -e "[SUCCESS] Using model: $MODEL_BASENAME"

      # Start Whisper server
      echo -e "[INFO] Starting Whisper server..."
      cd "$WHISPER_DIR"
      
      # Check if libwhisper.1.dylib exists in the same directory
      if [ ! -f "$WHISPER_DIR/libwhisper.1.dylib" ] && [ -f "$BACKEND_DIR/whisper-custom/libwhisper.1.dylib" ]; then
        echo -e "[INFO] Copying libwhisper.1.dylib from whisper-custom directory..."
        cp "$BACKEND_DIR/whisper-custom/libwhisper.1.dylib" "$WHISPER_DIR/"
      fi
      
      # Try to fix RPATH if needed
      if [ -f "$WHISPER_DIR/whisper-server" ] && [ -f "$WHISPER_DIR/libwhisper.1.dylib" ]; then
        echo -e "[INFO] Fixing RPATH in whisper-server binary..."
        install_name_tool -add_rpath "@executable_path" "$WHISPER_DIR/whisper-server" 2>/dev/null || true
      fi
      
      # Start the server with error handling
      ./run-server.sh --model "$MODEL" --host "$HOST" --port "$PORT_WHISPER" --language "$LANGUAGE" &
      WHISPER_PID=$!
      
      # Wait a moment to see if the server starts successfully
      sleep 2
      
      # Check if the process is still running
      if ! kill -0 $WHISPER_PID 2>/dev/null; then
        echo -e "[ERROR] Whisper server failed to start. Please check the logs."
        echo -e "[INFO] Checking whisper-server binary..."
        file "$WHISPER_DIR/whisper-server"
        echo -e "[INFO] You can try running it manually with:"
        echo -e "cd $WHISPER_DIR && ./run-server.sh --model $MODEL"
        
        # Try to build a static version as a fallback
        echo -e "[INFO] Attempting to build a static version of whisper-server..."
        cd "$BACKEND_DIR"
        mkdir -p whisper-static-build && cd whisper-static-build
        
        # Clone the repo
        git clone --depth 1 https://github.com/Zackriya-Solutions/whisper.cpp.git .
        
        # Copy custom server files
        cp -r "$BACKEND_DIR/whisper-custom/server/"* examples/server/
        
        # Build with static linking
        mkdir -p build && cd build
        cmake -DCMAKE_C_FLAGS="-w" -DCMAKE_CXX_FLAGS="-w" -DBUILD_SHARED_LIBS=OFF ..
        make -j4
        
        # Check if build succeeded
        if [ -f "bin/whisper-server" ]; then
          echo -e "[SUCCESS] Static build successful, replacing whisper-server..."
          cp bin/whisper-server "$WHISPER_DIR/"
          chmod +x "$WHISPER_DIR/whisper-server"
          
          # Try starting the server again
          cd "$WHISPER_DIR"
          ./run-server.sh --model "$MODEL" --host "$HOST" --port "$PORT_WHISPER" --language "$LANGUAGE" &
          WHISPER_PID=$!
          sleep 2
        else
          echo -e "[ERROR] Static build failed. Please report this issue."
        fi
      fi
      
      # Start Python backend
      echo -e "[INFO] Starting Python backend..."
      cd "$BACKEND_DIR"
      source venv/bin/activate
      
      # Fix the Python import paths
      echo -e "[INFO] Fixing Python import paths..."
      
      # Fix db import in main.py
      if grep -q "from db import" "$BACKEND_DIR/app/main.py"; then
        sed -i.bak 's/from db import/from app.db import/g' "$BACKEND_DIR/app/main.py"
        echo -e "[SUCCESS] Fixed db import path in main.py"
      fi
      
      # Fix db import in transcript_processor.py
      if grep -q "from db import" "$BACKEND_DIR/app/transcript_processor.py"; then
        sed -i.bak 's/from db import/from app.db import/g' "$BACKEND_DIR/app/transcript_processor.py"
        echo -e "[SUCCESS] Fixed db import path in transcript_processor.py"
      fi
      
      # Fix Process_transcrip import
      if grep -q "from Process_transcrip import" "$BACKEND_DIR/app/main.py"; then
        sed -i.bak 's/from Process_transcrip import/from app.Process_transcrip import/g' "$BACKEND_DIR/app/main.py"
        echo -e "[SUCCESS] Fixed Process_transcrip import path"
      fi
      
      # Fix transcript_processor import
      if grep -q "from transcript_processor import" "$BACKEND_DIR/app/main.py"; then
        sed -i.bak 's/from transcript_processor import/from app.transcript_processor import/g' "$BACKEND_DIR/app/main.py"
        echo -e "[SUCCESS] Fixed transcript_processor import path"
      fi
      
      # Run the Python backend
      python -m uvicorn app.main:app --host 0.0.0.0 --port 5167 &
      PYTHON_PID=$!

      # Print success message
      echo -e "${GREEN}Meetily backend started!${NC}"
      echo -e "${BLUE}Whisper Server running on http://localhost:8178${NC}"
      echo -e "${BLUE}FastAPI Backend running on http://localhost:5167${NC}"
      echo -e "${GREEN}API Documentation available at http://localhost:5167/docs${NC}"
      echo -e "${BLUE}Press Ctrl+C to stop all services${NC}"
      
      # Cleanup function to ensure all processes are terminated
      function cleanup {
        echo -e "${YELLOW}Shutting down Meetily services...${NC}"
        
        # Kill the Whisper server process
        if [ -n "$WHISPER_PID" ] && kill -0 $WHISPER_PID 2>/dev/null; then
          echo -e "${BLUE}Stopping Whisper server...${NC}"
          kill -TERM $WHISPER_PID 2>/dev/null || kill -KILL $WHISPER_PID 2>/dev/null
        fi
        
        # Kill the Python backend process
        if [ -n "$PYTHON_PID" ] && kill -0 $PYTHON_PID 2>/dev/null; then
          echo -e "${BLUE}Stopping FastAPI backend...${NC}"
          kill -TERM $PYTHON_PID 2>/dev/null || kill -KILL $PYTHON_PID 2>/dev/null
        fi
        
        # Find and kill any orphaned whisper-server processes
        ORPHANED_WHISPER=$(pgrep -f "whisper-server")
        if [ -n "$ORPHANED_WHISPER" ]; then
          echo -e "${YELLOW}Cleaning up orphaned Whisper server processes...${NC}"
          pkill -f "whisper-server"
        fi
        
        # Find and kill any orphaned uvicorn processes related to our app
        ORPHANED_UVICORN=$(pgrep -f "uvicorn app.main:app")
        if [ -n "$ORPHANED_UVICORN" ]; then
          echo -e "${YELLOW}Cleaning up orphaned FastAPI processes...${NC}"
          pkill -f "uvicorn app.main:app"
        fi
        
        echo -e "${GREEN}All Meetily services stopped.${NC}"
        exit 0
      }
      
      # Register the cleanup function for various signals
      trap cleanup INT TERM QUIT HUP
      
      # Wait for Ctrl+C or other termination signal
      wait $WHISPER_PID $PYTHON_PID
      
      # If we get here, one of the processes has terminated unexpectedly
      # Run cleanup to ensure everything is properly shut down
      cleanup
    EOS

    chmod 0755, bin/"meetily-download-model"
    chmod 0755, bin/"meetily-server"
    
    ohai "Meetily Backend installation complete! Run 'meetily-download-model medium' to download a model, then 'meetily-server' to start the server."
  end

  def post_install
    # Migrate existing database if it exists in the old location
    old_db = "#{prefix}/backend/meeting_minutes.db"
    new_db = "#{var}/meetily/meeting_minutes.db"
    
    if File.exist?(old_db) && !File.exist?(new_db)
      ohai "Migrating existing database to persistent location"
      cp old_db, new_db
      rm old_db
      ln_sf new_db, old_db
      ohai "Database migration complete"
    elsif !File.exist?(old_db) && File.exist?(new_db)
      # Create symlink if database exists in var but not in backend
      ln_sf new_db, old_db
    end
  end

  def caveats
    <<~EOS
      Meetily Backend has been installed!
      
      📁 Data is stored in #{var}/meetily/ and persists across upgrades!
      
      To download a Whisper model:
        meetily-download-model [model_name]
      
      Available models: tiny, base, small, medium, large-v3, etc.
      
      To start the Meetily Backend server:
        meetily-server
      
      The server will be available at:
        - Whisper Server: http://localhost:8178
        - FastAPI Backend: http://localhost:5167
        - API Documentation: http://localhost:5167/docs
      
      If you want to update your API keys for meeting analysis:
        echo "ANTHROPIC_API_KEY=your_key_here" > #{prefix}/backend/.env
        echo "GROQ_API_KEY=your_key_here" >> #{prefix}/backend/.env
        echo "OPENAI_API_KEY=your_key_here" >> #{prefix}/backend/.env
      
      Ollama should be running for local LLM support:
        brew install ollama
        ollama pull mistral
        
      For the complete Meetily experience, install the frontend application:
        brew install --cask meetily
    EOS
  end

  test do
    system "#{bin}/meetily-download-model", "--help"
    # Add more tests as needed
  end
end 