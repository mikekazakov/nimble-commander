# Helper Scripts
The `Scripts` directory contains a set of useful scripts to be used during development, continuous integration, testing and packaging.

## `build_for_codeql.sh`
Builds tests and the main application without running so that CodeQL can intercept the commands and perform its analysis afterwards.  
`xcodebuild` and `xcpretty` must be available in the environment in order for this script to run.  

## `build_help.sh`
Converts the markdown documention into a pdf placed in `build_help.tmp/Help.pdf`

## `build_mas_archive.sh`
Builds and archive Nimble Commander for submission to MacAppStore.

## `build_nightly.sh`
Builds Nimble Commander with the `NimbleCommander-NonMAS` scheme / `Release` configuration, signs it, packages the runnable build into a `.dmg` image and notarizes the final image.  
`xcodebuild`, `xcpretty` and `create-dmg` must be available in the environment in order for this script to run.  
It also requires the codesigning certificate to be properly signed.  

## `build_release.sh`  
Same a `build_nightly.sh`, but creates a release build. 

## `build_unsigned.sh`
Builds Nimble Commander with the `NimbleCommander-Unsigned` scheme / `Release` configuration and packages the runnable build into a `.dmg` image.  
`xcodebuild`, `xcpretty` and `create-dmg` must be available in the environment in order for this script to run.  

## `build_unsigned_and_run.sh`
Builds Nimble Commander with the `NimbleCommander-Unsigned` scheme / `Debug` configuration and runs it afterwards.  
`xcodebuild` must be available in the environment in order for this script to run.

## `run_all_integration_tests.sh`
Builds and executes all integration tests with the Debug/ASAN configuration.  
`xcodebuild` and `xcpretty` must be available in the environment in order for this script to run.  
`docker` must be available to run the VMs required for NC's virtual file systems.  

## `run_all_unit_tests.sh [Debug|Release|ASAN|UBSAN]`
Builds and executes all unit tests with the specified configuration.  
`xcodebuild` and `xcpretty` must be available in the environment in order for this script to run.  

## `run_clang_format.sh`
Executes `clang-format` against all source files in the `Source` directory, re-formatting them in-place if necessary.  
Rules from `Source/.clang-format` are used in the process.  
`clang-format` must be available in order for this script to run.

## `run_clang_tidy.sh`
Executes `clang-tidy` against all source files in the `Source` directory, updating them in-place if necessary.  
`xcodebuild`, `xcpretty` and `jq` must be available in the environment in order for this script to run.  
`clang-tidy` must be installed via Brew and is expected to be located at `/opt/homebrew/opt/llvm/bin/`.  
Rules from `Source/.clang-tidy` are used in the process.  
It's recommended to execute `run_clang_format.sh` afterwards.

## Dependencies installation:
  * xcodebuild:
    * XCode: https://download.developer.apple.com/Developer_Tools/Xcode_16/Xcode_16.xip             
    * Or just build tools: https://download.developer.apple.com/Developer_Tools/Command_Line_Tools_for_Xcode_16/Command_Line_Tools_for_Xcode_16.dmg
  * [xcpretty](https://github.com/xcpretty/xcpretty): `gem install xcpretty`
  * [clang-format](https://clang.llvm.org/docs/ClangFormat.html): `brew install clang-format`
  * [clang-tidy](https://clang.llvm.org/extra/clang-tidy/): `brew install llvm`
  * [jq](https://jqlang.github.io/jq/): `brew install jq`
  * [create-dmg](https://github.com/create-dmg/create-dmg): `brew install create-dmg`
