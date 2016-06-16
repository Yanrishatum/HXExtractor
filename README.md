# HXExtractor
Cpp tool designed to rip resources from games. My own project for fun, because I like to extract game resources.  
...  
Well, now I use it just for general scripting on my PC, and less for breaking into game archives.

## Compilation flags

`hxe_allow_absolute_path`  
Allows script to interact with files outside of working directory.

`hxe_allow_http`  
Allows to use http requests.

`hxe_allow_threading`  
Allows using of asynchronous functions.

`hxe_allow_run_scripts`  
Allows invoking script files from code.

`hxe_enable_GifGen`  
Enables usage of GifGen class.  
This class using not-yet-official `format.gif.Writer`. It available in my fork: https://github.com/Yanrishatum/format

## Building from source

### Dependencies:
`hscript`, [git](https://github.com/haxefoundation/hscript) version.  
`format`, My [fork](https://github.com/Yanrishatum/format) of it, if you use `hxe_enable_GifGen`.

### Flags:
```
-D hscriptPos
-D dce=no
```
To enable specific feautres use compilation flags listed above or use `--macro MacroUtils.enableAllFlags()`.  
To generate [API.md](API.md) use `--macro MacroUtils.makeApiMd()`.
