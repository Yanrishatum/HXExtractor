package;
import haxe.CallStack;
import haxe.io.Eof;
import haxe.io.Input;
import haxe.io.Path;
import hscript.Expr;
import hscript.Interp;
import hscript.Parser;
import sys.FileStat;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileOutput;

/**
 * ...
 * @author Yanrishatum
 */
class ScriptContainer
{

  public var inputs:Map<Int, FileInput>;
  public var inputNames:Map<String, Int>;
  public var inputStats:Map<Int, FileStat>;
  public var freeInputSlots:Array<Int>;
  
  public var defaultInput:Int;
  public var lastInput:Int;
  
  public var outputs:Map<Int, FileOutput>;
  public var outputNames:Map<String, Int>;
  public var freeOutputSlots:Array<Int>;
  
  public var outputFolder:String;
  
  public var script:Expr;
  public var scriptRaw:String;
  
  private var interp:CustomInterp;
  
  public var args:Array<String>;
  
  private var api:ScriptAPI;
  
  public var eofHandlers:Map<Int, Array<Void->Void>>;
  
  public static function create(path:String, args:Array<String>, variables:Dynamic):ScriptContainer
  {
    if (!FileSystem.exists(path))
    {
      Sys.println("File not found");
      return null;
    }
    var scriptData:String = File.getContent(path);
    
    var c:ScriptContainer = new ScriptContainer(path, scriptData, args.copy());
    
    if (variables != null)
    {
      var fields:Array<String> = Reflect.fields(variables);
      for (field in fields)
      {
        c.interp.variables.set(field, Reflect.field(variables, field));
      }
    }
    
    return c;
  }
  
  public function new(scriptName:String, scriptData:String, args:Array<String>) 
  {
    inputs = new Map();
    inputNames = new Map();
    inputStats = new Map();
    freeInputSlots = new Array();
    
    defaultInput = 0;
    
    outputs = new Map();
    outputNames = new Map();
    freeOutputSlots = new Array();
    
    eofHandlers = new Map();
    
    outputFolder = ".";
    
    this.args = args;
    
    scriptRaw = StringTools.replace(scriptData, "\r", "");
    
    try
    {
      var parser:Parser = new Parser();
      this.script = parser.parseString(scriptRaw);
    }
    catch (e:Error)
    {
      Sys.println("Script parsing error:");
      Main.printError(e, scriptRaw);
    }
    
    api = new ScriptAPI(this);
    
    createInterp(scriptName);
  }
  
  private inline function createInterp(n:String):Void
  {
    interp = new CustomInterp(n, scriptRaw);
    for (key in Main.quickAccess.keys())
    {
      interp.variables.set(key, Main.quickAccess.get(key));
    }
    
    var fields:Array<String> = Type.getInstanceFields(ScriptAPI);
    for (field in fields)
    {
      if (field == "c") continue; // Skip instance reference.
      interp.variables.set(field, Reflect.field(api, field));
    }
  }
  
  // For threads.
  public function voidExecute():Void
  {
    execute();
  }
  
  public function execute():Dynamic
  {
    var r:Dynamic = null;
    
    try
    {
      r = interp.execute(script);
    }
    catch (e:Eof)
    {
      if (lastInput == -1) lastInput = defaultInput;
      if (eofHandlers.exists(lastInput))
      {
        var handlers:Array<Void->Void> = eofHandlers.get(lastInput);
        for (handler in handlers) handler();
      }
      else
      {
        var filename:String = "#" + Std.string(lastInput);
        for (key in inputNames.keys())
        {
          if (inputNames.get(key) == lastInput)
          {
            filename = key;
            break;
          }
        }
        Sys.println("Runtime error:");
        Sys.println("EOF in file " + filename);
        Main.printError(interp.makeError(null), scriptRaw);
      }
    }
    catch (e:Error)
    {
      Sys.println("Runtime error:");
      Main.printError(e, scriptRaw);
      interp.printVars();
    }
    catch (e:Dynamic)
    {
      Sys.println("Runtime error:");
      Sys.println(Std.string(e));
      Sys.println(CallStack.toString(CallStack.exceptionStack()));
      Sys.print("\n");
      Main.printError(interp.makeError(null), scriptRaw);
    }
    
    for (input in inputs)
    {
      input.close();
    }
    return r;
  }
  
}