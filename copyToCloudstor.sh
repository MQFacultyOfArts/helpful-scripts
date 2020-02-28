#!/bin/bash

#Don't forget to run shellcheck (https://github.com/koalaman/shellcheck) after making edits.
counter=1
set -euo pipefail

#default values

CHECK=1
CHECKERS=36
EXTRAVARS=0
HELP=0
PUSHFIRST=0
VERSIONCHECK=1
SHOWDIFF=""
TIMEOUT=0
TRANSFERS=12
PULL=0

#cli options
POSITIONAL=()
while [[ $# -gt 0 ]]; do
	key="${1}"
	case ${key} in
		--help)
			HELP=1
		    	shift # past argument
	    	;;
		--nocheck)
			CHECK=0
		    	shift # past argument
	    	;;
		-p|--parallel)
			TRANSFERS="${2}"
		    	shift # past argument
			shift # past value
	    	;;
		--pushfirst)
			PUSHFIRST=1
		    	shift # past argument
	    	;;
		--showdiff)
			SHOWDIFF="-vv"
		    	shift # past argument
	    	;;
		--skipversioncheck)
			VERSIONCHECK=0
		    	shift # past argument
	    	;;
	    --pull)
			PULL=1
				shift
			;;
    	*)    # unknown option
			EXTRAVARS=1
			POSITIONAL+=("$1") # save it in an array for later
			shift # past argument
    		;;
	esac
done
if [ ${EXTRAVARS} -eq 1 ]; then
	set -- "${POSITIONAL[@]}" # restore positional parameters
fi

#Usage
if [ "$#" -ne 2 ] || [ ${HELP} -eq 1 ]; then
	echo "./copyToCloudstor <src> <rcloneEndpoint:dest>"
	echo "  --help              : This help"
	echo "  --skipversioncheck  : Skip rclone version checking"
	echo "  --nocheck           : Just pushes once without retrying"
	echo "  -p|--parallel       : Number of file transfers to run in parallel. (default 6)"
	echo "  --pushfirst         : Skip first oneway check (one less propfind)"
	echo "  --showdiff          : Show diff when checking for differences"

	exit 1
fi

#Check for latest rclone version
if [ ${VERSIONCHECK} -eq 1 ]; then
	if [ "$(rclone version --check | grep -e 'yours\|latest' | sed 's/  */ /g' | cut -d' ' -f2 | uniq | wc -l)" -gt 1 ]; then
		rclone version --check
		echo "Upgrade rclone (curl https://rclone.org/install.sh | sudo bash)"
		exit 1
	else 
		echo "rclone is latest version."
	fi
fi

#Do the transfer
SECONDS=0
source_absolute_path=$(readlink -m "${1}")


rcloneoptions="--transfers ${TRANSFERS} --checkers ${CHECKERS} --timeout ${TIMEOUT}"

if [ ${PULL} -eq 0 ]; then
	echo "Copying ${source_absolute_path} to ${2}. Starting at $(date)"

	counter=1
	if [ ${PUSHFIRST} -eq 1 ] || [ ${CHECK} -eq 0 ]; then
		echo "Starting run ${counter} at $(date) without checks"
		rclone copy --progress --no-check-dest --no-traverse ${rcloneoptions} "${source_absolute_path}" "${2}"
		echo "Done with run ${counter} at $(date)"
		counter=$((counter+1))
	fi
	if [ ${CHECK} -eq 1 ]; then
		while ! rclone check --one-way ${SHOWDIFF} ${rcloneoptions} "${source_absolute_path}" "${2}" 2>&1 | tee /dev/stderr | grep ': 0 differences found'; do
			echo "Starting run ${counter} at $(date)"
			rclone copy --progress "${rcloneoptions}" "${source_absolute_path}" "${2}"
			echo "Done with run ${counter} at $(date)"
			counter=$((counter+1))
		done
	fi
else
	echo "Copying ${1} to ${2}. Starting at $(date)"

	counter=1
	if [ ${PUSHFIRST} -eq 1 ] || [ ${CHECK} -eq 0 ]; then
		echo "Starting run ${counter} at $(date) without checks"
		rclone copy --progress --no-check-dest --no-traverse ${rcloneoptions} "${1}" "${2}"
		echo "Done with run ${counter} at $(date)"
		counter=$((counter+1))
	fi
	if [ ${CHECK} -eq 1 ]; then
		while ! rclone check --one-way ${SHOWDIFF} ${rcloneoptions} "${1}" "${2}" 2>&1 | tee /dev/stderr | grep ': 0 differences found'; do
			echo "Starting run ${counter} at $(date)"
			rclone copy --progress "${rcloneoptions}" "${1}" "${2}"
			echo "Done with run ${counter} at $(date)"
			counter=$((counter+1))
		done
	fi
fi


duration=${SECONDS}
echo "Copied '${1}' to '${2}'. Finished at $(date), in $((duration / 60)) minutes and $((duration % 60)) seconds elapsed."
