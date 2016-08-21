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
import sys.io.FileOutput;
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
  
  @:extern
  public static inline function checkAbsolutePath(path:String):Void
  {
    #if !hxe_allow_absolute_path
    if (Path.isAbsolute(path) || Path.normalize(path).indexOf("..") != -1)
    {
      throw "Going out of working directory does not allowed until `hxe_allow_absolute_path` compilation flag set.";
    }
    #end
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
  
  public function wait(timeout:Float):Void
  {
    Main.lock.wait(timeout);
  }
  
  //==========================================================
  // Advanced usage and multithreading.
  //==========================================================
  
  #if hxe_allow_run_scripts
  
  /**
   * [hxe_allow_run_scripts][Advanced usage] Executes another script at `path` and returns whaterever it retuns.
   */
  public function runScript(path:String, args:Array<String> = null, variables:Dynamic = null):Dynamic
  {
    checkAbsolutePath(path);
    var container:ScriptContainer = ScriptContainer.create(path, args, variables);
    return container.execute();
  }
  
  #if hxe_allow_threading
  
  /**
   * [hxe_allow_threading][hxe_allow_run_scripts][Advanced usage] Executes another script at `path` in separate thread.
   */
  public function runScriptAsync(path:String, args:Array<String> = null, variables:Dynamic = null):Thread
  {
    checkAbsolutePath(path);
    var container:ScriptContainer = ScriptContainer.create(path, args, variables);
    return Thread.create(container.voidExecute);
  }
  
  #end
  
  #end
  
  #if hxe_allow_threading
  
  /**
   * [hxe_allow_threading][Advanced usage] Runs `fn` in separated thread. Use at own risk.
   */
  public function async(fn:Void->Void):Thread
  {
    return Thread.create(fn);
  }
  
  /**
   * [hxe_allow_threading][Advanced usage] Sends message to main thread.
   */
  public function sendToMainThread(msg:Dynamic):Void
  {
    Main.thread.sendMessage(msg);
  }
  
  /**
   * [hxe_allow_threading][Advanced usage] Reads message from another threads.
   */
  public function readMessage(block:Bool):Dynamic
  {
    return Thread.readMessage(block);
  }
  
  #end
  
  //==========================================================
  // Input manipulation
  //==========================================================
  
  /**
   * Reads contents of a directory at given `path` and returns file/folder names.  
   * Same as `readDirectory`.
   */
  public function readFolder(path:String):Array<String>
  {
    return readDirectory(path);
  }
  
  /**
   * 
   * Reads contents of a directory at given `path` and returns file/folder names.
   */
  public function readDirectory(path:String):Array<String>
  {
    checkAbsolutePath(path);
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
    var path:String;
    if (c.args.length > 0) // Provided by arguments.
    {
      path = c.args.shift();
    }
    else
    {
      if (message == null) Sys.print("Specify an output folder: ");
      else Sys.print(message);
      path = Sys.stdin().readLine();
    }
    checkAbsolutePath(path);
    c.outputFolder = path;
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
   * If file cannot be opened, error is thrown. // TODO: Make it specific error...
   * If `hxe_allow_absolute_path` compilation flag wasn't set `path` does not allowed to go outside working directory.
   */
  public function openInput(path:String, index:Int = -1):Int
  {
    checkAbsolutePath(path);
    
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
      throw "Error while opening file: " + Std.string(e);
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
   * Reads next byte in input `file.  
   * Same as `getByte`.
   */
  public function getInt8(file:Int = -1):Int
  {
    return input(file).readByte();
  }
  
  /**
   * Reads next byte in input `file`.  
   * Same as `getInt8`.
   */
  public function getByte(file:Int = -1):Int
  {
    return input(file).readByte();
  }
  
  /**
   * Reads next short int in input `file`.  
   * Same as `getShort`.
   */
  public function getInt16(file:Int = -1):Int
  {
    return input(file).readInt16();
  }
  
  /**
   * Reads next short int in input `file`.  
   * Same as `getInt16`.
   */
  public function getShort(file:Int = -1):Int
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
  
  /**
   * Reads float from `file`.
   */
  public function getFloat(file:Int = -1):Float
  {
    return input(file).readFloat();
  }
  
  /**
   * Reads double from `file`.
   */
  public function getDouble(file:Int = -1):Float
  {
    return input(file).readDouble();
  }
  
  //==========================================================
  // Input information
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
   * Same as `setPosition`.
   */
  public function goto(offset:Int, file:Int = -1):Void
  {
    input(file).seek(offset, FileSeek.SeekBegin);
  }
  
  /**
   * Sets `file` position to `offset`.  
   * Same as `goto`.
   */
  public function setPosition(offset:Int, file:Int = -1):Void
  {
    goto(offset, file);
  }
  
  /**
   * Skip `amount` bytes in `file`.  
   * Same as `offset`.
   */
  public function skip(amount:Int, file:Int = -1):Void
  {
    input(file).seek(amount, FileSeek.SeekCur);
  }
  
  /**
   * Skip `amount` bytes in `file`.  
   * Same as `skip`.
   */
  public function offset(amount:Int, file:Int = -1):Void
  {
    skip(amount, file);
  }
  
  /**
   * Returns current position of `file` caret.
   */
  public function position(file:Int = -1):Int
  {
    return input(file).tell();
  }
  
  /**
   * Returns path to input at given `index`.
   */
  public function inputPath(index:Int = -1):String
  {
    if (index == -1) index = c.defaultInput;
    for (name in c.inputNames.keys())
    {
      if (c.inputNames[name] == index) return name;
    }
    return null;
  }
  
  //==========================================================
  // HTTP
  //==========================================================
  
  #if hxe_allow_http
  
  /**
   * [hxe_allow_http] Sends an HTTP GET request to specified `url` and returns output String.
   */
  public function httpGetString(url:String):String
  {
    return httpGet(url).toString();
    //var redirectChain:String = url;
    //var output:String;
    //var http:Http = null;
    //
    //function redirectCheck(status:Int):Void
    //{
      //if (status == 301)
      //{
        //// Redirect
        //redirectChain = http.responseHeaders.get("Location");
      //}
    //}
    //
    //function onData(data:String):Void
    //{
      //output = data;
    //}
    //
    //function onError(e:String):Void
    //{
      //throw e;
    //}
    //
    //do
    //{
      //url = redirectChain;
      //redirectChain = null;
      //
      //http = new Http(url);
      //output = null;
      //http.onData = onData;
      //http.onError = onError;
      //http.onStatus = redirectCheck;
      //http.request(false);
    //}
    //while (redirectChain != null);
    //
    //return output;
    
    //return Http.requestUrl(url);
  }
  
  /**
   * [hxe_allow_http] Sends an HTTP GET request to specified `url` and returns output Bytes.
   */
  public function httpGet(url:String):Bytes
  {
    var redirectChain:String = url;
    var output:BytesOutput;
    var http:Http = null;
    
    function redirectCheck(status:Int):Void
    {
      if (status == 301)
      {
        // Redirect
        redirectChain = http.responseHeaders.get("Location");
      }
    }
    
    do
    {
      url = redirectChain;
      redirectChain = null;
      
      http = new Http(url);
      output = new BytesOutput();
      
      http.onStatus = redirectCheck;
      http.customRequest(false, output);
    }
    while (redirectChain != null);
    //trace(http.responseHeaders);
    return output.getBytes();
  }
  
  public function httpGetResponseHeaders(url:String):Map<String, String>
  {
    var http:Http = new Http(url);
    http.request(false);
    return http.responseHeaders;
  }
  
  // TODO: Move it to hxe_allow_ftp or rename flag to hxe_allow_net
  @:extern
  private inline function createFTP(url:String, user:String, pass:String):Ftp
  {
    var split:Array<String> = url.split("/");
    if (split[0].toLowerCase() != "ftp:")
    {
      trace("Not FTP url");
      return null;
    }
    var host:String = split[2];
    var port:Null<Int> = null;
    
    var portIndex:Int = host.indexOf(":");
    if (portIndex != -1)
    {
      port = Std.parseInt(host.substr(portIndex + 1));
      host = host.substr(0, portIndex);
    }
    
    var ftp:Ftp = new Ftp(host, port);
    //ftp.debug = true;
    ftp.login(user, pass);
    
    return ftp;
  }
  
  public function ftpCreate(url:String, user:String, pass:String):Ftp
  {
    var ftp:Ftp = createFTP(url, user, pass);
    if (ftp != null)
    {
      var split:Array<String> = url.split("/");
      var dir:String = split.length == 3 ? "" : split.splice(3, split.length - 3).join("/");
      if (dir != "") ftp.cwd(dir);
    }
    return ftp;
  }
  
  public function ftpReadDirectory(url:String, ?user:String, ?pass:String):Array<String>
  {
    var ftp:Ftp = createFTP(url, user, pass);
    if (ftp == null) return null;
    //var dir:String = "";
    var split:Array<String> = url.split("/");
    var dir:String = split.length == 3 ? "" : split.splice(3, split.length - 3).join("/");
    var list:Array<String> = ftp.detailedList(dir);
    ftp.close();
    return list;
    //var ftp:Ftp = new 
  }
  
  public function ftpGet(url:String, ?user:String, ?pass:String):Bytes
  {
    var ftp:Ftp = createFTP(url, user, pass);
    if (ftp == null) return null;
    //var dir:String = "";
    var split:Array<String> = url.split("/");
    var dir:String = split.length == 3 ? "" : split.splice(3, split.length - 3).join("/");
    var out:BytesOutput = new BytesOutput();
    ftp.get(out, dir);
    ftp.close();
    return out.getBytes();
  }
  
  public function ftoGetString(url:String, ?user:String, ?pass:String):String
  {
    var bytes:Bytes = ftpGet(url, user, pass);
    if (bytes == null) return null;
    return bytes.toString();
  }
  
  #end
  
  //==========================================================
  // Saving.
  //==========================================================
  
  public function createOutput(path:String):FileOutput
  {
    if (c.outputFolder != null) path = Path.join([c.outputFolder, path]);
    checkAbsolutePath(path);
    var folder:String = Path.directory(path);
    if (folder != "" && !FileSystem.exists(folder)) FileSystem.createDirectory(folder);
    return File.write(path);
  }
  
  /**
   * Saves `length` bytes from input `file` into another file at `path`.
   */
  public function saveFile(path:String, length:Int, file:Int = -1):Void
  {
    if (c.outputFolder != null) path = Path.join([c.outputFolder, path]);
    checkAbsolutePath(path);
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
    if (c.outputFolder != null) path = Path.join([c.outputFolder, path]);
    checkAbsolutePath(path);
    var folder:String = Path.directory(path);
    if (folder != "" && !FileSystem.exists(folder)) FileSystem.createDirectory(folder);
    File.saveBytes(path, data);
  }
  
  /**
   * Saves String at specified `path`.
   */
  public function saveString(path:String, string:String):Void
  {
    if (c.outputFolder != null) path = Path.join([c.outputFolder, path]);
    checkAbsolutePath(path);
    var folder:String = Path.directory(path);
    if (folder != "" && !FileSystem.exists(folder)) FileSystem.createDirectory(folder);
    File.saveContent(path, string);
  }
  
  /**
   * Assigns an EOF error callback to `file` at specified index.  
   * If you reopen file at that index, eof callbacks should be added again.
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
    checkAbsolutePath(path);
    return FileSystem.exists(path);
  }
  
  /**
   * Checks if given `path` is directory.
   */
  public function isDirectory(path:String):Bool
  {
    checkAbsolutePath(path);
    return FileSystem.exists(path) && FileSystem.isDirectory(path);
  }
  
  /**
   * Checks if given `path` is directory.  
   * Just a mirror to `isDirectory(path);`.
   */
  public function isFolder(path:String):Bool
  {
    checkAbsolutePath(path);
    return isDirectory(path);
  }
  
  /**
   * Tells is `path` exists and not a directory.
   */
  public function isFile(path:String):Bool
  {
    checkAbsolutePath(path);
    return FileSystem.exists(path) && !FileSystem.isDirectory(path);
  }
  
  /**
   * Tells size of a file at specified path. Make sure you checked that file exists.
   */
  public function fileSize(path:String):Int
  {
    return FileSystem.stat(path).size;
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