#!/usr/bin/env bash
# Runs .github/workflows/build-ipa.yml locally with nektos/act and unpacks the IPA into dist/.
#
#   scripts/build-ipa.sh                                   # release build, tests first
#   scripts/build-ipa.sh --input configuration=debug       # debug build
#   scripts/build-ipa.sh --input run_tests=false           # skip the Linux tests
#   scripts/build-ipa.sh --input publish=true --input release_notes="What's new"
#                                                          # GitHub release + AltStore source
#
# Any extra arguments go straight to act.
#
# The job runs on this machine (act's "self-hosted" mode) rather than in a container, because
# it needs the Swift toolchain, xtool and the Darwin SDK that are installed here. act refuses to
# take that setting from the project .actrc, so it's passed on the command line instead.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v act >/dev/null || { echo "act is not installed: https://nektosact.com/installation/" >&2; exit 1; }

ARTIFACTS="$ROOT/build-artifacts"
rm -rf "$ARTIFACTS"

publishing=false
case " $* " in *publish=true*) publishing=true ;; esac
secret_args=()
if $publishing; then
  # The workflow creates the release and pushes the source with this token. It's handed to act
  # through the environment (`-s NAME` reads $NAME), so it never shows up on a command line.
  GITHUB_TOKEN="$(gh auth token)" || { echo "Publishing needs the GitHub CLI logged in (gh auth login)." >&2; exit 1; }
  export GITHUB_TOKEN
  secret_args=(-s GITHUB_TOKEN)
  [ -z "$(git status --porcelain)" ] || { echo "Commit your changes before publishing." >&2; exit 1; }
  git push -q origin HEAD:main
fi

act workflow_dispatch \
  --workflows .github/workflows/build-ipa.yml \
  -P ubuntu-latest=-self-hosted \
  --artifact-server-path "$ARTIFACTS" \
  "${secret_args[@]}" \
  "$@" </dev/null  # no input: anything that prompts fails fast instead of hanging

if $publishing; then
  # The workflow committed the updated source in act's copy and pushed it; bring it here too.
  git pull -q --ff-only origin main
  echo "AltStore source updated: altstore/source.json"
fi

zip_file="$(find "$ARTIFACTS" -name 'splitter-ipa.zip' -print -quit)"
[ -n "$zip_file" ] || { echo "No IPA artifact was produced." >&2; exit 1; }

mkdir -p dist
unzip -o -q "$zip_file" -d dist
(cd dist && for sum in *.sha256; do sha256sum -c "$sum"; done)
echo
echo "Installer(s) in $ROOT/dist:"
ls -1t dist/*.ipa | head -5
