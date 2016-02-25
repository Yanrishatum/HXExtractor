package;
#if hxe_enable_GifGen

import format.gif.Data;
import format.gif.Tools;
import format.gif.Writer;
import haxe.io.BytesOutput;
import haxe.io.UInt8Array;
import ImageGen.PixelData;
import haxe.io.Bytes;

typedef GifFrameData =
{
  var x:Int;
  var y:Int;
  var delay:Int;
  var width:Int;
  var height:Int;
  var disposalMethod:DisposalMethod;
  var pal:Bytes;
  var palSize:Int;
  var pixels:Bytes;
  var trans:Bool;
  var transIndex:Int;
}

/**
 * ...
 * @author Yanrishatum
 */
class GifGen
{

  private var frames:Array<GifFrameData>;
  private var gct:Bytes;
  private var gctSize:Int;
  private var bgIndex:Int;
  private var loops:Int;
  
  public function new() 
  {
    
  }
  
  public function start():Void
  {
    bgIndex = 0;
    gct = null;
    gctSize = 2;
    loops = 0;
    frames = new Array();
  }
  
  public function addIndexes(pixels:Bytes, x:Int, y:Int, width:Int, height:Int, delay:Int = 2, ?disposalMethod:DisposalMethod, ?pal:Bytes, ?transparentIndex:Int):Void
  {
    if (disposalMethod == null) disposalMethod = DisposalMethod.NO_ACTION;
    frames.push( {
      x: x,
      y: y,
      width: width,
      height: height,
      pixels: pixels,
      delay: delay,
      disposalMethod:disposalMethod,
      pal: pal,
      palSize: pal != null ? Std.int(pal.length / 2) : 0,
      trans: transparentIndex != null,
      transIndex: transparentIndex != null ? transparentIndex : 0
    });
  }
  
  public function setGlobalColorTable(table:Array<Int>):Void
  {
    gct = Bytes.alloc(table.length * 3);
    gctSize = table.length;
    var off:Int = 0;
    for (val in table)
    {
      gct.set(off++, (val & 0xFF0000) >> 16);
      gct.set(off++, (val & 0xFF00) >> 8);
      gct.set(off++, val & 0xFF);
    }
  }
  
  public function setBackgroundIndex(index:Int):Void
  {
    bgIndex = index;
  }
  
  public function setLoops(amount:Int):Void
  {
    loops = amount;
  }
  
  public function finish():Bytes
  {
    var data:Data =
    {
      version:Version.GIF89a,
      logicalScreenDescriptor:
      {
        width: 0,
        height: 0,
        hasGlobalColorTable: gct != null,
        colorResolution: 0,
        sorted: true,
        globalColorTableSize: gctSize,
        pixelAspectRatio: 1,
        backgroundColorIndex: bgIndex
      },
      globalColorTable: gct,
      blocks: new List()
    }
    data.blocks.add(Block.BExtension(Extension.EApplicationExtension(ApplicationExtension.AENetscapeLooping(loops))));
    var lw:Int = 0;
    var lh:Int = 0;
    for (frame in frames)
    {
      if (frame.x + frame.width > lw) lw = frame.x + frame.width;
      if (frame.y + frame.height > lh) lh = frame.y + frame.height;
      data.blocks.add(Block.BExtension(Extension.EGraphicControl( {
        disposalMethod: frame.disposalMethod,
        userInput: false,
        hasTransparentColor: frame.trans,
        delay: frame.delay,
        transparentIndex: frame.transIndex
      })));
      data.blocks.add(Block.BFrame( {
        x: frame.x,
        y: frame.y,
        width: frame.width,
        height: frame.height,
        localColorTable: frame.pal != null,
        interlaced: false,
        sorted: true,
        localColorTableSize: frame.palSize,
        pixels: frame.pixels,
        colorTable: frame.pal
      }));
    }
    
    data.logicalScreenDescriptor.width = lw;
    data.logicalScreenDescriptor.height = lh;
    var o:BytesOutput = new BytesOutput();
    new Writer(o).write(data);
    return o.getBytes();
  }
  
  
}

#end