@echo off

rem
rem Build using Visual Studio development environment:
rem
rem     vs_build.bat [option]...
rem
rem Where the available options are:
rem
rem  - verbose                   : turn on verbose mode (default off)
rem  - [release|debug]           : target build mode    (default release)
rem  - [x86|x86_64]              : target architecture  (default hostarch)
rem  - [build|clean|rebuild|run] : command to evaluate  (default build)
rem  - [DIR]                     : a directory containing the vs_conf.bat build config  (default current)
rem
rem
rem The actual build configuration is loaded from a file called vs_conf.bat
rem in the specified DIR (by default the current directory).
rem 
rem If the file vs_conf.local.bat exists, it will be loaded instead of
rem vs_conf.bat.  So to make changes that should not be put under version
rem control, simply copy vs_conf.bat to vs_conf.local.bat and make 
rem changes there.
rem 
rem The configuration variables that can be set in vs_conf.bat are:
rem
rem     set build_dir=<dir>        : base directory for build output
rem 
rem     set target_name=<basename>
rem     set target_type=[exe|dll|lib]
rem     set target_version=<major.minor>
rem 
rem     set run_args=<command line args for running the target>
rem 
rem     set enable_assembly=[0|1]  : output assembly code
rem     set enable_openmp=[0|1]    : enable OpenMP 2.0
rem     set enable_winmain=[0|1]   : use WinMain() instead of main()
rem     set enable_profile=[0|1]   : add /profile compiler flag
rem     set enable_ltcg=[0|1]      : enable whole program optimization
rem 
rem     set sources=<list of sources filenames>
rem 
rem     set extra_includes=<list of include directories>
rem     set extra_defines=<list of NAME[=VALUE] defines>
rem     set extra_libs=<list of .lib files to link>
rem     set extra_lib_dirs=<list of .lib directories>
rem     set extra_bin_dirs=<list of .dll or .exe directories>
rem
rem
rem Variables available for use inside vs_conf.bat are:
rem
rem     %root_dir%   : directory containing this script
rem     %build_dir%  : default output directory (build)
rem     %mode%       : [release|debug]
rem     %arch%       : [x86|x86_64]
rem     %hostarch%   : [x86|x86_64]
rem     %command%    : [build|clean|rebuild|run]
rem     %vcarch%     : e.g. x86_amd64
rem     %vcname%     : e.g. vs2022
rem
rem In addition to the system environment and all variables set by
rem vcvarsall.bat (aka Visual Studio Native Tools Command Prompt)
rem
rem
rem Example usage:
rem
rem - Build default target:
rem
rem     vs_build.bat
rem
rem - Cleanup default target:
rem
rem     vs_build.bat clean
rem
rem - Run default target in directory 'test'
rem
rem     vs_build.bat run test
rem
rem - Build debug/x86 target
rem
rem     vs_build.bat build debug x86
rem
rem - Rebuild default target in directory 'test'
rem
rem     vs_build.bat rebuild test
rem
rem - Build default debug target in verbose mode:
rem
rem     vs_build.bat debug verbose
rem


setlocal EnableDelayedExpansion


rem verbose = [on|off]
set verbose=off


set root_dir=%~dp0


for %%a in (%*) do (

         if "%%~a" == "verbose"      ( set verbose=on ) ^
    else if "%%~a" == "release"      ( set "mode=%%~a" ) ^
    else if "%%~a" == "debug"        ( set "mode=%%~a" ) ^
    else if "%%~a" == "x86"          ( set "arch=%%~a" ) ^
    else if "%%~a" == "x86_64"       ( set "arch=%%~a" ) ^
    else if "%%~a" == "build"        ( set "command=%%~a" ) ^
    else if "%%~a" == "clean"        ( set "command=%%~a" ) ^
    else if "%%~a" == "rebuild"      ( set "command=%%~a" ) ^
    else if "%%~a" == "run"          ( set "command=%%~a" ) ^
    else if exist "%%~a\vs_conf.bat" ( set "work_dir=%%~a" )
)

@echo %verbose%


