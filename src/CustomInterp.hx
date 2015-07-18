package;
import haxe.Log;
import hscript.Expr.Error;
import hscript.Expr.ErrorDef;
import hscript.Interp;

/**
 * ...
 * @author Yanrishatum
 */
class CustomInterp extends Interp
{

  private var _trace:Dynamic->Void;
  private var file:Array<String>; // lines
  private var name:String;
  
  public function new(filename:String, file:String) 
  {
    super();
    this.name = filename;
    this.file = file.split("\n");
    _trace = variables.get("trace");
  }
  
  override function get(o:Dynamic, f:String):Dynamic 
  {
		if( o == null ) error(EInvalidAccess(f));
		return Reflect.getProperty(o,f);
  }
  
  override function set(o:Dynamic, f:String, v:Dynamic):Dynamic 
  {
		if( o == null ) error(EInvalidAccess(f));
		Reflect.setProperty(o,f,v);
		return Reflect.getProperty(o, f);
  }
  
  override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic 
  {
    if (Reflect.isFunction(o) && f == "bind")
    {
      return function():Void { call(null, o, args); }
    }
    return super.fcall(o, f, args);
  }
  
  override function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic 
  {
    if (Reflect.compareMethods(f, _trace))
    {
      var p:Array<Dynamic> = args.copy();
      p.shift();
      Log.trace(args[0], { fileName: name, lineNumber:getLine(curExpr.pmin), customParams: p, methodName:"execute", className:"Interp" } );
      return null;
    }
    else return super.call(o, f, args);
  }
  
  private function getLine(p:Int):Int
  {
    for (i in 0...file.length)
    {
      if ((p -= file[i].length) <= 0) return i + 1;
    }
    return 0;
  }
  
  public function printVars():Void
  {
    for (key in locals.keys())
    {
      Sys.print(key + " = ");
      var v = locals.get(key);
      if (v != null) Sys.println(Std.string(v.r));
      else Sys.println("null");
    }
  }
  
  public function makeError(e:ErrorDef):Error
  {
    return new Error(e, curExpr.pmin, curExpr.pmax);
  }
  
}