#!/bin/bash
# download AVSpeech dataset
#
# required software packages: youtube-dl, ffmpeg, parallel
# command line arguments: <path to csv file> <output directory>
# environment variables: dryrun={0|1}, njobs=<#>, faster={0|1}

# dry run if nonzero
dryrun="${dryrun:-0}"
# number of parallel tasks
njobs="${njobs:-12}"
# faster download (always download 720p video)
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

# covert seconds to HH.MM.SS.FFF format
format_time() {
	h=$(bc <<< "${1}/3600")
	m=$(bc <<< "(${1}%3600)/60")
	s=$(bc <<< "${1}%60")
	printf "%02d:%02d:%06.3f\n" $h $m $s
}

show_msg() {
	printf "%s %s: %s\n" "$(get_time)" "$1" "$2"
}

download_video() {
	IFS=',' read -r ytid start end x y <<< "$1"

	# check if video exists
	[[ -f "$outdir/$ytid.mp4" ]] && { show_msg "$ytid" "skipped"; return; }

	# make sure output directory exists
	$mkdir "$outdir" || { show_msg "$ytid" "ERROR: failed to create output directory"; return; }

	start_time="$(format_time $start)"
	duration="$(bc <<< "$end - $start")"

	if [[ "$faster" -eq 0 ]]; then
		# download the highest quality video

		# download video
		$youtubedl --format 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio' --merge-output-format mp4 --prefer-ffmpeg --output "$outdir/%(id)s.%(ext)s.inprogress.1" -- "$ytid" || { show_msg "$ytid" "ERROR: failed to download video"; return; }
		# youtube-dl appends additional extension when merging video & audio - remove it
		$mv "$outdir/$ytid.mp4.inprogress.1.mp4" "$outdir/$ytid.mp4.inprogress.1" || { show_msg "$ytid" "ERROR: failed to rename temporary video"; return; }

		# cut video
		$ffmpeg -ss "$start_time" -i "$outdir/$ytid.mp4.inprogress.1" -t "$duration" -c:v copy -c:a copy -f mp4 -threads 1 "$outdir/$ytid.mp4.inprogress.2" < /dev/null || { show_msg "$ytid" "ERROR: failed to cut video"; return; }

		# cleanup
		$rm "$outdir/$ytid.mp4.inprogress.1" || { show_msg "$ytid" "ERROR: failed to remove temporary file"; return; }
		$mv "$outdir/$ytid.mp4.inprogress.2" "$outdir/$ytid.mp4" || { show_msg "$ytid" "ERROR: failed to rename video"; return; }

	else
		# download 720p hd video

		# get video link (try 720p/360p mp4 format in that order)
		url="$($youtubedl --get-url --format '22/18' -- "$ytid")" || { show_msg "$ytid" "ERROR: failed to get video url"; return; }

		# download (only the interesting part of) video
		$ffmpeg -ss "$start_time" -i "$url" -t "$duration" -c:v copy -c:a copy -f mp4 -threads 1 "$outdir/$ytid.mp4.inprogress" < /dev/null || { show_msg "$ytid" "ERROR: failed to download video"; return; }

		# cleanup
		$mv "$outdir/$ytid.mp4.inprogress" "$outdir/$ytid.mp4" || { show_msg "$ytid" "ERROR: failed to rename video"; return; }

	fi

	show_msg "$ytid" "downloaded"
}

export youtubedl ffmpeg mv rm mkdir parallel dryrun outdir
export -f get_time format_time show_msg download_video

cat "$csvfile" | $parallel -j "$njobs" -k download_video
#head -n 1 "$csvfile" | $parallel -j "$njobs" -k download_video

