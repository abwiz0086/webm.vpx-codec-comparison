"""A codec picker."""

import encoder
import h261
import h263
import mjpeg
import vp8
import vp8_cq
import ffmpeg

codec_map = {
  'vp8': vp8.Vp8Codec,
  'vp8_cq' : vp8_cq.Vp8CodecCqMode,
  'ffmpeg' : ffmpeg.FfmpegCodec,
  'mjpeg' : mjpeg.MotionJpegCodec,
  'h261': h261.H261Codec,
  'h263': h263.H263Codec
}

def PickCodec(name):
  if name is None:
    name = 'vp8'
  if name in codec_map:
    return codec_map[name]()
  raise encoder.Error('Unrecognized codec name %s' % name)


