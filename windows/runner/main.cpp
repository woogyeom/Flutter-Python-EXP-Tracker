#define _CRT_SECURE_NO_WARNINGS
#pragma warning(disable : 4819)

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <dbghelp.h>
#pragma comment(lib, "Dbghelp.lib")

#include "flutter_window.h"
#include "utils.h"

static void WriteStackTrace(EXCEPTION_POINTERS *ep)
{
  HANDLE process = GetCurrentProcess();
  SymInitialize(process, NULL, TRUE);

  void *stack[62];
  USHORT frames = CaptureStackBackTrace(0, _countof(stack), stack, NULL);

  SYMBOL_INFO *symbol = (SYMBOL_INFO *)calloc(sizeof(SYMBOL_INFO) + 256, 1);
  symbol->MaxNameLen = 255;
  symbol->SizeOfStruct = sizeof(SYMBOL_INFO);

  FILE *f = nullptr;
  if (_wfopen_s(&f, L"crash.log", L"w, ccs=UTF-8") != 0 || f == nullptr)
  {
    fwprintf(stderr, L"Failed to open crash.log for writing.\n");
    return;
  }
  fwprintf(f, L"ExceptionCode: 0x%08X\n", ep->ExceptionRecord->ExceptionCode);
  for (USHORT i = 0; i < frames; ++i)
  {
    DWORD64 addr = (DWORD64)(stack[i]);
    if (SymFromAddr(process, addr, 0, symbol))
    {
      fwprintf(f, L"%02d: %S [0x%0llX]\n", frames - i - 1, symbol->Name, symbol->Address);
    }
    else
    {
      fwprintf(f, L"%02d: [0x%0llX]\n", frames - i - 1, addr);
    }
  }
  fclose(f);
  free(symbol);
  SymCleanup(process);
}

static LONG WINAPI MyExceptionFilter(EXCEPTION_POINTERS *ep)
{
  WriteStackTrace(ep);
  return EXCEPTION_EXECUTE_HANDLER;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance,
                      _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line,
                      _In_ int show_command)
{
  SetUnhandledExceptionFilter(MyExceptionFilter);

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent())
  {
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
  if (!window.Create(L"flutter_exp_timer", origin, size))
  {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0))
  {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
