#!/usr/bin/env bash
source "$(dirname "$0")/../helpers/lib.sh"

plex_data_dir="/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/"
backup_location='/mnt/kingpin/Backup/plex.tar.gz'

# check_root

echo "Creating backup archive into ${backup_location}"
tar --create --gzip --verbose --exclude="Cache" --exclude="Metadata" --file="${backup_location}" "${plex_data_dir}"
echo "Finished. Backup can be found at ${backup_location}"

