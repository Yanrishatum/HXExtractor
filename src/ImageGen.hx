package;
import format.png.Data;
import format.png.Reader;
import format.png.Tools;
import format.png.Writer;
import haxe.io.Bytes;
import haxe.io.Output;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

typedef Image =
{
  var width:Int;
  var height:Int;
  var pixels:Bytes;
}

enum ImageCommand
{
  Copy(source:Int, sx:Int, sy:Int, dx:Int, dy:Int, w:Int, h:Int);
  Fill(x:Int, y:Int, w:Int, h:Int, color:Int);
  FillAlpha(x:Int, y:Int, w:Int, h:Int, alpha:Int);
}

/**
 * ...
 * @author Yanrishatum
 */
class ImageGen
{

  private var sourceMap:Map<String, Int>;
  private var sources:Array<Image>;
  private var commands:Array<ImageCommand>;
  
  public function new() 
  {
    sources = new Array();
    sourceMap = new Map();
    commands = new Array();
  }
  
  public function draw(source:Int, sx:Int, sy:Int, dx:Int, dy:Int, w:Int, h:Int):Void
  {
    commands.push(ImageCommand.Copy(source, sx, sy, dx, dy, w, h));
  }
  
  public function fillAlpha(x:Int, y:Int, w:Int, h:Int, alpha:Int):Void
  {
    commands.push(ImageCommand.FillAlpha(x, y, w, h, alpha));
  }
  
  public function fill(x:Int, y:Int, w:Int, h:Int, color:Int):Void
  {
    commands.push(ImageCommand.Fill(x, y, w, h, color));
  }
  
  public function addCommands(other:ImageGen):Void
  {
    for (com in other.commands)
    {
      commands.push(com);
    }
  }
  
  public function loadPng(path:String):Int
  {
    if (sourceMap.exists(path)) return sourceMap.get(path);
    if (FileSystem.exists(path))
    {
      var png:Data = new Reader(File.read(path)).read();
      var h:Header = Tools.getHeader(png);
      sources.push(
      {
        width: h.width,
        height: h.height,
        pixels:Tools.extract32(png)
      });
      sourceMap.set(path, sources.length - 1);
      return sources.length - 1;
    }
    return -1;
  }
  
  public function setTransparentColor(source:Int, transparent:Int):Void
  {
    var pixels:Bytes = sources[source].pixels;
    var i:Int = 0;
    while (i < pixels.length)
    {
      if (pixels.getInt32(i) == transparent) pixels.setInt32(i, 0);
      i += 4;
    }
  }
  
  public function save(path:String):Void
  {
    var width:Int = 0;
    var height:Int = 0;
    for (command in commands)
    {
      switch (command)
      {
        case ImageCommand.Copy(s, sx, sy, dx, dy, w, h):
          if (dx + w > width) width = dx + w;
          if (dy + h > height) height = dy + h;
        case ImageCommand.Fill(x, y, w, h, color):
          if (x + w > width) width = x + w;
          if (y + h > height) height = y + h;
        case ImageCommand.FillAlpha(x, y, w, h, alpha):
          if (x + w > width) width = x + w;
          if (y + h > height) height = y + h;
      }
    }
    if (width == 0 || height == 0) return;
    var bytes:Bytes = Bytes.alloc(width * height * 4);
    
    for (command in commands)
    {
      switch (command)
      {
        case ImageCommand.Copy(s, sx, sy, dx, dy, w, h):
          blit(bytes, width, sources[s], sx, sy, dx, dy, w, h);
        case ImageCommand.Fill(x, y, w, h, color):
          _fillColor(bytes, width, x, y, w, h, color);
        case ImageCommand.FillAlpha(x, y, w, h, alpha):
          _fillAlpha(bytes, width, x, y, w, h, alpha);
      }
    }
    var png:Data = Tools.build32BGRA(width, height, bytes);
    try
    {
      FileSystem.createDirectory(Path.directory(path));
    }
    catch (e:Dynamic) { }
    var o:Output = File.write(path);
    new Writer(o).write(png);
    o.flush();
    o.close();
  }
  
  private function _fillColor(out:Bytes, outW:Int, x:Int, y:Int, w:Int, h:Int, color:Int):Void
  {
    outW *= 4;
    x *= 4;
    var offset:Int = y * outW + x;
    for (i in 0...h)
    {
      var o:Int = offset;
      for (j in 0...w)
      {
        out.setInt32(o, color);
        o += 4;
      }
      offset += outW;
    }
  }
  
  private function _fillAlpha(out:Bytes, outW:Int, x:Int, y:Int, w:Int, h:Int, alpha:Int):Void
  {
    outW *= 4;
    x *= 4;
    var offset:Int = y * outW + x;
    for (i in 0...h)
    {
      var o:Int = offset;
      for (j in 0...w)
      {
        out.set(o + 3, alpha);
        o += 4;
      }
      offset += outW;
    }
  }
  
  private function blit(out:Bytes, outW:Int, source:Image, sx:Int, sy:Int, dx:Int, dy:Int, w:Int, h:Int):Void
  {
    outW *= 4;
    dx *= 4;
    sx *= 4;
    w *= 4;
    var offset:Int = dy * outW + dx;
    var sourceOffset:Int = sy * (source.width * 4) + sx;
    
    for (i in 0...h)
    {
      var j = 0;
      var so:Int = sourceOffset;
      var o:Int = offset;
      
      while (j < w)
      {
        if (source.pixels.get(so + 3) != 0)
        {
          out.blit(o, source.pixels, so, 4);
        }
        j += 4;
        so += 4;
        o += 4;
      }
      sourceOffset += (source.width * 4);
      offset += outW;
    }
  }
  
  public function sourceWidth(index:Int = 0):Int
  {
    return sources[index].width;
  }
  
  public function sourceHeight(index:Int = 0):Int
  {
    return sources[index].height;
  }
  
}