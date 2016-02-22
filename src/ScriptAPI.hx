package;
import cpp.vm.Thread;
import haxe.Http;
import haxe.io.Bytes;
import haxe.io.BytesData;
import haxe.io.BytesOutput;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileSeek;

/**
 * The main API functions available from scripts.  
 * @author Yanrishatum
 */
class ScriptAPI
{
  
  private var c:ScriptContainer;
  
  public function new(parent:ScriptContainer) 
  {
    c = parent;
  }
  
  //==========================================================
  // Utils
  //==========================================================
  
  @:extern
  private inline function input(id:Int):FileInput
  {
    c.lastInput = id;
    return c.inputs[id == -1 ? c.defaultInput : id];
  }
  
  /**
   * Allocates `len` bytes.
   */
  public function alloc(len:Int):Bytes
  {
    return Bytes.alloc(len);
  }
  
  /**
   * Returns script argument at `index`.
   */
  public function arg(index:Int):String
  {
    return c.args[index];
  }
  
  /**
   * Returns a *copy* of script arguments.
   */
  public function args():Array<String>
  {
    return c.args.copy();
  }
  
  /**
   * Returns amount of arguments passed to script.
   */
  public function argCount():Int
  {
    return c.args.length;
  }
  
  //==========================================================
  // Advanced usage and multithreading.
  //==========================================================
  
  /**
   * [Advanced usage] Runs `fn` in separated thread. Use at own risk.
   */
  public function async(fn:Void->Void):Thread
  {
    return Thread.create(fn);
  }
  
  /**
   * [Advanced usage] Executes another script at `path` and returns whaterever it retuns.
   */
  public function runScript(path:String, args:Array<String> = null, variables:Dynamic = null):Dynamic
  {
    var container:ScriptContainer = ScriptContainer.create(path, args, variables);
    return container.execute();
  }
  
  /**
   * [Advanced usage] Executes another script at `path` in separate thread.
   */
  public function runScriptAsync(path:String, args:Array<String> = null, variables:Dynamic = null):Thread
  {
    var container:ScriptContainer = ScriptContainer.create(path, args, variables);
    return Thread.create(container.voidExecute);
  }
  
  /**
   * [Advanced usage] Sends message to main thread.
   */
  public function sendToMainThread(msg:Dynamic):Void
  {
    Main.thread.sendMessage(msg);
  }
  
  /**
   * [Advanced usage] Reads message from another threads.
   */
  public function readMessage(block:Bool):Dynamic
  {
    return Thread.readMessage(block);
  }
  
  //==========================================================
  // Input manipulation
  //==========================================================
  
  /**
   * Reads contents of folder at given `path` and returns file/folder names.
   */
  public function readFolder(path:String):Array<String>
  {
    if (isFolder(path)) return FileSystem.readDirectory(path);
    return null;
  }
  
  /**
   * Propmpt user to write default output folder.  
   * Note that if script has passed arguments, output folder will be set from them, reducing the size of argument list.  
   * If `message` specified, it's content displayed instead of default text.
   */
  public function requestOutputFolder(message:String = null):Void
  {
    if (c.args.length > 0) // Provided by arguments.
    {
      c.outputFolder = c.args.shift();
    }
    else
    {
      if (message == null) Sys.print("Specify an output folder: ");
      else Sys.print(message);
      c.outputFolder = Sys.stdin().readLine();
    }
  }
  
  /**
   * Propmt user to write additional argument to script.
   * Note that if script has passed arguments, next argument will be returned, reducing the size of argument list.  
   * If `message` specified, it's content displayed instead of default text.
   */
  public function requestArgument(message:String = null):String
  {
    if (c.args.length > 0) // Provided by arguments.
    {
      return c.args.shift();
    }
    else
    {
      if (message == null) Sys.print("Enter an argument (no description provided): ");
      else Sys.print(message);
      return return Sys.stdin().readLine();
    }
  }
  
