package;
import cpp.vm.Thread;
import haxe.io.Bytes;
import haxe.io.BytesData;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileSeek;

/**
 * ...
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
   * Sends message to main thread.
   */
  public function sendToMainThread(msg:Dynamic):Void
  {
    Main.thread.sendMessage(msg);
  }
  
  /**
   * Reads message from another threads.
   */
  public function readMessage(block:Bool):Dynamic
  {
    return Thread.readMessage(block);
  }
  
  //==========================================================
  // Input manipulation
  //==========================================================
  
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
   * Requests input file. Arguments for script taken first.
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
   * Opens file for input.
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
      return index;
    }
    catch (e:Dynamic)
    {
      Sys.println("Error while opening file: " + Std.string(e));
      return -1;
    }
  }
  
  /**
   * Closes opened input file.
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
   * Sets active input file which used by default.
   */
  public function setActive(file:Int):Void
  {
    c.defaultInput = file;
  }
  
  /**
   * Resets active ipnut file. Equivalent to setActive(0);
   */
  public function resetActive():Void
  {
    c.defaultInput = 0;
  }
  
  /**
   * Sets bigEndian to selected input.
   */
  public function bigEndian(file:Int = -1):Void
  {
    input(file).bigEndian = true;
  }
  
  /**
   * Sets littleEndian to selected input.
   */
  public function littleEndian(file:Int = -1):Void
  {
    input(file).bigEndian = false;
  }
  
  //==========================================================
  // Assertions
  //==========================================================
  
  /**
   * Checks string in input equals to expected string.
   */
  public function checkString(string:String, file:Int = -1):Bool
  {
    return input(file).readString(string.length) == string;
  }
  
  /**
   * Checks next byte in input equals to expected byte.
   */
  public function checkByte(byte:Int, file:Int = -1):Bool
  {
    return input(file).readByte() == (byte & 0xFF);
  }
  
  /**
   * Checks next short equals to expected short.
   */
  public function checkInt16(int16:Int, file:Int = -1):Bool
  {
    return input(file).readInt16() == (int16 & 0xFFFF);
  }
  
  public function checkInt24(int24:Int, file:Int = -1):Bool
  {
    return input(file).readInt24() == (int24 & 0xFFFFFF);
  }
  
  public function checkInt32(int32:Int, file:Int = -1):Bool
  {
    return input(file).readInt32() == int32;
  }
  
  public function checkFloat(f:Float, file:Int = -1):Bool
  {
    return input(file).readFloat() == f;
  }
  
  public function checkDouble(f:Float, file:Int = -1):Bool
  {
    return input(file).readDouble() == f;
  }
  
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
  
  public function getByte(file:Int = -1):Int
  {
    return input(file).readByte();
  }
  
  public function getInt16(file:Int = -1):Int
  {
    return input(file).readInt16();
  }
  
  public function getInt24(file:Int = -1):Int
  {
    return input(file).readInt24();
  }
  
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
   * Reads string until null (0) byte encounterd.
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
   * Reads one line from file.
   */
  public function getLine(file:Int = -1):String
  {
    return input(file).readLine();
  }
  
  /**
   * Reads `len` bytes from file.
   */
  public function getBytes(len:Int, file:Int = -1):Bytes
  {
    return input(file).read(len);
  }
  
  //==========================================================
  // File position
  //==========================================================
  
  /**
   * Sets file position to `offset`.
   */
  public function goto(offset:Int, file:Int = -1):Void
  {
    input(file).seek(offset, FileSeek.SeekBegin);
  }
  
  /**
   * Skip `amount` bytes in file.
   */
  public function skip(amount:Int, file:Int = -1):Void
  {
    input(file).seek(amount, FileSeek.SeekCur);
  }
  
  /**
   * Returns current position of file caret.
   */
  public function position(file:Int = -1):Int
  {
    return input(file).tell();
  }
  
  //==========================================================
  // Saving.
  //==========================================================
  
  /**
   * Saves `length` bytes from input file into another file at `path`.
   */
  public function saveFile(path:String, length:Int, file:Int = -1):Void
  {
    if (c.outputFolder != null) path = Path.normalize(c.outputFolder + "/" + path);
    var folder:String = Path.directory(path);
    try
    {
      FileSystem.createDirectory(folder);
    }
    catch (e:Dynamic) { };
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
    try
    {
      FileSystem.createDirectory(folder);
    }
    catch (e:Dynamic) { };
    File.saveBytes(path, data);
  }
  
  /**
   * Saves String at specified `path`.
   */
  public function saveString(path:String, string:String):Void
  {
    if (c.outputFolder != null) path = Path.normalize(c.outputFolder + "/" + path);
    var folder:String = Path.directory(path);
    try
    {
      FileSystem.createDirectory(folder);
    }
    catch (e:Dynamic) { };
    File.saveContent(path, string);
  }
  
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
   * Tells is file exists at `path`.
   */
  public function fileExists(path:String):Bool
  {
    return FileSystem.exists(path);
  }
  
  /**
   * Tells is `path` exists and is directory.
   */
  public function isDirectory(path:String):Bool
  {
    return FileSystem.exists(path) && FileSystem.isDirectory(path);
  }
  
  /**
   * Tells is `path` exists and is file.
   */
  public function isFile(path:String):Bool
  {
    return FileSystem.exists(path) && !FileSystem.isDirectory(path);
  }
  
  /**
   * Terminates script.
   */
  public function exit():Void
  {
    throw "Script terminated with exit() call"; // TODO: Interrupt executing another way. (avoid try/catch of script)
  }
  
}