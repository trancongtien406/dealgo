#!/bin/sh
# Build/refresh the Vietnam Photon index into /photon (volume dealgo_photon).
# Downloads the weekly GraphHopper Vietnam JSON dump (Photon 1.x format) and imports it at low CPU priority.
set -eu
DUMP_URL="${PHOTON_DUMP_URL:-https://download1.graphhopper.com/public/asia/vietnam/photon-dump-vietnam-1.0-latest.jsonl.zst}"
TMP=/photon/import.jsonl.zst
echo "downloading $DUMP_URL"
curl -fsSL -o "$TMP" "$DUMP_URL"
curl -fsSL "$DUMP_URL.md5" | awk '{print $1"  '"$TMP"'"}' | md5sum -c -
rm -rf /photon/photon_data.new
mkdir -p /photon/photon_data.new
zstd --stdout -d "$TMP" | nice -n 19 java $JAVA_OPTS -jar /opt/photon.jar import \
  -data-dir /photon/photon_data.new -import-file - -country-codes vn -languages vi,en
# photon writes <data-dir>/photon_data
rm -rf /photon/photon_data.old
[ -d /photon/photon_data ] && mv /photon/photon_data /photon/photon_data.old
mv /photon/photon_data.new/photon_data /photon/photon_data
rm -rf /photon/photon_data.new /photon/photon_data.old "$TMP"
echo "import done"
