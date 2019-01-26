#!/bin/bash
# download AVSpeech dataset
#
# usage:      download.sh <path-to-csv-file> <output-directory>
# env vars:   dryrun={0|1} njobs=<n> faster={0|1}
# dependency: youtube-dl, ffmpeg, parallel
# author:     Changil Kim <changil@csail.mit.edu>
#
# examples:
#   download.sh avspeech_train.csv data/train
#   njobs=1 faster=1 download.sh avspeech_train.csv data/train

# read environment variables
# dry run if set (default: unset)
dryrun="${dryrun:-0}"
# number of parallel tasks (default: #cpu cores)
njobs="${njobs:-0}"
# faster download if set (always download 720p video; default: unset)
faster="${faster:-0}"

# check if all arguments are given
if [[ $# -ne 2 ]]; then
	echo "usage: $(basename "$0") <csv-file> <out-dir>"
	exit 1
fi

# csv file path
csvfile="$1"
# output directory path
outdir="$2"

# command definitions
youtubedl="youtube-dl --quiet --no-warnings"
ffmpeg="ffmpeg -y -loglevel error"
mv="mv -f"
rm="rm -f"
mkdir="mkdir -p"
parallel="parallel --no-notice"

if [[ "$dryrun" -ne 0 ]]; then
	# show commands if dry run
	youtubedl="echo $youtubedl"
	ffmpeg="echo $ffmpeg"
	mv="echo $mv"
	rm="echo $rm"
	mkdir="echo $mkdir"
fi

get_time() {
	date "+[%Y/%m/%d %H:%M:%S]"
}

# covert seconds to hh:mm:ss.ffffff format
format_time() {
	h=$(bc <<< "${1}/3600")
	m=$(bc <<< "(${1}%3600)/60")
	s=$(bc <<< "${1}%60")
	printf "%02d:%02d:%09.6f\n" $h $m $s
}

format_seconds() {
	printf "%010.6f\n" "$1"
}

show_msg() {
	printf "%s %s: %s\n" "$(get_time)" "$1" "$2"
}

download_video() {
	# parse csv
	IFS=',' read -r ytid start end x y <<< "$1"

	id="${ytid}_$(format_seconds "$start")-$(format_seconds "$end")"
	filename="$id.mp4"

	# skip if video exists
	[[ -f "$outdir/$filename" ]] && { show_msg "$id" "skipped"; return; }

	# make sure output directory exists
	$mkdir "$outdir" || { show_msg "$id" "ERROR: failed to create output directory"; return; }

	duration="$(bc <<< "$end - $start")"
	t="$(date +%s.%N)"

	if [[ "$faster" -eq 0 ]]; then
		# download the highest quality video

		# download video
		$youtubedl --format 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio' --merge-output-format mp4 --prefer-ffmpeg --output "$outdir/$filename.inprogress.1" -- "$ytid" || { show_msg "$id" "ERROR: failed to download video"; return; }
		# youtube-dl appends additional extension when merging video & audio - remove it
		$mv "$outdir/$filename.inprogress.1.mp4" "$outdir/$filename.inprogress.1" || { show_msg "$id" "ERROR: failed to rename temporary video"; return; }

		# cut video
		$ffmpeg -ss "$start" -i "$outdir/$filename.inprogress.1" -t "$duration" -c:v copy -c:a copy -f mp4 -threads 1 "$outdir/$filename.inprogress.2" < /dev/null || { show_msg "$id" "ERROR: failed to cut video"; return; }

		# cleanup
		$rm "$outdir/$filename.inprogress.1" || { show_msg "$id" "ERROR: failed to remove temporary file"; return; }
		$mv "$outdir/$filename.inprogress.2" "$outdir/$filename" || { show_msg "$id" "ERROR: failed to rename video"; return; }

	else
		# download 720p hd video

		# get video link (try 720p/360p mp4 format in that order)
		# youtube-dl format 22 is the following:
		# 22     mp4        1280x720   hd720 , avc1.64001F, mp4a.40.2@192k (best)
		url="$($youtubedl -f 22 --get-url --format '22/18' -- "$ytid")" || { show_msg "$id" "ERROR: failed to get video url"; return; }

		# download (only the interesting part of) video
		$ffmpeg -ss "$start" -i "$url" -t "$duration" -c:v copy -c:a copy -f mp4 -threads 1 "$outdir/$filename.inprogress" < /dev/null || { show_msg "$id" "ERROR: failed to download video"; return; }

		# cleanup
		$mv "$outdir/$filename.inprogress" "$outdir/$filename" || { show_msg "$id" "ERROR: failed to rename video"; return; }

	fi

	walltime="$(printf "%.1f" "$(bc <<< "$(date +%s.%N) - $t")")"
	show_msg "$id" "downloaded (${walltime}s)"
}

export youtubedl ffmpeg mv rm mkdir outdir faster
export -f get_time format_time format_seconds show_msg download_video

trap 'printf "%s %s\n" "$(get_time)" "*** download interrupted ***"; exit 2' INT QUIT TERM
printf "%s %s\n" "$(get_time)" "*** download starts ***"

cat "$csvfile" | $parallel -j "$njobs" --timeout 600 download_video

printf "%s %s\n" "$(get_time)" "*** download ends ***"

