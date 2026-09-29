# Battlecode 2025 on Softmax

Runs the original [Battlecode 2025 Java engine](https://github.com/battlecode/battlecode25)
and both players in one JVM inside one Coworld game container. The game uses
Softmax's existing `game-hosted` runtime.

Engine revision `28975a487c1a30ed2b5bed644fe6ecd2c3dd1482` is the official
`engine.3.1.2` release. Its Java sources, maps, seeds, tiebreaks, instrumenting
classloaders, bytecode budgets and cumulative 20-minute team clocks are unchanged.
The vanished JSI dependency is recovered from the hash-pinned official 1.0.0
release; only the dependency location in the Gradle build changes. The outer JVM
watchdog is 50 minutes and the hosted episode limit is 60 minutes. Hardware,
scheduling and these outer limits mean tournament outcomes are not guaranteed identical.

## Submit your player

Use Java 21 and the **`java/` directory** of the
[official 2025 scaffold](https://github.com/battlecode/battlecode25-scaffold).
Build and upload the original `submission.zip` unchanged. No metadata or Java
source edits are needed. The separate experimental Python engine is not supported.

```sh
uv venv --python 3.12 .venv-softmax
uv pip install --python .venv-softmax/bin/python 'coworld[auth]'
source .venv-softmax/bin/activate
softmax login
coworld player list
coworld player use ply_YOUR_PLAYER_ID
bash ./gradlew --no-daemon zipForSubmit
coworld upload-policy --file submission.zip --name "My Battlecode Player"
coworld submit "My Battlecode Player:v1" --league LEAGUE_ID \
  --preference package=myplayer
```

Select your identity **before uploading**, use the exact policy version returned,
and replace `myplayer` with your case-sensitive Java package. Multiple historical
packages can remain in the ZIP; the league preference selects the entrypoint.
If you only have Java sources, place them under the scaffold's `java/src/` first.
ZIP limits are 32 MiB compressed, 128 MiB expanded and 10,000 entries.

## Reproduce archived players

```sh
python3 scripts/build_submissions.py
```

Requires Python 3, Git and Docker. The helper checks out the 12 pinned archives in
[players/archives.json](players/archives.json), runs their original `zipForSubmit`
tasks in Java 21 containers, and copies untouched ZIPs to
`artifacts/scaffold-policies/`. Logs and provenance record revisions, hashes and
restored scaffold files. Source-only archives use the official scaffold at
`40dbb9b28e75ef5aa4b47dc0ca74bc73ecc3012f`. Om Nom's unchanged Jinja generator runs
first, following its `make zip` mode. No player Java source is rewritten.

Use each catalog entry's package when submitting. Selection notes distinguish
explicit tournament snapshots from inferred current versions; not every archive
identifies its final tournament entrypoint. ZIP timestamps may vary across builds.
The helper does not upload policies or change league identities.

## Build and verify

Use current Coworld tooling with game-hosted file-player support.

```sh
coworld build --version 0.1.0 --output coworld_manifest.json
coworld certify coworld_manifest.json --timeout-seconds 300 --no-open-report
PYTHONPATH=src python3 -m unittest discover -s tests -v
```

The build includes the original browser viewer and scaffold example. For native
Apple Silicon testing, build `docker build --platform linux/arm64 -t
coworld-battlecode-2025:native .`; the hosted release is linux/amd64. Run
`scripts/smoke.py` with `--scaffold PATH_TO_JAVA_SCAFFOLD`, `--spaark PATH_TO_ARCHIVE`,
`--image IMAGE`, and a fresh `--output DIRECTORY` to exercise identical packages,
an archive player, bytecode enforcement and compilation failure attribution.

## Runtime and replay

Softmax stages policy files before the game starts. The wrapper reads
`COGAME_CONFIG_URI` and `COGAME_PLAYER_SEATS_URI`, verifies hashes, extracts each
seat separately, and compiles only its selected entrypoint and referenced sources.
Uploaded build scripts, annotation processors and precompiled classes do not run.
Bundled `battlecode/` sources are ignored so the pinned engine supplies the API.
The image runs as root to write the runner's staged output directories; Linux
capabilities are dropped and the original JVM instrumentation remains active.

Slots 0/1 are teams A/B. Winners receive 1, losers 0. Results come from the native
`.bc25` replay, not player stdout, and include engine revision, packages and ZIP
hashes. Compilation errors are attributed to the failing seat and its private log.
Replays and logs are written before the results completion marker.

The original client has small replay-URL, autoplay and loop integration changes.
The live page shows match status; live board streaming and robot `println` logs
are not exposed. Native replays also work in the original Battlecode client.

For standalone Docker execution, `battlecode2025 run --request REQUEST --output
OUTPUT` accepts `{"version":1,"players":[{"uri":"...","package":"myplayer"},
{"uri":"...","package":"opponent"}],"game_config":{"map":"DefaultSmall"}}`.
The output directory must be empty.

Publish with `coworld upload-coworld coworld_manifest.json --wait-certification`.
The separate 2025 league uses Coworld-owned archive bots, mirrored two-seat
matches and Elo ranking. Keep new league rounds paused until certification and
real archived-player matches pass.

This repository and scaffold example are GPL-3.0. Archived players retain their
upstream provenance and licenses.
