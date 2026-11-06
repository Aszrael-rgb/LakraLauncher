import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WindowsStartupService {
  static const _runKey = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'LakraLauncher';

  void setEnabled(bool enabled) {
    if (!Platform.isWindows) return;

    final registryPath = _runKey.toNativeUtf16(allocator: calloc);
    final valueName = _valueName.toNativeUtf16(allocator: calloc);
    final registryHandle = calloc<Pointer<Void>>();
    Pointer<Utf16>? executable;
    var registryKeyOpened = false;
    late HKEY registryKey;

    try {
      final createResult = RegCreateKeyEx(
        HKEY_CURRENT_USER,
        PCWSTR(registryPath),
        null,
        REG_OPTION_NON_VOLATILE,
        KEY_SET_VALUE,
        null,
        registryHandle.cast<Pointer>(),
        null,
      );
      if (createResult.isError) {
        throw WindowsException(createResult.toHRESULT());
      }

      registryKey = HKEY(registryHandle.value);
      registryKeyOpened = true;
      if (enabled) {
        executable = '"${Platform.resolvedExecutable}"'.toNativeUtf16(
          allocator: calloc,
        );
        final result = RegSetValueEx(
          registryKey,
          PCWSTR(valueName),
          REG_SZ,
          executable.cast<Uint8>(),
          (executable.length + 1) * sizeOf<Uint16>(),
        );
        if (result.isError) throw WindowsException(result.toHRESULT());
      } else {
        final result = RegDeleteValue(registryKey, PCWSTR(valueName));
        if (result.isError && result.code != ERROR_FILE_NOT_FOUND) {
          throw WindowsException(result.toHRESULT());
        }
      }
    } finally {
      if (registryKeyOpened) RegCloseKey(registryKey);
      if (executable != null) calloc.free(executable);
      calloc.free(registryHandle);
      calloc.free(valueName);
      calloc.free(registryPath);
    }
  }
}
