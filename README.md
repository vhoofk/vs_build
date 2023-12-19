# Usage


Build using Visual Studio development environment:

    vs_build.bat [option]...

Where the available options are:

 - verbose                   : turn on verbose mode (default off)
 - [release|debug]           : target build mode    (default release)
 - [x86|x86_64]              : target architecture  (default hostarch)
 - [build|clean|rebuild|run] : command to evaluate  (default build)
 - [DIR]                     : a directory containing the vs_conf.bat build config  (default current)


The actual build configuration is loaded from a file called vs_conf.bat
in the specified DIR (by default the current directory).

If the file vs_conf.local.bat exists, it will be loaded instead of
vs_conf.bat.  So to make changes that should not be put under version
control, simply copy vs_conf.bat to vs_conf.local.bat and make 
changes there.

The configuration variables that can be set in vs_conf.bat are:

    set build_dir=<dir>        : base directory for build output

    set target_name=<basename>
    set target_type=[exe|dll|lib]
    set target_version=<major.minor>

    set run_args=<command line args for running the target>

    set enable_assembly=[0|1]  : output assembly code
    set enable_openmp=[0|1]    : enable OpenMP 2.0
    set enable_winmain=[0|1]   : use WinMain() instead of main()
    set enable_profile=[0|1]   : add /profile compiler flag
    set enable_ltcg=[0|1]      : enable whole program optimization

    set sources=<list of sources filenames>

    set extra_includes=<list of include directories>
    set extra_defines=<list of NAME[=VALUE] defines>
    set extra_libs=<list of .lib files to link>
    set extra_lib_dirs=<list of .lib directories>
    set extra_bin_dirs=<list of .dll or .exe directories>


Variables available for use inside vs_conf.bat are:

    %root_dir%   : directory containing this script
    %build_dir%  : default output directory (build)
    %mode%       : [release|debug]
    %arch%       : [x86|x86_64]
    %hostarch%   : [x86|x86_64]
    %command%    : [build|clean|rebuild|run]
    %vcarch%     : e.g. x86_amd64
    %vcname%     : e.g. vs2022

In addition to the system environment and all variables set by
vcvarsall.bat (aka Visual Studio Native Tools Command Prompt)


Example usage:

- Build default target:

    vs_build.bat

- Cleanup default target:

    vs_build.bat clean

- Run default target in directory 'test'

    vs_build.bat run test

- Build debug/x86 target

    vs_build.bat build debug x86

- Rebuild default target in directory 'test'

    vs_build.bat rebuild test

- Build default debug target in verbose mode:

    vs_build.bat debug verbose



