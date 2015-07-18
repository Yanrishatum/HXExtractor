package;

/**
 * ...
 * @author Yanrishatum
 */
class StrTools
{

  public static function startsWith(a:String, b:String):Bool
  {
    return StringTools.startsWith(a, b);
  }
  
  public static function endsWith(a:String, b:String):Bool
  {
    return StringTools.endsWith(a, b);
  }
  
  public static function fastCodeAt(a:String, b:Int):Int
  {
    return StringTools.fastCodeAt(a, b);
  }
  
  public static function hex(a:Int, ?b:Int):String
  {
    return StringTools.hex(a, b);
  }
  
  public static function urlEncode( s : String ) : String
  {
    return StringTools.urlEncode(s);
  }
  
  public static function urlDecode( s : String ) : String
  {
    return StringTools.urlDecode(s);
  }
  
  public static function htmlEscape( s : String, ?quotes : Bool ) : String
  {
    return StringTools.htmlEscape(s, quotes);
  }
  
  public static function htmlUnescape( s : String ) : String
  {
    return StringTools.htmlUnescape(s);
  }
  
  public static function isSpace( s : String, pos : Int ) : Bool
  {
    return StringTools.isSpace(s, pos);
  }
  
  public static function ltrim( s : String ) : String
  {
    return StringTools.ltrim(s);
  }
  
  public static function rtrim( s : String ) : String
  {
    return StringTools.rtrim(s);
  }
  
  public static function trim( s : String ) : String
  {
    return StringTools.trim(s);
  }
  
  public static function lpad( s : String, c : String, l : Int ) : String
  {
    return StringTools.lpad(s, c, l);
  }
  
  public static function rpad( s : String, c : String, l : Int ) : String
  {
    return StringTools.rpad(s, c, l);
  }
  
  public static function replace( s : String, sub : String, by : String ) : String
  {
    return StringTools.replace(s, sub, by);
  }
  
  public static inline function isEof( c : Int ) : Bool
  {
    return StringTools.isEof(c);
  }
}