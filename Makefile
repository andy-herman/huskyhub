# HuskyHub — Developer helpers
# Usage: make <target>
#
# Targets:
#   up        Start all containers (build if needed)
#   down      Stop containers, keep data volumes
#   reset     Wipe all volumes and rebuild from scratch
#   logs      Tail all container logs
#   ai-setup  Download the Ollama model required for Week 9
#   shell-db  Open a MySQL shell inside the database container

.PHONY: up down reset logs ai-setup shell-db

up:
	docker compose up --build

down:
	docker compose down

reset:
	@echo "WARNING: This deletes all database data and rebuilds from init.sql"
	docker compose down -v
	docker compose up --build

logs:
	docker compose logs -f

ai-setup:
	docker compose --profile ai up -d
	docker exec -it huskyhub-ollama ollama pull llama3.2
	docker compose restart huskyhub-flask
	@echo "Ollama model ready. Navigate to /chatbot to test."

shell-db:
	docker exec -it huskyhub-db mysql -u user -psupersecretpw huskyhub
