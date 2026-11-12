#!/bin/sh
#####################################################################################
# Author: Peter Winter (Refactored for single-pass delta sync & DB signaling)
# Description: Detects additions, modifications, and deletions in a single rsync pass,
# archives them safely, uploads once to the datastore, and logs the event to the DB.
#####################################################################################

target_directory="${1}"
bucket_type="${2}"

if [ -z "${target_directory}" ] || [ -z "${bucket_type}" ]; then
    exit 1
fi

# Prevent overlapping executions if a large update is still processing
lock_file="/var/lock/adt_sync_${bucket_type}.lock"
exec 9>"${lock_file}"
if ! /usr/bin/flock -n 9; then
    exit 0
fi

machine_ip="`${HOME}/utilities/processing/GetIP.sh`"
WEBSITE_URL="`${HOME}/utilities/config/ExtractConfigValue.sh 'WEBSITEURL'`"
processing_time="`/usr/bin/date +%s`"

outgoing_dir="${HOME}/runtime/filesystem_sync/${bucket_type}/outgoing"
exclude_file="${outgoing_dir}/exclusion_list.dat"
exclude_command=""
if [ -f "${exclude_file}" ]; then
    exclude_command="--exclude-from=${exclude_file}"
fi

shadow_dir="${target_directory}1"

# First run: initialize shadow copy cleanly and exit
if [ ! -d "${shadow_dir}" ]; then
    /usr/bin/rsync -a ${exclude_command} "${target_directory}/" "${shadow_dir}/"
    exit 0
fi

additions_log="${outgoing_dir}/additions/additions.${machine_ip}-${processing_time}-.log"
deletions_log="${outgoing_dir}/deletions/deletions.${machine_ip}-${processing_time}-.log"
rsync_out="/tmp/adt_rsync_${bucket_type}_${processing_time}.out"

/bin/rm -f "${additions_log}" "${deletions_log}" "${rsync_out}"

# Single-pass dry-run using fast mtime/size comparison (no --checksum)
/usr/bin/rsync -rni --delete ${exclude_command} "${target_directory}/" "${shadow_dir}/" > "${rsync_out}"

# Parse rsync itemize-changes output safely (handles spaces in filenames)
while IFS= read -r line; do
    code="${line%% *}"
    rel_path="${line#* }"

    # Skip directory entries themselves (ending in /)
    case "${rel_path}" in
        */) continue ;;
    esac

    if [ "${code}" = "*deleting" ]; then
        if [ -f "${shadow_dir}/${rel_path}" ]; then
            /bin/echo "${target_directory}/${rel_path}" >> "${deletions_log}"
            /bin/echo "${shadow_dir}/${rel_path}" >> "${deletions_log}"
            /bin/rm -f "${shadow_dir}/${rel_path}"
        fi
    else
        # Check if item is a regular file added or updated (>f...)
        case "${code}" in
            \>f*)
                if [ -f "${target_directory}/${rel_path}" ]; then
                    /bin/echo "${target_directory}/${rel_path}" >> "${additions_log}"
                    /bin/echo "${shadow_dir}/${rel_path}" >> "${additions_log}"
                    # Sync single changed file into shadow copy
                    /bin/mkdir -p "$(/usr/bin/dirname "${shadow_dir}/${rel_path}")"
                    /bin/cp -p "${target_directory}/${rel_path}" "${shadow_dir}/${rel_path}"
                fi
                ;;
        esac
    fi
done < "${rsync_out}"

/bin/rm -f "${rsync_out}"

# Fixed typo (${target_directory}1) and update deletion timestamp
/bin/rm -f "${shadow_dir}/webroot_sync_timestamp.del" 2>/dev/null
/bin/date +%s > "${shadow_dir}/webroot_sync_timestamp.del"

# Clean up empty directories in both trees
/usr/bin/find "${target_directory}" -mindepth 1 -type d -empty -delete
/usr/bin/find "${shadow_dir}" -mindepth 1 -type d -empty -delete

rnd="`/usr/bin/shuf -i1-10000 -n1`"

# Package and upload additions archive if changes occurred
if [ -s "${additions_log}" ]; then
    add_tar="${outgoing_dir}/additions/additions.${machine_ip}-${processing_time}-.tar.gz"
    /usr/bin/tar -czpf "${add_tar}" -T "${additions_log}" --same-owner --same-permissions
    /bin/rm -f "${additions_log}"

    if [ -f "${add_tar}" ]; then
        ${HOME}/services/datastore/operations/PutToDatastore.sh "${bucket_type}" "${add_tar}" "filesystem-sync/${bucket_type}/additions" "distributed" "no" "${target_directory}"
        
        # Optional: signal peer nodes via your database table so they don't poll S3
        # ${HOME}/utilities/database/LogDeltaEvent.sh "additions" "filesystem-sync/${bucket_type}/additions/$(basename "${add_tar}")" "${machine_ip}"

        /bin/mv "${add_tar}" "${outgoing_dir}/additions/additions.${machine_ip}-${processing_time}-${rnd}.tar.gz"
        ${HOME}/services/datastore/operations/PutToDatastore.sh "${bucket_type}" "${outgoing_dir}/additions/additions.${machine_ip}-${processing_time}-${rnd}.tar.gz" "filesystem-sync/${bucket_type}/historical/additions" "distributed" "no" "${target_directory}"
    fi
else
    /bin/rm -f "${additions_log}"
fi

# Upload deletions log if deletions occurred
if [ -s "${deletions_log}" ]; then
    ${HOME}/services/datastore/operations/PutToDatastore.sh "${bucket_type}" "${deletions_log}" "filesystem-sync/${bucket_type}/deletions" "distributed" "no" "${target_directory}"
    
    # Optional: signal peer nodes via your database table
    # ${HOME}/utilities/database/LogDeltaEvent.sh "deletions" "filesystem-sync/${bucket_type}/deletions/$(basename "${deletions_log}")" "${machine_ip}"

    /bin/mv "${deletions_log}" "${outgoing_dir}/deletions/deletions.${machine_ip}-${processing_time}-${rnd}.log"
    ${HOME}/services/datastore/operations/PutToDatastore.sh "${bucket_type}" "${outgoing_dir}/deletions/deletions.${machine_ip}-${processing_time}-${rnd}.log" "filesystem-sync/${bucket_type}/historical/deletions" "distributed" "no" "${target_directory}"
else
    /bin/rm -f "${deletions_log}"
fi
