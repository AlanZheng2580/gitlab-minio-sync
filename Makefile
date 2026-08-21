.PHONY: up down bootstrap demo verify logs

up:
	./scripts/start.sh

down:
	docker compose down

bootstrap:
	./scripts/bootstrap.sh

demo:
	./scripts/demo.sh

verify:
	./scripts/verify.sh

logs:
	docker compose logs -f --tail=100
