# AVSpeech Downloader
A bash script to download [AVSpeech](https://looking-to-listen.github.io/avspeech/) dataset.

## Usage
```bash
$ download.sh path-to-csv-file output-directory
```
You may stop the downloader by pressing `Ctrl-C`. Next runs recognize already downloaded files and will not try to re-download them.

## Options
`download.sh` acknowledges the following environment variables.
* `dryrun` set to any nonzero value makes the downloader print commands to the console without downloading any videos.
* `njobs` sets the number of concurrent downloader processes to run and defaults to the number of CPU cores.
* With `faster` set to `1`, the downloader tries to download 720p or 360p videos instead of the highest quality videos. Additionally, when `faster` is set to `2`, the downloader forces _FFmpeg_ to copy streams, running much faster with no transcoding carried out. See the known issue below.

## Required software packages
The following packages are required to run the downloader. It is important to have the latest versions of both _youtube-dl_ and _FFmpeg_.
* [youtube-dl](https://rg3.github.io/youtube-dl/)
* [FFmpeg](https://www.ffmpeg.org/)
* [GNU Parallel](https://www.gnu.org/software/parallel/)

## Examples
```bash
$ download.sh avspeech_train.csv data/train
$ njobs=12 faster=1 download.sh avspeech_train.csv data/train
```

## Known issue
_FFmpeg_ uses keyframe seeking when stream copying, which happens with `faster=2`. When a cut does not start from a keyframe, which happens most of the time, it cuts the video at the closest preceding keyframe and sets a negative start time to compensate for it. Thus, any subsequent tools that take the cut video clips as input should take the start time into account. Most video players do, but if you programatically process video clips, chances are you need to do it yourself and discard the first part of both audio and video streams accordingly.

## Contact
Please contact [Changil Kim](mailto:changil@csail.mit.edu) if you have questions of comments.
