# Audio::PortAudio

Access to audio input and output devices

## Synopsis

```perl6

use Audio::PortAudio;

my $pa = Audio::PortAudio.new;

# get the default stream with no inputs, 2 output channels
# for audio encoded as 32 bit floats at 44100 samplerate;
my $stream = $pa.open-default-stream(0,2,Audio::PortAudio::Float32,44100);

$stream.start;

loop {
	# get some audio data in a carray from somewhere
	$stream.write($carray, $frame-count);
}


```

## Description

This module provides a mechanism to get audio into and out of your
program via a sound card or some other sub-system supported by the
(portaudio)[http://www.portaudio.com/], this may include "ALSA", "JACK"
or "OSS" on Linux, "CoreAudio" on Mac and "ASIO" on Windows, (of course
the actual support depends on how the library was built on your system.)

You will need to have the portaudio library installed on your system
to use this, it may be available as a package or come pre-installed,
but the details will be specific to your platform.

The interface is somewhat simplified in comparison to the underlying
library and in particular only "blocking" IO is supported at the current
time (though this does not preclude the use of the callback API in the
future, it's just an interface that is natural to a Perl 6 developer
doesn't suggest itself at the moment.)

It is important to note that the constraints of real-time audio data
handling mean that you have to be careful that you allow for consistent
and timely handing of the data to or from the device for proper results,
you may find that for some applications you will need to avoid the use
of any concurrency whatsoever for instance (the streaming example is
such a case where the time budget was such that any unexpected garbage
collection or other processor stealing activity didn't leave the process
enough time spare to recover and the stream eventually became unusable.)

Also it should be noted that some types of source API ("JACK" in
particular,) require that you use a fixed buffer size that is consistent
with that configured for the host service, unfortunately portaudio doesn't
appear to provide a way of discovering this so you may need to either
check with the source configuration or experiment to find a correct and
working value for buffer sizes.  The symptoms of this may include choppy,
"syncopated" or "phased" output.


