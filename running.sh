# 1. Start the lab environment in background
docker compose up -d

# 2. Run the setup script inside your local shell (not in Docker)
./setup_lab.sh

# 3. Run the dev workflow script
./dev_workflow.sh