rem ----------------------------------------------------------------------
rem Check 'command'
rem ----------------------------------------------------------------------

if "%command%" == ""        set command=build
if "%command%" == "build"   goto :have_command
if "%command%" == "clean"   goto :have_command
if "%command%" == "rebuild" goto :have_command
if "%command%" == "run"     goto :have_command

echo "Invalid build command: %command%" && exit /b 1

:have_command


rem ----------------------------------------------------------------------
rem Check 'mode'
rem ----------------------------------------------------------------------

if "%mode%" == ""        set mode=release
if "%mode%" == "release" goto :have_mode
if "%mode%" == "debug"   goto :have_mode

echo "Invalid build mode: %mode%" && exit /b 1

:have_mode


rem ----------------------------------------------------------------------
rem Determine 'hostarch'
rem ----------------------------------------------------------------------

rem [AMD64|IA64|ARM64|x86]

if "%PROCESSOR_ARCHITECTURE%" == "x86"   set hostarch=x86
if "%PROCESSOR_ARCHITECTURE%" == "AMD64" set hostarch=x86_64
if "%PROCESSOR_ARCHITEW6432%" == "AMD64" set hostarch=x86_64

if defined hostarch goto :have_hostarch

echo "Could not determine host architecture" && exit /b 1

:have_hostarch


rem ----------------------------------------------------------------------
rem Check 'arch'
rem ----------------------------------------------------------------------

if "%arch%" == ""       set arch=%hostarch%
if "%arch%" == "x86"    goto :have_arch
if "%arch%" == "x86_64" goto :have_arch

echo "Invalid target architecture: %arch%" && exit /b 1

:have_arch


rem ----------------------------------------------------------------------
rem Determine 'vcarch'
rem ----------------------------------------------------------------------

rem https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line?#vcvarsall-syntax

if "%hostarch%" == "x86"    if "%arch%" == "x86"    set vcarch=x86
if "%hostarch%" == "x86"    if "%arch%" == "x86_64" set vcarch=x86_amd64
if "%hostarch%" == "x86_64" if "%arch%" == "x86"    set vcarch=amd64_x86
if "%hostarch%" == "x86_64" if "%arch%" == "x86_64" set vcarch=amd64

if defined vcarch goto :have_vcarch

echo "Could not determine VC build architecture" && exit /b 1

:have_vcarch


rem ----------------------------------------------------------------------
rem Find vswhere.exe
rem ----------------------------------------------------------------------

rem From https://github.com/Microsoft/vswhere/wiki/Installing:
rem 
rem   Starting with Visual Studio 15.2 (26418.1 Preview) vswhere.exe is
rem   installed in
rem  
rem     %ProgramFiles(x86)%\Microsoft Visual Studio\Installer.
rem  
rem   (use %ProgramFiles% in a 32-bit program prior to Windows 10).
rem  
rem   This is a fixed location that will be maintained.

set VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe


rem ----------------------------------------------------------------------
rem Find Visual Studio install directory
rem ----------------------------------------------------------------------

rem This automatically selects the most recent Visual Studio installation,
rem to prevent this, simply set the VCINSTALLDIR environment variable
rem before running this script.


if defined VCINSTALLDIR goto :have_vcinstalldir

for /f "usebackq delims=" %%p in (
    `"%VSWHERE%" -latest -property installationPath`
    ) do set VCINSTALLDIR=%%p

:have_vcinstalldir


rem ----------------------------------------------------------------------
rem Activate Visual Studio build environment
rem ----------------------------------------------------------------------

rem https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line?#vcvarsall-syntax

set VCVARSALL=%VCINSTALLDIR%\vcvarsall.bat
if exist "%VCVARSALL%" goto :have_vcvarsall

set VCVARSALL=%VCINSTALLDIR%\VC\vcvarsall.bat
if exist "%VCVARSALL%" goto :have_vcvarsall

set VCVARSALL=%VCINSTALLDIR%\Auxiliary\Build\vcvarsall.bat
if exist "%VCVARSALL%" goto :have_vcvarsall

