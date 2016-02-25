package;
import format.png.Data;
import format.png.Reader;
import format.png.Tools;
import format.png.Writer;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
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

typedef PixelData =
{
  var pixels:Bytes;
  var width:Int;
  var height:Int;
}

/**
 * Image generation class. Can be used to rasterize some data and save it as PNG file.
 * @author Yanrishatum
 */
class ImageGen
{

  private var sourceMap:Map<String, Int>;
  private var sources:Array<Image>;
  private var commands:Array<ImageCommand>;
  
  /**
   * Creates new canvas.
   */
  public function new() 
  {
    sources = new Array();
    sourceMap = new Map();
    commands = new Array();
  }
  
  /**
   * Draws image at `source` index onto canvas.
   * @param source Source image index.
   * @param sx X offset on Source image.
   * @param sy Y offset on Source image.
   * @param dx X position of copied pixels on Canvas.
   * @param dy Y position of copied pixels on Canvas.
   * @param w Width of copied area.
   * @param h Height of copied area.
   */
  public function draw(source:Int, sx:Int, sy:Int, dx:Int, dy:Int, w:Int, h:Int):Void
  {
    commands.push(ImageCommand.Copy(source, sx, sy, dx, dy, w, h));
  }
  
  /**
   * Sets `alpha` velues onto canvas rectangle to desired value.  
   * Does not changing R/G/B values.
   */
  public function fillAlpha(x:Int, y:Int, w:Int, h:Int, alpha:Int):Void
  {
    commands.push(ImageCommand.FillAlpha(x, y, w, h, alpha));
  }
  
  /**
   * Fills given rectangle on canvas with given ARGB `color`.
   */
  public function fill(x:Int, y:Int, w:Int, h:Int, color:Int):Void
  {
    commands.push(ImageCommand.Fill(x, y, w, h, color));
  }
  
  /**
   * Sets pixel on canvas with given ARGB `color`.
   */
  public function setPixel(x:Int, y:Int, color:Int):Void
  {
    commands.push(ImageCommand.Fill(x, y, 1, 1, color)); // TODO: Make it separate?
  }
  
  /**
   * Copies commands from other ImageGen instance.
   */
  public function addCommands(other:ImageGen):Void
  {
    for (com in other.commands)
    {
      commands.push(com);
    }
  }
  
  /**
   * Removes any draw commands.
   */
  public function clearCanvas():Void
  {
    commands = new Array();
  }
  
  /**
   * Removes last draw command.
   */
  public function undo():Void
  {
    if (commands.length > 0) commands.shift();
  }
  
  /**
   * Loads PNG file at `path` and returns it's internal source index.
   */
  public function loadPng(path:String):Int
  {
    ScriptAPI.checkAbsolutePath(path);
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
  
  /**
   * Loads source image from code. Pixels should be in BGRA format.  
   * This functions does not have Bytes size checks, use at own risk.
   */
  public function loadBytes(bytes:Bytes, width:Int, height:Int):Int
  {
    sources.push( {
      width: width,
      height: height,
      pixels: bytes
    });
    return sources.length - 1;
  }
  
  /**
   * Replaces alpha channel of all pixels that equals to `transparent` color on `source` image to zero.  
   * This is permanent function.
   */
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
  
  private function _render():PixelData
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
    if (width == 0 || height == 0) return null;
    var bytes:Bytes = Bytes.alloc(width * height * 4);
    
    for (command in commands)
    {
      switch (command)
      {
        case ImageCommand.Copy(s, sx, sy, dx, dy, w, h):
          blit(bytes, width, sources[s], sx, sy, dx, dy, w, h);
        case ImageCommand.Fill(x, y, w, h, color):
          if (w == 1 && h == 1) _setPixel(bytes, width, x, y, color);
          else _fillColor(bytes, width, x, y, w, h, color);
        case ImageCommand.FillAlpha(x, y, w, h, alpha):
          _fillAlpha(bytes, width, x, y, w, h, alpha);
      }
    }
    
    return {pixels:bytes, width:width, height:height };
  }
  
  /**
   * Saves output PNG image at `path`.  
   * Note that this function ignores outputFolder settings for your scripts.  
   * If you need to save it regarding that folder, use `ImageGen.outputPng` and `saveBytes` functions.
   */
  public function save(path:String):Void
  {
    ScriptAPI.checkAbsolutePath(path);
    var data:PixelData = _render();
    var png:Data = Tools.build32BGRA(data.width, data.height, data.pixels);
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
  
  /**
   * Returns rendered pixels in BGRA format.
   */
  public function outputPixels():Bytes
  {
    return _render().pixels;
  }
  
  /**
   * Returns resulting PNG image data.
   */
  public function outputPng():Bytes
  {
    var data:PixelData = _render();
    var png:Data = Tools.build32BGRA(data.width, data.height, data.pixels);
    var o:BytesOutput = new BytesOutput();
    new Writer(o).write(png);
    return o.getBytes();
  }
  
  /**
   * Returns object with format `{ pixels:Bytes, width:Int, height:Int }`.  
   * (faster) Analogue of `outputPixels()`, `outputWidth()` and `outputHeight()` fundions.
   * @return
   */
  public function outputData():PixelData
  {
    return _render();
  }
  
  /**
   * Returns current width size of canvas.
   */
  public function outputWidth():Int
  {
    var width:Int = 0;
    for (command in commands)
    {
      switch (command)
      {
        case ImageCommand.Copy(s, sx, sy, dx, dy, w, h):
          if (dx + w > width) width = dx + w;
        case ImageCommand.Fill(x, y, w, h, color):
          if (x + w > width) width = x + w;
        case ImageCommand.FillAlpha(x, y, w, h, alpha):
          if (x + w > width) width = x + w;
      }
    }
    return width;
  }
  
  /**
   * Returns current height of canvas.
   */
  public function outputHeight():Int
  {
    var height:Int = 0;
    for (command in commands)
    {
      switch (command)
      {
        case ImageCommand.Copy(s, sx, sy, dx, dy, w, h):
          if (dy + h > height) height = dy + h;
        case ImageCommand.Fill(x, y, w, h, color):
          if (y + h > height) height = y + h;
        case ImageCommand.FillAlpha(x, y, w, h, alpha):
          if (y + h > height) height = y + h;
      }
    }
    return height;
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
  
  private function _setPixel(out:Bytes, outW:Int, x:Int, y:Int, color:Int):Void
  {
    out.setInt32((y * outW + x) * 4, color);
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
  
  /**
   * Returns width of source image at `index`.
   */
  public function sourceWidth(index:Int = 0):Int
  {
    return sources[index].width;
  }
  
  /**
   * Returns height of source image at `index`.
   */
  public function sourceHeight(index:Int = 0):Int
  {
    return sources[index].height;
  }
  
}