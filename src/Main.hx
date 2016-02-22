package;

import cpp.Lib;
import cpp.vm.Thread;
import haxe.io.Eof;
import haxe.io.Input;
import haxe.io.Path;
import haxe.Json;
import haxe.Log;
import hscript.Expr;
import hscript.Interp;
import hscript.Parser;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;

/**
 * ...
 * @author Yanrishatum
 */
class Main 
{
	private static var scriptData:String;
  private static var script:Expr;
  public static var files:Array<String>;
  public static var display:Bool = false;
  public static var fileNameToFolder:Bool = false;
  public static var onEof:Array<Void->Void>;
  
  public static var quickAccess:Map<String, Dynamic> =
  [
    "Math" => Math,
    "StringTools" => StringTools,
    "Path" => Path,
    "ImageGen" => ImageGen,
    "Std" => Std,
    "Reflect" => Reflect,
    "EReg" => EReg,
    "Xml" => Xml,
    "Json" => Json,
    "String" => String,
    "fromCharCode" => String.fromCharCode,
    "Sys" => Sys,
    "sys" => { io: { File:File }, FileSystem:FileSystem }
  ];
  
  public static var thread:Thread;
  
	static function main() 
	{
    thread = Thread.current();
		var args:Array<String> = Sys.args();
    if (args.length != 0)
    {
      var scriptPath:String = args[0];
      if (!FileSystem.exists(scriptPath))
      {
        Sys.println("File not found");
        return;
      }
      var folder:String = Path.directory(scriptPath);
      scriptPath = Path.withoutDirectory(scriptPath);
      scriptData = File.getContent(scriptPath);
      
      Sys.setCwd(folder);
      
      var scriptArgs:Array<String> = args.copy();
      scriptArgs.shift();
      
      var c:ScriptContainer = new ScriptContainer(scriptPath, scriptData, scriptArgs);
      c.execute();
    }
    else
    {
      //Sys.println("API:");
      //Sys.println(MacroUtils.makeReadme());
    }
	}
	
  public static function printError(e:Error, script:String)
  {
    if (e.e != null)
    {
      switch (e.e)
      {
        case ErrorDef.EUnterminatedComment:
          Sys.println("Unterminated commentary");
        case ErrorDef.EUnterminatedString:
          Sys.println("Unterminated String");
        case ErrorDef.EInvalidAccess(f):
          Sys.println("Invalid Access: " + f);
        case ErrorDef.EInvalidChar(c):
          Sys.println("Invalid character: " + c + " (" + String.fromCharCode(c) + ")");
        case ErrorDef.EInvalidIterator(v):
          Sys.println("Invalid iterator: " + v);
        case ErrorDef.EInvalidOp(op):
          Sys.println("Invalid operation: " + op);
        case ErrorDef.EUnexpected(s):
          Sys.println("Unexpected: " + s);
        case ErrorDef.EUnknownVariable(v):
          Sys.println("Unknown variable: " + v);
      }
    }
    if (script == null)
    {
      Sys.println("PMin: " + e.pmin + ", PMax: " + e.pmax);
      return;
    }
    
    var lines:Array<String> = script.split("\n");
    var errMin:Int = 1;
    var errMax:Int = 1;
    var min:Int = e.pmin;
    var max:Int = e.pmax;
    var minFound:Bool = false;
    
    for (line in lines)
    {
      if (!minFound && min - line.length - 1 >= 0)
      {
        min -= line.length + 1;
        errMin++;
      }
      else 
        minFound = true;
      max -= line.length + 1;
      if (max < 0)
      {
        max += line.length + 1;
        break;
      }
      errMax++;
    }
    
    if (errMin > lines.length+1)
    {
      Sys.println("Unknown pos: " +e.pmin + ", " + e.pmax + ", " + errMin + ", " + min);
      return;
    }
    if (errMax > lines.length+1)
    {
      errMax = lines.length;
      max = lines[errMax - 1].length;
    }
    
    // Same-line
    if (errMin == errMax)
    {
      Sys.println('Error on line #$errMin, chars $min-$max');
      var line:String = lines[errMin - 1];
      var highlight:StringBuf = new StringBuf();
      for (i in 0...max)
      {
        if (i < min) highlight.addChar(' '.code);
        else if (i == min) highlight.addChar('v'.code);
        else highlight.addChar('-'.code);
      }
      highlight.addChar('|'.code);
      Sys.println(highlight.toString());
      Sys.println(line);
    }
    else // Multiline error
    {
      Sys.println('Error on lines #$errMin (char $min) - #$errMax (char $max)');
      
      var line:String = lines[errMin - 1];
      var highlight:StringBuf = new StringBuf();
      var len:Int = line.length < min ? min + 1 : line.length;
      for (i in 0...len)
      {
        if (i < min) highlight.addChar(' '.code);
        else if (i == min) highlight.addChar('v'.code);
        else highlight.addChar('-'.code);
      }
      Sys.println(highlight.toString());
      Sys.println(line);
      
      line = lines[errMax - 1];
      highlight = new StringBuf();
      for (i in 0...max)
      {
        if (i < max) highlight.addChar('-'.code);
      }
      highlight.addChar('|'.code);
      Sys.println(highlight.toString());
      Sys.println(line);
    }
  }
  
}