set VCVARSALL=%VCINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat
if exist "%VCVARSALL%" goto :have_vcvarsall

echo "vcvarsall.bat not found" && exit /b 1

:have_vcvarsall


call "%VCVARSALL%" %vcarch% > nul

@echo %verbose%


if not "%VisualStudioVersion%" == "" goto :have_vcver

echo "vcvarsall.bat failed" && exit /b 1

:have_vcver


rem ----------------------------------------------------------------------
rem Construct 'vcname' for the current build environment (e.g. vs2022)
rem ----------------------------------------------------------------------

for /f "usebackq delims=" %%p in (
    `"%VSWHERE%" -version %VisualStudioVersion% -property catalog.productLineVersion`
    ) do set vcname=vs%%p


rem ----------------------------------------------------------------------
rem Import (local) project configuration
rem ----------------------------------------------------------------------

pushd "%work_dir%"

if exist vs_conf.local.bat (
    call vs_conf.local.bat
) else (
    call vs_conf.bat
)

popd


rem ----------------------------------------------------------------------
rem Check imported configuration
rem ----------------------------------------------------------------------

if "%build_dir%"  == "" set build_dir=build
if "%target_dir%" == "" set target_dir=%build_dir%\windows\%mode%\%arch%


if not "%target_name%" == "" goto :have_target_name

echo "'target_name' not defined" && exit /b 1

:have_target_name


if "%target_type%" == ""    set target_type=exe
if "%target_type%" == "exe" goto :have_target_type
if "%target_type%" == "lib" goto :have_target_type
if "%target_type%" == "dll" goto :have_target_type

echo "Invalid 'target_type': %target_type%" && exit /b 1

:have_target_type


rem ----------------------------------------------------------------------
rem Setup compiler flags
rem ----------------------------------------------------------------------

rem https://learn.microsoft.com/en-us/cpp/build/reference/compiling-a-c-cpp-program
rem https://learn.microsoft.com/en-us/cpp/build/reference/c-cpp-building-reference


rem /nologo  -> suppress startup banner

set cl_flags=/nologo 

rem /FA -> generate an assembly listing file
rem   c -> include machine code
rem   s -> include source code
rem   u -> utf-8

if "%enable_assembly%" == "1" (
    set cl_flags=%cl_flags% /FAs
)

rem /Zi      -> put debug info in a seperate .pdb file  (implies /debug)
rem /JMC     -> enable just-my-code debugging (step over non-user code)
rem /W3      -> warning level 3 (default), XXX maybe W4 or Wall?
rem /WX-     -> turn off: treat warnings as errors, XXX maybe on?
rem /diagnostics:column -> include column number in messages
rem /FC      -> full path of source file in diagnostics

set cl_flags=%cl_flags% /Zi /JMC /W3 /WX- /diagnostics:column /FC

rem /experimental:external -> enable /external
rem /external:W3  -> warning level 3 for external headers

set cl_flags=%cl_flags% 

if "%mode%" == "release" (

    rem /MD  -> multithreaded runtime DLL (defines _DLL and _MT, links MSVCRT.lib)
    rem /O2  -> Maximize speed (equivalent to /Og /Oi /Ot /Oy /Ob2 /GF /Gy)
    rem /Oi  -> generate intrinsic functions
    rem /GL  -> whole program optimization
    rem /fp:precise -> precise floating point behaviour, XXX maybe fp:fast?

    set cl_flags=%cl_flags% /MD /O2 /Oi /fp:fast

    if "%enable_ltcg%" == "1" (
        set cl_flags=%cl_flags% /GL
    )

    if "%arch%" == "x86" (

        rem /Oy-  -> turn off: omit frame pointer (/Oy implied by /O2)

        set cl_flags=%cl_flags% /Oy-
    )

) else if "%mode%" == "debug" (
    
    rem /MDd  -> multithreaded debug runtime DLL, (defines _DLL, _MT and _DEBUG, links to MSCVRTD.dll)
    rem /RTCu -> runtime error checks: uninitialized variables
    rem /RTCs -> runtime error checks: stack frames
    rem /Od   -> turn off optimizations

    set cl_flags=%cl_flags% /MDd /RTC1 /Od
)

