#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
    _In_ wchar_t* command_line, _In_ int show_command) {

    // Attach to console when present (e.g., 'flutter run') or create a
    // new console when running with a debugger.
    if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
        CreateAndAttachConsole();
    }

    // Initialize COM, so that it is available for use in the library and/or
    // plugins.
    ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    flutter::DartProject project(L"data");

    std::vector<std::string> command_line_arguments =
        GetCommandLineArguments();

    project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

    FlutterWindow window(project);
    Win32Window::Point origin(10, 10);
    Win32Window::Size size(1280, 720);
    
    // PERBAIKAN: Gunakan title yang sesuai dan biarkan window_manager mengelola window
    if (!window.Create(L"", origin, size)) {
        return EXIT_FAILURE;
    }

    // HAPUS SEMUA KODE YANG MEMODIFIKASI WINDOW STYLE
    // Biarkan window_manager dari main.dart yang mengatur semuanya

    window.SetQuitOnClose(true);

    // Run the message loop. It will run until the window is closed.
    ::MSG msg;
    while (::GetMessage(&msg, nullptr, 0, 0)) {
        ::TranslateMessage(&msg);
        ::DispatchMessage(&msg);
    }

    ::CoUninitialize();
    return EXIT_SUCCESS;
}