  /**
   * Propmt user to specify input file and returns it's index.  
   * If `index` specified (default = -1), file will be loaded at that index, otherwise index will be assigned automatically.  
   * Note that if script has passed arguments, next argument will be used as file path, reducing the size of argument list.  
   * If `message` specified, it's content displayed instead of default text.  
   * If file cannot be opened, error is printed and returned index = -1.
   */
  public function requestInput(message:String = null, index:Int = -1):Int
  {
    if (index == -1)
    {
      if (c.freeInputSlots.length == 0) index = Lambda.count(c.inputs);
      else index = c.freeInputSlots.shift();
    }
    if (c.args.length > 0) // Provided by arguments.
    {
      return openInput(c.args.shift(), index);
    }
    else
    {
      if (message == null) Sys.print("Specify an input file for index " + index + ": ");
      else Sys.print(message);
      return openInput(Sys.stdin().readLine(), index);
    }
  }
  
  /**
   * Opens a file at `path` and returns it's index.
   * If `index` specified (default = -1), file will be loaded at that index, otherwise index will be assigned automatically.  
   * If file cannot be opened, error is printed and returned index = -1.
   */
  public function openInput(path:String, index:Int = -1):Int
  {
    //if (c.inputNames.exists(path))
    //{
      //return c.inputNames.get(path);
    //}
    
    if (index == -1)
    {
      if (c.freeInputSlots.length == 0) index = Lambda.count(c.inputs);
      else index = c.freeInputSlots.shift();
    }
    
    try
    {
      c.inputs.set(index, File.read(path));
      c.inputNames.set(path, index);
      c.inputStats.set(index, FileSystem.stat(path));
      return index;
    }
    catch (e:Dynamic)
    {
      Sys.println("Error while opening file: " + Std.string(e));
      return -1;
    }
  }
  
  /**
   * Closes active file at `index`.
   */
  public function closeInput(index:Int):Void
  {
    if (c.inputs.exists(index))
    {
      c.inputs.get(index).close();
      c.inputs.remove(index);
      c.eofHandlers.remove(index);
      c.freeInputSlots.push(index);
    }
  }
  
  /**
   * Sets active input `file` which used by default (when index = -1).  
   * Default input file index is 0.
   */
  public function setActive(file:Int):Void
  {
    c.defaultInput = file;
  }
  
  /**
   * Resets active ipnut file.  
   * Equivalent to `setActive(0);`
   */
  public function resetActive():Void
  {
    c.defaultInput = 0;
  }
  
  /**
   * Sets `bigEndian` byte-order to selected input.
   */
  public function bigEndian(file:Int = -1):Void
  {
    input(file).bigEndian = true;
  }
  
  /**
   * Sets `littleEndian` byte-order to selected input.
   */
  public function littleEndian(file:Int = -1):Void
  {
    input(file).bigEndian = false;
  }
  
  //==========================================================
  // Assertions
  //==========================================================
  
  /**
   * Checks string in input equals to expected `string`.  
   * `file` argument specifies input file index.
   */
  public function checkString(string:String, file:Int = -1):Bool
  {
    return input(file).readString(string.length) == string;
  }
  
  /**
   * Checks next byte in input equals to expected `byte`.  
   * `file` argument specifies input file index.
   */
  public function checkByte(byte:Int, file:Int = -1):Bool
  {
    return input(file).readByte() == (byte & 0xFF);
  }
  
  /**
   * Checks next short equals to expected short.  
   * `file` argument specifies input file index.
   */
  public function checkInt16(int16:Int, file:Int = -1):Bool
  {
    return input(file).readInt16() == (int16 & 0xFFFF);
  }
  
  /**
   * Checks next 3 bytes equals to expected value.  
   * `file` argument specifies input file index.
   */
  public function checkInt24(int24:Int, file:Int = -1):Bool
  {
    return input(file).readInt24() == (int24 & 0xFFFFFF);
  }
  
  /**
   * Checks next integer equals to expected value.  
   * `file` argument specifies input file index.
   */
  public function checkInt32(int32:Int, file:Int = -1):Bool
  {
    return input(file).readInt32() == int32;
  }
  