rem /EHsc -> exception handling model: stack unwinding + assume extern "C" never throw
rem /sdl  -> additional security checks (superset of /GS)
rem /GS   -> check buffer overflow (on by default)
rem /Gy   -> enable function level linking
rem /Gd   -> functions are __cdecl, default
rem /Gm-  -> turn off: minimal rebuild (Gm is deprecated)

set cl_flags=%cl_flags% /EHsc /sdl /GS /Gy /Gd /Gm-

rem /TP          -> treat source files as C++
rem /permissive- -> turn on various conformance flags
rem /Zc:wchar_t  -> conformance: wchar_t built-in type instead of typedef
rem /Zc:forScope -> conformance: strict for loop scope
rem /Zc:inline   -> remove unreferenced functions

set cl_flags=%cl_flags% /TP /permissive- /Zc:wchar_t /Zc:forScope /Zc:inline

rem /analyze-  -> turn off: enable code analysis, XXX maybe on?

set cl_flags=%cl_flags% /analyze-


rem /openmp  -> enable support for OpenMP 2.0
rem /openmp:experimental  -> enable OpenMP SIMD support

if "%enable_openmp%" == "1" (
    set cl_flags=%cl_flags% /openmp:experimental
)

rem /I  -> include directory

for %%p in (%extra_includes%) do (
    set cl_flags=!cl_flags! /I "%%~p"
)

rem /D  -> preprocessor definition
rem /U  -> undefine preprocessor definition

set cl_flags=%cl_flags% ^
    /D "_CRT_SECURE_NO_WARNINGS" ^
    /D "_CRT_SECURE_NO_DEPRECATE" ^
    /D "_CRT_NONSTD_NO_DEPRECATE" ^
    /D "_UNICODE" ^
    /D "UNICODE"

if "%arch%" == "x86" (
    set cl_flags=%cl_flags% /D "WIN32"
)

if "%target_type%" == "dll" (
    set cl_flags=%cl_flags% ^
        /D "_WINDOWS" ^
        /D "_USRDLL" ^
        /D "_WINDLL"
)

if "%target_type%" == "exe" (
    set cl_flags=%cl_flags% ^
        /D "_CONSOLE"
)

if "%mode%" == "debug" (
    set cl_flags=%cl_flags% /D "_DEBUG"
) else (
    set cl_flags=%cl_flags% /D "NDEBUG"
)

for %%p in (%extra_defines%) do (
    set cl_flags=!cl_flags! /D "%%~p"
)

rem /Fa  -> assembly listing output directory or filename
rem /Fo  -> object file output directory or filename
rem /Fd  -> .pdb file output directory or filename
rem /Fe  -> .exe or .dll output filename
rem   these need an escaped trailing backslash for directories!

set cl_flags=%cl_flags% ^
    /Fa"%target_dir%\\" ^
    /Fo"%target_dir%\\" ^
    /Fd"%target_dir%\%target_name%.pdb" ^
    /Fe"%target_dir%\%target_name%.%target_type%"


rem ----------------------------------------------------------------------
rem Setup linker flags
rem ----------------------------------------------------------------------

rem /nologo  -> suppress startup banner
rem   set through CL option /nologo

set link_flags=%link_flags% /nologo

rem /out:  -> output target filename 
rem   set through CL option /Fe

set link_flags=%link_flags% ^
    /out:"%target_dir%\%target_name%.%target_type%"

if "%target_type%" == "dll" (

    rem /implib:  -> filename of DLL import library
    rem   default is same as /out: but with .lib extension

    set link_flags=%link_flags% ^
        /implib:"%target_dir%\%target_name%.lib"
)

rem /version  -> version info for the DLL or EXE file

if not "%target_version%" == "" (
    set link_flags=%link_flags% /version:"%target_version%"
)

rem /manifest        -> create a manifest file
rem /manifest:embed  -> embed the manifest in the DLL or EXE

