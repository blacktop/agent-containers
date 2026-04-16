.PHONY: bump sync

## bump: increment patch version and commit for release
bump:
	@./build/increment-patch.sh
	@version=$$(jq -r .version src/features/firewall/devcontainer-feature.json) && \
		git add src/ && \
		git commit -m "chore: Bump version to $$version" && \
		echo "Bumped to $$version — push to main to trigger release"

## sync: pull Claude session history from running/stopped devcontainers to host
sync:
	@./build/sync-sessions.sh
