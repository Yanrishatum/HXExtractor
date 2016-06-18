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

## Building from source

### Dependencies:
`hscript`, [git](https://github.com/haxefoundation/hscript) version.  
`format`, [git](https://github.com/haxefoundation/format) version, if you use `hxe_enable_GifGen` (stable will do as soon as they release version with `git.format.Writer` included).

### Flags:
```
-D hscriptPos
-D dce=no
```
To enable specific feautres use compilation flags listed above or use `--macro MacroUtils.enableAllFlags()`.  
To generate [API.md](API.md) use `--macro MacroUtils.makeApiMd()`.