set link_flags=%link_flags% /manifest /manifest:embed

if "%target_type%" == "dll" (

    rem /manifestuac:no  -> don't include user account control info

    set link_flags=%link_flags% /manifestuac:no
)

if "%target_type%" == "exe" (

    rem /manifestuac:     -> include user account control info
    rem   asInvoker       -> run as a regular user
    rem   uiAccess=false  -> don't bypass user interface protection levels

    set link_flags=%link_flags% ^
        /manifestuac:"level='asInvoker' uiAccess='false'"
)

rem /dynamicbase -> random address rebasing at load time (ASLR), default
rem /nxcompat    -> enable data execution prevention

set link_flags=%link_flags% /dynamicbase /nxcompat

rem /debug:full  ->  generate debug info in a .pdb file
rem   set through CL option /Zi

set link_flags=%link_flags% /debug

if "%mode%" == "debug" (

    rem /incremental  -> use incremental linking
    rem /ilk:         -> filename of incremental database file

    if not "%enable_profile%" == "1" (

        set link_flags=%link_flags% ^
            /incremental ^
            /ilk:"%target_dir%\%target_name%.ilk"
    )
)

if "%mode%" == "release" (

    rem /incremental:no  -> turn off incremental linking

    set link_flags=%link_flags% /incremental:no

    rem /opt:ref  -> remove unreferenced functions
    rem /opt:icf  -> fold identical functions (see CL option /Gy)

    set link_flags=%link_flags% /opt:ref /opt:icf

    if "%enable_ltcg%" == "1" (
    
        rem /ltcg     -> enable whole program optimization
        rem /ltcgout: -> filename of intermediate .iobj file

        set link_flags=%link_flags% ^
            /ltcg ^
            /ltcgout:"%target_dir%\%target_name%.iobj"
    )
)

if "%target_type%" == "dll" (

    rem /dll -> build DLL
    rem /subsystem:windows  -> target doesn't require a console/terminal 

    set link_flags=%link_flags% /dll /subsystem:windows
)

if "%target_type%" == "exe" (

    rem /subsystem:windows  -> target doesn't require a console/terminal 
    rem /subsystem:console  -> target requires a console/terminal

    if "%enable_winmain%" == "1" (
        set link_flags=%link_flags% /subsystem:windows
    ) else (
        set link_flags=%link_flags% /subsystem:console
    )
)

if "%arch%" == "x86" (

    rem /machine:  -> set target architecture (ARM|ARM64|ARM64EC|EBC|X64|X86)

    set link_flags=%link_flags% /machine:x86
)

if "%arch%" == "x86_64" (
    
    rem /machine:  -> set target architecture (ARM|ARM64|ARM64EC|EBC|X64|X86)

    set link_flags=%link_flags% /machine:x64
)

if "%enable_profile%" == "1" (
    
    rem /profile  -> produces an output file for profiling

    set link_flags=%link_flags% /profile
)

rem /LIBPATH:  -> add directory to library search path

for %%p in (%extra_lib_dirs%) do (
    set link_flags=!link_flags! /libpath:"%%~p"
)

rem ----------------------------------------------------------------------
rem Setup static library creation flags
rem ----------------------------------------------------------------------

rem /nologo  -> suppress startup banner

set lib_flags=%lib_flags% /nologo

rem /out:  -> output target filename 

set lib_flags=%lib_flags% ^
    /out:"%target_dir%\%target_name%.%target_type%" 

rem ----------------------------------------------------------------------
rem Build the list of object files corresponding to the sources
rem ----------------------------------------------------------------------

set objects=
for %%f in (%sources%) do (
    set objects=!objects! "%target_dir%\%%~nf.obj"
)

rem ----------------------------------------------------------------------
rem Setup runtime path
rem ----------------------------------------------------------------------

set run_path=%target_dir%

for %%p in (%extra_bin_dirs%) do (
    set run_path=!run_path!;%%~p
)

set run_path=%run_path%;%PATH%


rem ----------------------------------------------------------------------
rem Evaluate 'command'
rem ----------------------------------------------------------------------

