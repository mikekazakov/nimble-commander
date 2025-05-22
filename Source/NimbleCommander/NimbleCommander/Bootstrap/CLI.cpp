// Copyright (C) 2021-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CLI.h"
#include <vector>
#include <string_view>
#include <iostream>
#include <cstdlib>
#include <unistd.h>
#include <sys/types.h>
#include <spawn.h>
#include <fcntl.h>
#include <CoreFoundation/CoreFoundation.h>
#include <mach-o/dyld.h> // For _NSGetExecutablePath
#include <RoutedIO/RoutedIO.h>

// Declaration for environ which is defined in unistd.h on many systems but not on macOS
extern char **environ;

namespace nc::bootstrap {

static const auto g_Message = "Command-line options:                                                          \n"
                              "-NCLogLevel <level>   Sets a logging level for all subsystems.                 \n"
                              "                      Levels are: off, trace, debug, info, warn, err, critical.\n"
                              "                                                                               \n"
                              "Command-line commands:                                                         \n"
                              "--help                          Prints this message.                           \n"
                              "--install-privileged-helper     Installs the Admin Mode helper.                \n"
                              "--uninstall-privileged-helper   Stops and uninstalls the Admin Mode helper.    \n"
                              "--new-window                   Opens a new window in the current instance.    \n";

static bool g_ShouldOpenNewWindow = false;

void ProcessCLIUsage(int argc, char *argv[])
{
    const std::vector<std::string_view> args(argv, argv + argc);
    bool isTerminalLaunch = isatty(STDIN_FILENO);
    
    for( auto arg : args ) {
        if( arg == "--help" ) {
            std::cout << g_Message << std::flush;
            std::exit(0);
        }
        if( arg == "--install-privileged-helper" ) {
            nc::routedio::RoutedIO::InstallViaRootCLI();
            std::exit(0);
        }
        if( arg == "--uninstall-privileged-helper" ) {
            nc::routedio::RoutedIO::UninstallViaRootCLI();
            std::exit(0);
        }
        if( arg == "--new-window" ) {
            g_ShouldOpenNewWindow = true;
            // If launched from terminal, detach the process so it doesn't block the terminal
            if (isTerminalLaunch) {
                // Get the current executable path
                char exePath[PATH_MAX];
                uint32_t size = sizeof(exePath);
                if (_NSGetExecutablePath(exePath, &size) == 0) {
                    int devnull = -1;
                    posix_spawn_file_actions_t fileActions;
                    posix_spawnattr_t attr;
                    bool init_success = false;
                    
                    // Initialize file actions
                    if (posix_spawn_file_actions_init(&fileActions) == 0) {
                        // Open /dev/null before setting up redirections
                        devnull = open("/dev/null", O_RDWR);
                        if (devnull >= 0) {
                            // Set up redirections in the correct order
                            // First redirect to /dev/null
                            if (posix_spawn_file_actions_adddup2(&fileActions, devnull, STDIN_FILENO) == 0 &&
                                posix_spawn_file_actions_adddup2(&fileActions, devnull, STDOUT_FILENO) == 0 &&
                                posix_spawn_file_actions_adddup2(&fileActions, devnull, STDERR_FILENO) == 0) {
                                
                                // Close the original devnull fd in the child after redirection
                                if (posix_spawn_file_actions_addclose(&fileActions, devnull) == 0) {
                                    // Set up spawn attributes for new session
                                    if (posix_spawnattr_init(&attr) == 0) {
                                        // Create a new session and process group
                                        short flags = POSIX_SPAWN_SETSID;
                                        if (posix_spawnattr_setflags(&attr, flags) == 0) {
                                            init_success = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    if (init_success) {
                        // Prepare arguments for the new process
                        std::vector<char*> newArgv(argc + 1);
                        for (int i = 0; i < argc; ++i) {
                            newArgv[i] = argv[i];
                        }
                        newArgv[argc] = nullptr;
                        
                        // Spawn the detached process
                        pid_t childPid;
                        int spawn_result = posix_spawn(&childPid, exePath, &fileActions, &attr, newArgv.data(), environ);
                        
                        if (spawn_result == 0) {
                            // Success - parent exits immediately
                            if (devnull >= 0) {
                                close(devnull); // Close devnull in the parent
                            }
                            
                            // Clean up in parent before exit
                            posix_spawnattr_destroy(&attr);
                            posix_spawn_file_actions_destroy(&fileActions);
                            
                            _exit(0); // Exit without running destructors or atexit handlers
                        } else {
                            std::cerr << "Failed to spawn detached process: " << strerror(spawn_result) << std::endl;
                        }
                    } else {
                        std::cerr << "Failed to initialize process detachment" << std::endl;
                    }
                    
                    // Clean up if we didn't exit or if initialization failed
                    if (devnull >= 0) {
                        close(devnull);
                    }
                    
                    if (init_success) {
                        posix_spawnattr_destroy(&attr);
                        posix_spawn_file_actions_destroy(&fileActions);
                    }
                }
            }
        }
    }
}
bool ShouldOpenNewWindowFromCLI() {
    return g_ShouldOpenNewWindow;
}

} // namespace nc::bootstrap
