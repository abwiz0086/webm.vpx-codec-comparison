#!/bin/bash

# Encode each .yuv file in the specified input directory to VP8 format,
# and compute the PSNR.

# Input Parameters:
#  $1=Input directory

tempyuvfile=$(mktemp ./tempXXXXX.yuv)

if [ ! -d encoded_clips ]; then
  mkdir encoded_clips
  mkdir encoded_clips/h264
  mkdir encoded_clips/vp8
fi

if [ ! -d logs ]; then
  mkdir logs
  mkdir logs/h264
  mkdir logs/vp8
fi

if [ ! -d stats ]; then
  mkdir stats
  mkdir stats/h264
  mkdir stats/vp8
fi

for filename in $1/*.yuv
do
  echo "Processing ${filename}"

  # filename format: <path>/<clip_name>_<width>_<height>_<frame_rate>.yuv
  pathless=$(basename ${filename})
  clip_stem=${pathless%.*}
  part=($(echo $clip_stem | tr "_" "\n"))
  width=${part[1]}
  height=${part[2]}
  frame_rate=${part[3]}

  # Reset previous run data
  rm -f ./stats/vp8/${clip_stem}.txt

  # Data-rate range depends on input format
  if [ ${width} -gt 640 ]; then
    rate_start=800
    rate_end=1500
    rate_step=100
  else
    rate_start=100
    rate_end=800
    rate_step=100
  fi

  for (( rate=rate_start; rate<=rate_end; rate+=rate_step ))
  do
    echo "Encoding for $rate"
    # Encode video into the following file:
    #  ./<clip_name>_<width>_<height>_<frame_rate>_<rate>kbps.yuv
    # Data-rate & PSNR will be output to the file "opsnr.stt"
    # Settings from Adrian's Oct 26 message.
    ./bin/vpxenc \
      --passes=1 --best \
      --end-usage=cbr \
      --buf-sz=1000 --buf-optimal-sz=1000 --buf-initial-sz=800 \
      --undershoot-pct=100 --overshoot-pct=15 \
      --min-q=2 --max-q=56 \
      --max-intra-rate=1200 \
      --kf-min-dist=9999 --kf-max-dist=9999 \
      --lag-in-frames=0 \
      --drop-frame=0 \
      --resize-allowed=0 \
      --target-bitrate=${rate} --fps=${frame_rate}/1 \
      --static-thresh=0 --noise-sensitivity=0 \
      --token-parts=1 \
      -w ${width} -h ${height} ${filename} --codec=vp8 \
      -o ./encoded_clips/vp8/${clip_stem}_${rate}kbps.webm \
      &>./logs/vp8/${clip_stem}_${rate}kbps.txt


    # Decode the clip to a temporary file in order to compute PSNR and extract
    # bitrate.
    rm -f $tempyuvfile
    encoded_rate=( `bin/ffmpeg -i ./encoded_clips/vp8/${clip_stem}_${rate}kbps.webm \
      $tempyuvfile 2>&1 | awk '/bitrate:/ { print $6 }'` )
    if expr $encoded_rate + 0 > /dev/null; then

      # Compute the global PSNR.
      psnr=$(./bin/psnr ${filename} $tempyuvfile ${width} ${height} 9999)

      # Rename the file to reflect the encoded datarate.
      if [ $rate -ne $encoded_rate ]; then
        mv -f ./encoded_clips/vp8/${clip_stem}_${rate}kbps.webm \
          ./encoded_clips/vp8/${clip_stem}_${encoded_rate}_kbps.webm
      fi
      echo "${encoded_rate} ${psnr}" >> ./stats/vp8/${clip_stem}.txt
    else
      echo "Non-numeric bitrate $encoded_rate"
      exit 1
    fi

    rm -f $tempyuvfile
  done

  rm -f opsnr.stt
done