  /**
   * Checks next float equals to expected value.  
   * `file` argument specifies input file index.
   */
  public function checkFloat(f:Float, file:Int = -1):Bool
  {
    return input(file).readFloat() == f;
  }
  
  /**
   * Checks next double equals to expected value.  
   * `file` argument specifies input file index.
   */
  public function checkDouble(f:Float, file:Int = -1):Bool
  {
    return input(file).readDouble() == f;
  }
  
  /**
   * Checks next amount of bytes are equals to expected byte-order.  
   * `file` argument specifies input file index.
   */
  public function checkBytes(b:Bytes, file:Int = -1):Bool
  {
    var f:FileInput = input(file);
    var d:BytesData = b.getData();
    for (i in 0...b.length)
    {
      if (f.readByte() != Bytes.fastGet(d, i)) return false;
    }
    return true;
  }
  
  /**
   * Checks next amount of bytes are equals to expected byte-order.  
   * `file` argument specifies input file index.
   */
  public function checkArrayOfBytes(arr:Array<Int>, file:Int = -1):Bool
  {
    var f:FileInput = input(file);
    for (i in 0...arr.length)
    {
      if (f.readByte() != arr[i]) return false;
    }
    return true;
  }
  
  //==========================================================
  // Script-interrupting assertions.
  //==========================================================
  
  /**
   * Asserts value. If false - prints message and terminates script.
   */
  public function assert(bool:Bool, message:String = null):Void
  {
    if (!bool)
    {
      throw "Script interruped: Assertion failed" + (message != null ? "\n" + message : "");
    }
  }
  
  /**
   * Asserts string in input file. If not equals - prints message and terminates script.
   */
  public function assertString(string:String, file:Int = -1, message:String = null):Void
  {
    var inFile:String = input(file).readString(string.length);
    if (inFile != string)
    {
      throw "Script interruped: String signature not valid. Expected: " + string + ", got: " + inFile + (message != null ? "\n" + message : "");
    }
  }
  
  //==========================================================
  // Data gathering.
  //==========================================================
  
  /**
   * Reads next byte in input `file`.
   */
  public function getByte(file:Int = -1):Int
  {
    return input(file).readByte();
  }
  
  /**
   * Reads next short in input `file`.
   */
  public function getInt16(file:Int = -1):Int
  {
    return input(file).readInt16();
  }
  
  /**
   * Reads next 3 bytes in input `file`.
   */
  public function getInt24(file:Int = -1):Int
  {
    return input(file).readInt24();
  }
  
  /**
   * Reads next integer in input `file`.
   */
  public function getInt32(file:Int = -1):Int
  {
    return input(file).readInt32();
  }
  
  /**
   * Reads String with size of `len`.
   */
  public function getString(len:Int, file:Int = -1):String
  {
    return input(file).readString(len);
  }
  
  /**
   * Reads string with Int32 length prefix.  
   * Analogue to `getString(getInt32(file), file);`
   */
  public function getString32(file:Int = -1):String
  {
    var len:Int = input(file).readInt32();
    return input(file).readString(len);
  }
  
  /**
   * Reads zero-terminated string.
   */
  public function getNullTerminatedString(file:Int = -1):String
  {
    return input(file).readUntil(0);
  }
  
  /**
   * Reads string until `terminator` byte encountered.
   */
  public function getStringUntil(terminator:Int, file:Int = -1):String
  {
    return input(file).readUntil(terminator);
  }
  
  /**
   * Reads one line from `file`.
   */
  public function getLine(file:Int = -1):String
  {
    return input(file).readLine();
  }
  
  /**
   * Reads `len` bytes from `file`.
   */
  public function getBytes(len:Int, file:Int = -1):Bytes
  {
    return input(file).read(len);
  }
  
  //==========================================================
  // File position
  //==========================================================
  
  /**
   * Returns a total size of `file` in bytes.
   */
  public function size(file:Int = -1):Int
  {
    if (file == -1) file = c.defaultInput;
    if (c.inputStats.exists(file))
    {
      return c.inputStats[file].size;
    }
    return -1;
  }
  
