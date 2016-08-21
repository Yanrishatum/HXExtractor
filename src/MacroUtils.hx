package;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import sys.io.File;

typedef ClassInfo =
{
  var name:String;
  var disp:String;
  @:optional var hideConstructor:Bool;
}

/**
 * ...
 * @author Yanrishatum
 */
class MacroUtils
{
  
  public static function enableAllFlags():Void
  {
    Compiler.define("hxe_allow_absolute_path", "1");
    Compiler.define("hxe_allow_http", "1");
    Compiler.define("hxe_allow_threading", "1");
    Compiler.define("hxe_allow_run_scripts", "1");
    Compiler.define("hxe_enable_GifGen", "1");
    Compiler.define("hxe_enable_Audio", "1");
  }

  public static macro function makeApiMd():Void
  {
    var str:StringBuf = new StringBuf();
    
    str.add("### Notes\r\n* This file is automatically generated.\r\n\r\n");
    
    var classes:Array<ClassInfo> = 
    [
      { name:"ScriptAPI", disp:"Scripting API", hideConstructor:true },
      { name:"ImageGen", disp:"@" },
      // { name:"Math", disp:"@" },
      // { name:"StringTools", disp: "@" },
      // { name:"haxe.io.Path", disp:"Path class" },
      // { name:"Std", disp:"@" },
      // { name:"Reflect", disp:"@" },
      // { name:"EReg", disp:"EReg (Regular Expression) class" },
      // { name:"Xml", disp: "@" },
      // { name:"haxe.Json", disp:"@" },
      // { name:"String", disp:"@" },
      // { name:"Sys", disp:"@" }
      // File and FileSystem doesn't documented.
    ];
    if (Context.defined("hxe_enable_GifGen"))
    {
      classes.push( { name:"GifGen", disp:"@" } );
    }
    
    for (info in classes)
    {
      str.add("### ");
      if (info.disp == "@") str.add(info.name + " class");
      else str.add(info.disp);
      str.add("\r\n");
      genAPI(info.name, str, info.hideConstructor != true);
    }
    
    //str.add("### Scripting API\r\n");
    //genAPI("ScriptAPI", str, false);
    //
    //str.add("### ImageGen class\r\n");
    //genAPI("ImageGen", str, true);
    
    File.saveContent("API.md", str.toString());
  }
  
  public static macro function makeReadme():Expr
  {
    var str:StringBuf = new StringBuf();
    var t:ClassType = cl(Context.getType("ScriptAPI"));
    
    for (field in t.fields.get())
    {
      if (field.isPublic)
      {
        switch (field.type)
        {
          case Type.TLazy(f):
            addLazey(field, str, f());
          case Type.TFun(args, ret):
            add(field, str, args, ret);
          default:
        }
      }
    }
    
    var out:String = str.toString();
    
    return macro $v{out};
  }
  
  #if macro
  
  private static function genAPI(cls:String, str:StringBuf, displayContructor:Bool):Void
  {
    var t:ClassType = cl(Context.getType(cls));
    
    if (t.doc != null)
    {
      str.add(formatDoc(t.doc));
      str.add("\r\n");
    }
    
    var funcs:Array<ClassField> = new Array();
    var variables:Array<ClassField> = new Array();
    var properties:Array<ClassField> = new Array();
    
    for (field in t.fields.get())
    {
      if (field.isPublic)
      {
        switch (field.kind)
        {
          case FieldKind.FMethod(k):
            if (k == MethodKind.MethNormal) funcs.push(field);
          case FieldKind.FVar(r, w):
            if (r == VarAccess.AccNormal && w == VarAccess.AccNormal) variables.push(field);
            else properties.push(field);
        }
      }
    }
    
    if (funcs.length > 0) str.add("#### Functions\r\n");
    
    for (func in funcs)
    {
      switch (func.type)
      {
        case Type.TFun(args, ret):
          add(func, str, args, ret);
        case Type.TLazy(f):
          addLazey(func, str, f());
        default:
          trace(func.type);
      }
    }
    
    //trace(variables.length);
    //trace(properties.length);
  }
  
  private static function addLazey(field:ClassField, str:StringBuf, l:Type):Void
  {
    switch (l)
    {
      case Type.TLazy(f):
        addLazey(field, str, f());
      case Type.TFun(args, ret):
        add(field, str, args, ret);
      default:
    }
  }
  
  private static function add(field:ClassField, str:StringBuf, args:Array<{name:String, opt:Bool, t:Type}>, ret:Type)
  {
    str.add('`');
    str.add(field.name);
    str.addChar("(".code);
    var i:Int = 0;
    for (arg in args)
    {
      if (arg.opt) str.addChar("?".code);
      str.add(arg.name);
      str.addChar(":".code);
      str.add(typeToString(arg.t));
      if (++i != args.length) str.add(", ");
    }
    str.add("):");
    str.add(typeToString(ret));
    str.add('`  \n');
    if (field.doc != null)
    {
      str.add(formatDoc(field.doc));
    }
    else
    {
      str.add("No docs available");
    }
    str.add("  \r\n\r\n");
  }
  
  private static inline function formatDoc(doc:String):String
  {
    return StringTools.trim(~/[ ]+\* (.*)/g.replace(~/@author .*\r\n/.replace(doc, ""), "$1"));
  }
  
  private static function typeToString(t:Type):String
  {
    switch (t)
    {
      case Type.TAbstract(t, p):
        return t.get().name + paramsToString(p, "<", ">");
      case Type.TAnonymous(a):
        return "TAnonymous";
      case Type.TDynamic(t):
        return "TDynamic()";
      case Type.TEnum(t, p):
        return t.get().name + paramsToString(p, "<", ">");
      case Type.TFun(a, r):
        var str:StringBuf = new StringBuf();
        for (arg in a)
        {
          if (arg.opt) str.addChar("?".code);
          str.add(typeToString(arg.t));
          str.add(" -> ");
        }
        str.add(typeToString(r));
        return str.toString();
      case Type.TInst(t, p):
        return t.get().name + paramsToString(p, "<", ">");
      case Type.TLazy(f):
        return "TLazy(" + typeToString(f()) + ")";
      case Type.TMono(t):
        var r:Type = t.get();
        return r == null ? "TMono(null)" : "TMono(" + typeToString(r) + ")";
      case Type.TType(t, p):
        return t.get().name + paramsToString(p, "<", ">");
    }
  }
  
  private static function paramsToString(arr:Array<Type>, left:String = "", right:String = ""):String
  {
    if (arr == null || arr.length == 0) return "";
    var str:StringBuf = new StringBuf();
    str.add(typeToString(arr[0]));
    for (i in 1...arr.length)
    {
      str.add(", ");
      str.add(typeToString(arr[i]));
    }
    return left + str.toString() + right;
  }
  
  private static function cl(t:Type):ClassType
  {
    switch (t)
    {
      case Type.TInst(t, p):
        return t.get();
      default: return null;
    }
  }
  #end
  
}