use v6.c;

use NativeCall;

class Audio::PortAudio {

    constant FRAMES_PER_BUFFER = 256;
    constant SAMPLE_RATE = 44100e0;
    
    enum StreamFormat (
        Float32         => 0x00000001,
        Int32           => 0x00000002,
        Int24           => 0x00000004,
        Int16           => 0x00000008,
        Int8            => 0x00000010,
        UInt8           => 0x00000020,
        CustomFormat    => 0x00010000,
        NonInterleaved  => 0x80000000,
    );
    
    constant paInputUnderflow is export     = 0x00000001;
    constant paInputOverflow is export      = 0x00000002;
    constant paOutputUnderflow is export    = 0x00000004;
    constant paOutputOverflow is export     = 0x00000008;
    constant paPrimingOutput is export      = 0x00000010;
    
    constant paClipOff is export                    = 0x00000001;
    constant paDitherOff is export                  = 0x00000002;
    constant paNeverDropInput is export             = 0x00000004;
    constant paPrimeOutputBufferUsingStreamCallback = 0x00000008;
    constant paPlatformSpecificFlags                = 0xFFFF0000;
    
    enum ErrorCode (
        "paNoError" => 0,
        "paNotInitialized" => -10000,
        "paUnanticipatedHostError",
        "paInvalidChannelCount",
        "paInvalidSampleRate",
        "paInvalidDevice",
        "paInvalidFlag",
        "paSampleFormatNotSupported",
        "paBadIODeviceCombination",
        "paInsufficientMemory",
        "paBufferTooBig",
        "paBufferTooSmall", # 9990
        "paNullCallback",
        "paBadStreamPtr",
        "paTimedOut",
        "paInternalError",
        "paDeviceUnavailable",
        "paIncompatibleHostApiSpecificStreamInfo",
        "paStreamIsStopped",
        "paStreamIsNotStopped",
        "paInputOverflowed",
        "paOutputUnderflowed", # 9980
        "paHostApiNotFound",
        "paInvalidHostApi",
        "paCanNotReadFromACallbackStream",
        "paCanNotWriteToACallbackStream",
        "paCanNotReadFromAnOutputOnlyStream",
        "paCanNotWriteToAnInputOnlyStream",
        "paIncompatibleStreamHostApi",
        "paBadBufferPtr"
    );
    
    enum HostApiTypeId  (
        InDevelopment   => 0,
        DirectSound     => 1,
        MME             => 2,
        ASIO            => 3,
        SoundManager    => 4,
        CoreAudio       => 5,
        OSS             => 7,
        ALSA            => 8,
        AL              => 9,
        BeOS            => 10,
        WDMKS           => 11,
        JACK            => 12,
        WASAPI          => 13,
        AudioScienceHPI => 14
    );
    
    enum StreamCallbackResult (
        Continue => 0,
        Complete => 1,
        Abort => 2
    );
    
    sub Pa_GetErrorText(int32 $errcode) returns Str is native('portaudio',v2) {...}

    # Single base exception 
    class X::PortAudio is Exception {
        has Int $.code is required;
        has Str $.error-text;
        method error-text() returns Str {
            if !$!error-text.defined {
                $!error-text = Pa_GetErrorText($!code);
            }
            $!error-text;
        }
    }

    class StreamCallbackTimeInfo is repr('CStruct') {
        has num $.inputBufferAdcTime;
        has num $.currentTime;
        has num $.outputBufferDacTime;
    }
    
    class StreamParameters is repr('CStruct') {
        has int32 $.device;
        has int32 $.channel-count;
        has uint32 $.sample-format;
        has num64 $.suggested-latency;
        has CArray[OpaquePointer] $.host-api-specific-streaminfo;
    }

    class HostApiInfo is repr('CStruct') {
        has int32   $.struct-version;
        has int32   $.type;
        has Str     $.name;
        has int32   $.device-count;
        has int32   $.default-input-device;
        has int32   $.default-output-device;
    }

    sub Pa_HostApiTypeIdToHostApiIndex( int32 $type ) returns int32 is native('portaudio', v2) { * }

    method host-api-index(HostApiTypeId $type) returns Int {
        my $rc = Pa_HostApiTypeIdToHostApiIndex($type.Int);

        $rc;
    }

