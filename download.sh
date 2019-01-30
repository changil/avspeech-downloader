#!/bin/bash
# download AVSpeech dataset
#
# usage:      download.sh <path-to-csv-file> <output-directory>
# env vars:   dryrun={0|1} njobs=<n> faster={0|1|2}
# dependency: youtube-dl, FFmpeg, GNU Parallel
# author:     Changil Kim <changil@csail.mit.edu>
#
# examples:
#   download.sh avspeech_train.csv data/train
#   njobs=12 faster=1 download.sh avspeech_train.csv data/train

# read environment variables
# dry run if set nonzero (default: 0)
dryrun="${dryrun:-0}"
# number of parallel tasks (default: #cpu cores)
njobs="${njobs:-0}"
# faster download if set > 0 (1: always download 720p/360p videos; 2: plus, use stream copy; default: 0)
faster="${faster:-0}"

# check if all arguments are given
if [[ $# -ne 2 ]]; then
	echo "usage: $(basename "$0") <path-to-csv-file> <output-directory>"
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

	# get the source video (either downloaded file or url)
	if [[ "$faster" -eq 0 ]]; then
		# download the highest quality video (which would require youtube-dl to mux video and audio that are downloaded separately)
		$youtubedl --format 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio' --merge-output-format mp4 --prefer-ffmpeg --output "$outdir/$filename.inprogress.1" -- "$ytid" || { show_msg "$id" "ERROR: failed to download video"; return; }
		# youtube-dl appends additional extension when merging video & audio - remove it
		$mv "$outdir/$filename.inprogress.1.mp4" "$outdir/$filename.inprogress.1" || { show_msg "$id" "ERROR: failed to rename temporary video"; return; }
		src="$outdir/$filename.inprogress.1"
		deletesrc=1
	else
		# get the url of the 720p/360p mp4 video (tried in that order; usually the best single file format)
		src="$($youtubedl --get-url --format '22/18' -- "$ytid")" || { show_msg "$id" "ERROR: failed to get video url"; return; }
		deletesrc=0
	fi

	# download/cut only the relevant part of video
	if [[ "$faster" -le 1 ]]; then
		# transcode streams (the following options should be reasonable for most cases, but could be changed to meet your taste)
		codec_opts="-c:v libx264 -crf 18 -preset veryfast -pix_fmt yuv420p -c:a aac -b:a 128k -strict experimental"
	else
		# copy streams - this will result in the cut taking place at the closest preceding keyframe and the start time set accordingly (i.e., negative)
		codec_opts="-c:v copy -c:a copy"
	fi
	$ffmpeg -ss "$start" -i "$src" -t "$duration" $codec_opts -f mp4 -threads 1 "$outdir/$filename.inprogress" < /dev/null || { show_msg "$id" "ERROR: failed to download/cut video"; return; }

	# cleanup
	if [[ $deletesrc -ne 0 ]]; then
		$rm "$src" || { show_msg "$id" "ERROR: failed to remove temporary file"; return; }
	fi
	$mv "$outdir/$filename.inprogress" "$outdir/$filename" || { show_msg "$id" "ERROR: failed to rename video"; return; }

	walltime="$(printf "%.1f" "$(bc <<< "$(date +%s.%N) - $t")")"
	show_msg "$id" "downloaded (${walltime}s)"
}

export youtubedl ffmpeg mv rm mkdir outdir faster
export -f get_time format_time format_seconds show_msg download_video

trap 'printf "%s %s\n" "$(get_time)" "*** download interrupted ***"; exit 2' INT QUIT TERM
printf "%s %s\n" "$(get_time)" "*** download starts ***"

cat "$csvfile" | $parallel -j "$njobs" --timeout 600 download_video

printf "%s %s\n" "$(get_time)" "*** download ends ***"

