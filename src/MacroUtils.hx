package;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

/**
 * ...
 * @author Yanrishatum
 */
class MacroUtils
{

  
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
    if (field.doc != null)
    {
      str.add("\n");
      str.add(StringTools.trim(StringTools.replace(field.doc, "\n   * ", " ")));
    }
    str.addChar("\n".code);
    str.addChar("\n".code);
  }
  
  
  private static function typeToString(t:Type):String
  {
    switch (t)
    {
      case Type.TAbstract(t, p):
        return t.get().name + paramsToString(p);
      case Type.TAnonymous(a):
        return "TAnonymous";
      case Type.TDynamic(t):
        return "TDynamic()";
      case Type.TEnum(t, p):
        return t.get().name + paramsToString(p);
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
        return t.get().name + paramsToString(p);
      case Type.TLazy(f):
        return "TLazy(" + typeToString(f()) + ")";
      case Type.TMono(t):
        var r:Type = t.get();
        return r == null ? "TMono(null)" : "TMono(" + typeToString(r) + ")";
      case Type.TType(t, p):
        return t.get().name + paramsToString(p);
    }
  }
  
  private static function paramsToString(arr:Array<Type>):String
  {
    if (arr == null || arr.length == 0) return "";
    var str:StringBuf = new StringBuf();
    str.add(typeToString(arr[0]));
    for (i in 1...arr.length)
    {
      str.add(", ");
      str.add(typeToString(arr[i]));
    }
    return str.toString();
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