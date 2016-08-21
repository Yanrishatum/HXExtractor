package;
import cpp.vm.Lock;
import cpp.vm.Thread;
import haxe.io.Bytes;
import haxe.io.BytesData;
import ogg.Ogg;
import openal.AL;

/**
 * Audio API
 */
class Audio
{
  
  private static var updateThread:Thread;
  private static var streams:Array<OggStream>;
  private static var sleepLock:Lock = new Lock();
  private static function startupThread():Void
  {
    updateThread = Thread.create(threadLoop);
  }
  private static function threadLoop():Void
  {
    streams = new Array();
    inline function updateStreamList():Void
    {
      while (true)
      {
        var streamData:OggStream = Thread.readMessage(false);
        if (streamData == null) break;
        streams.push(streamData);
      }
    }
    
    while (Main.running)
    {
      updateStreamList();
      var i:Int = 0;
      while (i < streams.length)
      {
        var stream:OggStream = streams[i];
        if (!stream.update())
        {
          streams.splice(i, 1);
          continue;
        }
        i++;
      }
      sleepLock.wait(0.05);
    }
    updateThread = null;
  }
  
  private static var device:Device;
  private static var context:Context;
  private static function ensureContext():Void
  {
    if (device == null)
    {
      device = ALC.openDevice();
      if (device == null) return;
      context = ALC.createContext(device, null);
      if (context == null) return;
      ALC.makeContextCurrent(context);
    }
  }
  
  public static function openStream(path:String):OggStream
  {
    ensureContext();
    return new OggStream(path);
  }
  
}

class OggStream
{
  
  private var file:OggVorbisFile;
  
  private static inline var BUFFER_COUNT:Int = 4;
  private static inline var BUFFER_SIZE:Int = 4096 * 8;
  #if HXCPP_BIG_ENDIAN
  public static inline var ENDIAN:OggEndian = OggEndian.OGG_B_ENDIAN;
  #else
  public static inline var ENDIAN:OggEndian = OggEndian.OGG_L_ENDIAN;
  #end
  
  // AL
  private var alSource:Int;
  private var alBuffers:Array<ALuint>;
  private var dataBuffers:Array<BytesData>;
  
  public var info:VorbisInfo;
  
  public var length:Float;
  public var position(get, set):Float;
  private function get_position():Float
  {
    return Ogg.ov_time_tell(file);
  }
  private function set_position(v:Float):Float
  {
    if (v < 0) v = 0;
    else if (v >= length) v = 0;
    Ogg.ov_time_seek_lap(file, v);
    return get_position();
  }
  
  private var _volume:Float;
  public var volume(get, set):Float;
  private function get_volume():Float return _volume;
  private function set_volume(v:Float):Float
  {
    _volume = v;
    AL.sourcef(alSource, AL.GAIN, v);
    return v;
  }
  
  public var playing:Bool;
  public var paused:Bool;
  public var loop:Bool;
  
  public function new(path:String)
  {
    file = Ogg.newOggVorbisFile();
    if (Ogg.ov_fopen(path, file) != 0) throw "Not an OGG or corruped";
    info = Ogg.ov_info(file, -1);
    length = Ogg.ov_time_total(file, -1);
    _volume = 1;
    dataBuffers = new Array();
    var i:Int = 0;
    while (i < BUFFER_COUNT)
    {
      dataBuffers[i++] = Bytes.alloc(BUFFER_SIZE).getData();
    }
    playing = false;
    loop = false;
  }
  
  public function update():Bool
  {
    if (!playing || (position >= length && AL.getSourcei(alSource, AL.BUFFERS_QUEUED) == 0))
    {
      if (loop && playing)
      {
        play();
      }
      else
      {
        destroyALContext();
        playing = false;
        return false;
      }
    }
    var processed:Int = AL.getSourcei(alSource, AL.BUFFERS_PROCESSED);
    var active:Bool = true;
    while (processed-- > 0)
    {
      var buf:ALuint = AL.sourceUnqueueBuffer(alSource);
      if (!fillBuffer(buf, dataBuffers[alBuffers.indexOf(buf)])) break;
      AL.sourceQueueBuffer(alSource, buf);
    }
    if (!alPlaying()) AL.sourcePlay(alSource);
    return true;
  }
  
  public function play():Bool
  {
    if (alBuffers == null) createALContext();
    Ogg.ov_time_seek_lap(file, 0);
    
    var i = 0;
    while (i < BUFFER_COUNT)
    {
      if (!fillBuffer(alBuffers[i], dataBuffers[i])) break;
      i++;
    }
    if (i == 0) return false;
    
    AL.sourceQueueBuffers(alSource, BUFFER_COUNT, alBuffers);
    AL.sourcePlay(alSource);
    playing = true;
    
    if (@:privateAccess Audio.updateThread == null)
    {
      @:privateAccess Audio.startupThread();
    }
    @:privateAccess Audio.updateThread.sendMessage(this);
    
    return true;
  }
  
  public function stop():Void
  {
    destroyALContext();
    playing = false;
  }
  
  public function destroy():Void
  {
    destroyALContext();
    dataBuffers = null;
    info = null;
    Ogg.ov_clear(file);
    file = null;
  }
  
  
  private function alPlaying():Bool
  {
    return AL.getSourcei(alSource, AL.SOURCE_STATE) == AL.PLAYING;
  }
  
  private function createALContext():Void
  {
    alSource = AL.genSource();
    AL.sourcei (alSource, AL.SOURCE_RELATIVE, AL.TRUE);
    AL.sourcef (alSource, AL.GAIN, _volume);
    AL.source3f(alSource, AL.POSITION       , 0.0, 0.0, 0.0);
    AL.source3f(alSource, AL.VELOCITY       , 0.0, 0.0, 0.0);
    AL.source3f(alSource, AL.DIRECTION      , 0.0, 0.0, 0.0);
    AL.sourcef (alSource, AL.ROLLOFF_FACTOR , 0.0);
    alBuffers = AL.genBuffers(BUFFER_COUNT, new Array());
  }
  
  private function destroyALContext():Void
  {
    if (alBuffers != null)
    {
      AL.sourceStop(alSource);
      AL.deleteSource(alSource);
      AL.deleteBuffers(alBuffers);
      alBuffers = null;
    }
  }
  
  private function fillBuffer(buf:ALuint, data:BytesData):Bool
  {
    var size:Int = 0;
    var result:Int;
    while (size < BUFFER_SIZE)
    {
      result = Ogg.ov_read(file, data, size, BUFFER_SIZE - size, OggEndian.TYPICAL, OggWord.OGG_16_BIT, OggSigned.OGG_SIGNED);
      if (result > 0) size += result;
      else if (result < 0) throw result; // Corrupt OGG
      else break; // EOF
    }
    
    if (size == 0) return false;
    AL.bufferData(buf, (info.channels == 1 ? AL.FORMAT_MONO16 : AL.FORMAT_STEREO16), info.rate, data, 0, size);
    //AL.bufferData(buf, mono ? AL.FORMAT_MONO16 : AL.FORMAT_STEREO16, dataBuffer, size, info.rate);
    return true;
  }
  
}