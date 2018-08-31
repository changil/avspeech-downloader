# AVSpeech Downloader
A bash script to download [AVSpeech](https://looking-to-listen.github.io/avspeech/) dataset.

## Usage
```bash
$ download.sh path-to-csv-file output-directory
```
You may stop the downloader by pressing `Ctrl-C`. Next runs recognize already downloaded files and do not try to re-download them.

## Options
`download.sh` acknowledges the following environment variables.
* `dryrun` set to any non-zero value renders the downloader only print commands to the console
* `njobs` sets the number of concurrent downloader processes to be run and defaults to the number of CPU cores
* `faster` set to a non-zero value, the downloader tries to download 720p HD videos despite the existence of higher quality videos, which allows the downloader to run much faster since no transcoding is carried out

## Examples
```bash
$ download.sh avspeech_train.csv data/train
$ njobs=1 faster=1 download.sh avspeech_train.csv data/train
```

## Required software packages
The following packages are required to run the downloader.
* [youtube-dl](https://rg3.github.io/youtube-dl/)
* [FFmpeg](https://www.ffmpeg.org/)
* [GNU Parallel](https://www.gnu.org/software/parallel/)

## Contact
Please contact [Changil Kim](mailto:changil@csail.mit.edu) if you have questions of comments.