    sub Pa_GetHostApiInfo(int32 $host-api) returns HostApiInfo is native('portaudio', v2) { * }

    method host-api(HostApiTypeId $type) returns HostApiInfo {
        my $index = self.host-api-index($type);
        Pa_GetHostApiInfo($index);
    }

    sub Pa_HostApiDeviceIndexToDeviceIndex(int32  $host-api, int32 $host-api-device-index ) returns int32 is native('portaudio', v2) { * }
    
    class DeviceInfo is repr('CStruct') {
        has int32 $.struct-version;
        has Str $.name;
        has int32 $.api-version;
        has int32 $.max-input-channels;
        has int32 $.max-output-channels;
        has num64 $.default-low-input-latency;
        has num64 $.default-low-output-latency;
        has num64 $.default-high-input-latency;
        has num64 $.default-high-output-latency;
        has num64 $.default-sample-rate;
    
        method perl() {
            "DeviceInfo.new(struct-version => $.struct-version, name => $.name, api-version => $.api-version, " ~
            "max-input-channels => $.max-input-channels, max-output-channels => $.max-output-channels, default-low-input-latency => $.default-low-input-latency, "~
            "default-low-output-latency => $.default-low-output-latency, default-high-input-latency => $.default-high-input-latency, " ~
            "default-high-output-latency => $.default-high-output-latency, default-sample-rate => $.default-sample-rate"
        }

        method host-api() returns HostApiInfo {
            Pa_GetHostApiInfo($!api-version);
        }
    }

    class X::StreamError is X::PortAudio {
        has Str $.what;
        method message() {
            "{ $!what } : { $.error-text }";
        }
    }

    class Stream is repr('CPointer') {
        sub Pa_StartStream(Stream $stream) returns int32 is native('portaudio',v2) {...}

        method start() returns Int {
            Pa_StartStream(self);
        }

        sub Pa_CloseStream(Stream $stream) returns int32 is native('portaudio',v2) {...}

        method close() returns Int {
            Pa_CloseStream(self);
        }

        sub Pa_WriteStream(Stream $stream, CArray $buf, int32 $frames) returns int32 is native('portaudio',v2) {...}

        method write(CArray $buf, Int $frames) returns Int {
            my $rc = Pa_WriteStream(self, $buf, $frames);

            if $rc != 0 {
                X::StreamError.new(code => $rc, what => "writing to stream").throw;
            }
            $rc;
        }

        sub Pa_IsStreamStopped(Stream $stream) returns int32 is native('portaudio', v2) { * }

        method stopped() returns Bool {
            Bool(Pa_IsStreamStopped(self));
        }

        sub Pa_IsStreamActive(Stream $stream) returns int32 is native('portaudio', v2) { * }

        method active() returns Bool {
            Bool(Pa_IsStreamActive(self));
        }

        sub Pa_GetStreamReadAvailable( Stream $stream ) returns int32 is native('portaudio', v2) { * }

        method read-available() returns Int {
            my $rc = Pa_GetStreamReadAvailable(self);
            if $rc < 0 {
                X::StreamError.new(code => $rc, what => "getting read frames").throw;
            }

            $rc;
        }

        sub Pa_GetStreamWriteAvailable( Stream $stream ) returns int32 is native('portaudio', v2) { * }

        method write-available() returns Int {
            my $rc = Pa_GetStreamWriteAvailable(self);

            if $rc < 0 {
                X::StreamError.new(code => $rc, what => "getting write frames").throw;
            }

            $rc;
        }

        sub Pa_ReadStream(Stream $stream, CArray $buffer, uint64 $frames) returns int32 is native('portaudio', v2) { * }

        method read(Int $frames, Int $num-channels, Mu:U $type) returns CArray {
            my $zero = $type ~~ Num ?? 0e0 !! 0;
            my $buff = CArray[$type].new($zero xx ($frames * $num-channels));
            my $rc = Pa_ReadStream(self, $buff, $frames);
            if $rc != 0 {
                X::StreamError.new(code => $rc, what => "reading stream").throw;
            }
            $buff;
        }
    }

    submethod BUILD() {
        self.initialize();
    }
    
    sub Pa_Initialize() returns int32 is native('portaudio',v2) {...}