  /**
   * Sets `file` position to `offset`.
   */
  public function goto(offset:Int, file:Int = -1):Void
  {
    input(file).seek(offset, FileSeek.SeekBegin);
  }
  
  /**
   * Skip `amount` bytes in `file`.
   */
  public function skip(amount:Int, file:Int = -1):Void
  {
    input(file).seek(amount, FileSeek.SeekCur);
  }
  
  /**
   * Returns current position of `file` caret.
   */
  public function position(file:Int = -1):Int
  {
    return input(file).tell();
  }
  
  //==========================================================
  // HTTP
  //==========================================================
  
  /**
   * Sends an HTTP request to specified `url` and returns output String.
   */
  public function httpGetString(url:String):String
  {
    return Http.requestUrl(url);
  }
  
  /**
   * Sends an HTTP request to specified `url` and returns output Bytes.
   */
  public function httpGet(url:String):Bytes
  {
    var http:Http = new Http(url);
    var output:BytesOutput = new BytesOutput();
    http.customRequest(false, output);
    return output.getBytes();
  }
  
  //==========================================================
  // Saving.
  //==========================================================
  
  /**
   * Saves `length` bytes from input `file` into another file at `path`.
   */
  public function saveFile(path:String, length:Int, file:Int = -1):Void
  {
    if (c.outputFolder != null) path = Path.normalize(c.outputFolder + "/" + path);
    var folder:String = Path.directory(path);
    if (folder != "" && !FileSystem.exists(folder)) FileSystem.createDirectory(folder);
    var b:Bytes = input(file).read(length);
    File.saveBytes(path, b);
  }
  
  /**
   * Saves Bytes at specified `path`.
   */
  public function saveBytes(path:String, data:Bytes):Void
  {
    if (c.outputFolder != null) path = Path.normalize(c.outputFolder + "/" + path);
    var folder:String = Path.directory(path);
    if (folder != "" && !FileSystem.exists(folder)) FileSystem.createDirectory(folder);
    File.saveBytes(path, data);
  }
  
  /**
   * Saves String at specified `path`.
   */
  public function saveString(path:String, string:String):Void
  {
    if (c.outputFolder != null) path = Path.normalize(c.outputFolder + "/" + path);
    var folder:String = Path.directory(path);
    if (folder != "" && !FileSystem.exists(folder)) FileSystem.createDirectory(folder);
    File.saveContent(path, string);
  }
  
  /**
   * Assigns a EOF error callback to `file` at specified index.  
   * If file is closed you need to add callback again.
   */
  public function eofCallback(fn:Void->Void, file:Int = -1):Void
  {
    if (file == -1) file = c.defaultInput;
    if (c.eofHandlers.exists(file))
    {
      var arr:Array<Void->Void> = c.eofHandlers.get(file);
      if (arr.indexOf(fn) == -1) arr.push(fn);
    }
    else
    {
      c.eofHandlers.set(file, [fn]);
    }
    //Main.onEof.push(fn);
  }
  
  /**
   * Tells if file or directory exists at `path`.
   */
  public function fileExists(path:String):Bool
  {
    return FileSystem.exists(path);
  }
  
  /**
   * Checks if given `path` is directory.
   */
  public function isDirectory(path:String):Bool
  {
    return FileSystem.exists(path) && FileSystem.isDirectory(path);
  }
  
  /**
   * Checks if given `path` is directory.  
   * Just a mirror to `isDirectory(path);`.
   */
  public function isFolder(path:String):Bool
  {
    return isDirectory(path);
  }
  
  /**
   * Tells is `path` exists and not a directory.
   */
  public function isFile(path:String):Bool
  {
    return FileSystem.exists(path) && !FileSystem.isDirectory(path);
  }
  
  /**
   * Terminates script.  
   * Currently interrupt by error throw and can be catched by try...catch contruction in script.
   */
  public function exit():Void
  {
    throw "Script terminated with exit() call"; // TODO: Interrupt executing another way. (avoid try/catch of script)
  }
  
}