pushd "%work_dir%"

if "%command%" == "build"   call :build
if "%command%" == "clean"   call :clean
if "%command%" == "rebuild" call :rebuild
if "%command%" == "run"     call :run

popd

rem This is the end of the script, the rest is subroutines

exit /b 0


rem ----------------------------------------------------------------------
rem Subroutine 'build' - Builds the target
rem ----------------------------------------------------------------------

:build

echo --- Building %target_dir%\%target_name%.%target_type% ---

if not exist %target_dir% mkdir "%target_dir%"

if "%target_type%" == "exe" call :build_exe
if "%target_type%" == "lib" call :build_lib
if "%target_type%" == "dll" call :build_dll

echo --- Finished ---

call :dist

exit /b 0

rem ----------------------------------------------------------------------
rem Subroutine 'dist' - Copies the target to the dist directory
rem ----------------------------------------------------------------------

:dist

if "%dist_dir%" == "" exit /b 0
if not exist "%target_dir%\%target_name%.%target_type%" exit /b 0

echo --- Copying to %dist_dir%\%target_name%.%target_type% ---

if not exist "%dist_dir%" mkdir "%dist_dir%"

copy "%target_dir%\%target_name%.%target_type%" "%dist_dir%"

echo --- Finished ---

exit /b 0

rem ----------------------------------------------------------------------
rem Subroutine 'clean' - Deletes files generated by 'build'
rem ----------------------------------------------------------------------

:clean

rem Remove all .asm files in the target directory
for %%f in ("%target_dir%\*.asm") do del "%%f"

rem Remove all .obj files in the target directory
for %%f in ("%target_dir%\*.obj") do del "%%f"

rem Remove build target artefacts with the specified extensions
for %%e in (exe lib dll exp pdb iobj ilk) do (
    if exist "%target_dir%\%target_name%.%%e" (
        del "%target_dir%\%target_name%.%%e"
    )
)

rem Recursively delete empty directories starting from
rem the build_dir.  This assumes that the target_dir is
rem a subdirectory of build_dir.

if exist "%build_dir%\" (
    for /f "usebackq delims=" %%d in (
        `dir /s /b /ad "%build_dir%" ^| sort /r`
        ) do rd "%%d" 2> nul

    rd "%build_dir%" 2> nul
)

rem Remove the target artefact in the dist directory
del "%dist_dir%\%target_name%.%target_type%" 2> nul

rem Remove the dist dist directory if it is empty
rd "%dist_dir%" 2> nul

exit /b 0


rem ----------------------------------------------------------------------
rem Subroutine 'rebuild' - Cleans and then builds the target
rem ----------------------------------------------------------------------

:rebuild
call :clean
call :build
exit /b 0


rem ----------------------------------------------------------------------
rem Subroutine 'build_exe' - Build an executable
rem ----------------------------------------------------------------------

:build_exe
cl %cl_flags% %sources% /link %link_flags% %extra_libs%
exit /b 0


rem ----------------------------------------------------------------------
rem Subroutine 'build_lib' - Build a static library
rem ----------------------------------------------------------------------

:build_lib
for %%f in (%sources%) do cl /c %cl_flags% %%f
lib %lib_flags% %objects%
exit /b 0


rem ----------------------------------------------------------------------
rem Subroutine 'build_dll' - Build a dynamic link library
rem ----------------------------------------------------------------------

:build_dll
cl %cl_flags% %sources% /link %link_flags% %extra_libs%
exit /b 0


rem ----------------------------------------------------------------------
rem Subroutine 'run' - Run the target executable
rem ----------------------------------------------------------------------

:run

call :build

echo --- Running %target_dir%\%target_name%.%target_type% ---

if not "%target_type%" == "exe" echo "Not an executable" && exit /b 1

set old_path=%PATH%
set PATH=%run_path%

"%target_dir%\%target_name%.exe" %run_args%

set exit_val=%errorlevel%
set PATH=%old_path%

echo --- Finished with exit value %exit_val% ---

exit /b 0