    method initialize() returns Int {
        Pa_Initialize();
    }
    sub Pa_Terminate() returns int32 is native('portaudio',v2) {...}

    method terminate() returns Int {
        Pa_Terminate();
    }

    sub Pa_GetDeviceCount() returns int32 is native('portaudio',v2) {...}

    method device-count() returns Int {
        Pa_GetDeviceCount();
    }

    
    sub Pa_GetDeviceInfo(int32 $device-number) returns DeviceInfo is export is native('portaudio',v2) {...}

    method device-info(Int $device-number) returns DeviceInfo {
        Pa_GetDeviceInfo($device-number);
    }

    method devices() {
        my Int $no-devices = self.device-count();
        gather {
            for ^$no-devices -> $device-number {
                take self.device-info($device-number);
            }

        }
    }


    method error-text(Int $error-code) returns Str {
        Pa_GetErrorText($error-code);
    }
    
    sub Pa_GetDefaultOutputDevice() returns int32 is native('portaudio',v2) {...}

    method default-output-device() returns DeviceInfo {
        my Int $device-number = Pa_GetDefaultOutputDevice();
        self.device-info($device-number);
    }

    sub Pa_GetDefaultInputDevice() returns int32 is native('portaudio',v2) {...}

    method default-input-device() returns DeviceInfo {
        my Int $device-number = Pa_GetDefaultInputDevice();
        self.device-info($device-number);
    }
    
    sub Pa_OpenDefaultStream(CArray[Stream] $stream,
                             int32 $input,
                             int32 $output,
                             int32 $format,
                             num64 $sample-rate,
                             int32 $frames-per-buffer ,
                             &callback (CArray $inputbuf, CArray $outputbuf, int32 $framecount, StreamCallbackTimeInfo $callback-time-info, int32 $flags, CArray $cb-user-data --> int32),
                             CArray $user-data)
        returns int32 is native('portaudio',v2) {...}

    class X::OpenError is X::PortAudio {
        method message() returns Str  {
            "error opening stream: '{ $.error-text }'";
        }
    }

    method open-default-stream(Int $input = 0, Int $output = 2, StreamFormat $format = StreamFormat::Float32, Int $sample-rate = 44100, Int $frames-per-buffer = 256) returns Stream {
        my CArray[Stream] $stream = CArray[Stream].new;
        $stream[0] = Stream.new;
        my $rc = Pa_OpenDefaultStream($stream,$input,$output,$format.Int, Num($sample-rate), $frames-per-buffer, Code, CArray);
        if $rc != 0 {
            X::OpenError.new(code => $rc, error-text => self.error-text($rc)).throw;
        }
        $stream[0];
    }
    
    sub Pa_OpenStream(CArray[Stream] $stream,
                      StreamParameters $in-params,
                      StreamParameters $out-params,
                      num64 $sample-rate,
                      int32 $frames-per-buffer,
                      int32 $flags,
                      &callback (CArray $inputbuf, CArray $outputbuf, int32 $framecount, StreamCallbackTimeInfo $callback-time-info, int32 $cb-flags, CArray $cb-user-data --> int32),
                      CArray $user-data)
        returns int32 is native('portaudio',v2) {...}

    method open-stream(StreamParameters $in-params, StreamParameters $out-params, Int $sample-rate = 44100, Int $frames-per-buffer = 256) returns Stream {
        my CArray[Stream] $stream = CArray[Stream].new;
        $stream[0] = Stream.new;
        my $rc = Pa_OpenStream($stream, $in-params, $out-params, Num($sample-rate), $frames-per-buffer, 0, Code, CArray);
        if $rc != 0 {
            X::OpenError.new(code => $rc, error-text => self.error-text($rc)).throw;
        }
        $stream[0];
    }
    sub Pa_IsFormatSupported( StreamParameters $input, StreamParameters $output, num64 $sample-rate ) returns int32 is native('portaudio', v2) { * }

    method is-format-supported(StreamParameters $input, StreamParameters $output, Int $sample-rate) returns Bool {
        my $rc = Pa_IsFormatSupported($input, $output, Num($sample-rate));
        $rc == 0 ?? True !! False;
    }
}
# vim: expandtab shiftwidth=4 ft=perl6
