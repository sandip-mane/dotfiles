.PHONY: bootstrap sync stow macos local-ai

bootstrap:
	./bootstrap.sh

sync:
	./sync.sh

stow:
	@for pkg in packages/*/; do stow -d packages -t "$(HOME)" -R "$$(basename $$pkg)"; done

macos:
	./macos.sh

local-ai:
	./local-ai.sh
