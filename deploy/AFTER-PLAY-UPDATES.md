# After Play release retention

Packaging automatically retains the current and previous complete Windows/Web
package pair in the local build and download folders. Older generated ZIPs and
release staging directories are removed. Source assets, Git history, save files,
trailer files and unknown filenames are outside this cleanup.

The website publisher runs server cleanup only after upload checksums and health
checks succeed. It keeps the live release and its latest lower version, along
with the frontend rollback image. Newer staging releases and images belonging to
other applications or containers are preserved.

Dry run locally: `powershell -ExecutionPolicy Bypass -File tools/prune-after-play-releases.ps1`

Dry run on the server: `python3 deploy/prune-kinderparadies-releases.py`

Add `-Apply` locally or `--apply` on the server to execute the cleanup.
