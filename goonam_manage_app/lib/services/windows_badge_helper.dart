// import 'dart:ffi';
// import 'dart:io';
// import 'package:ffi/ffi.dart';
// import 'package:win32/win32.dart';
//
// // -------------------- BỔ SUNG CÁC HẰNG SỐ & HÀM GDI --------------------
//
// const int FW_BOLD = 700;
// const int OUT_DEFAULT_PRECIS = 0;
// const int CLIP_DEFAULT_PRECIS = 0;
// const int DEFAULT_QUALITY = 0;
// const int DEFAULT_PITCH = 0;
// const int FF_SWISS = 2;
// const int BLACKNESS = 0x00000042;
//
// // PatBlt
// final _PatBlt = DynamicLibrary.open('gdi32.dll').lookupFunction<
//     Int32 Function(IntPtr, Int32, Int32, Int32, Int32, Uint32),
//     int Function(int, int, int, int, int, int)>('PatBlt');
// int PatBlt(int hdc, int x, int y, int w, int h, int rop) =>
//     _PatBlt(hdc, x, y, w, h, rop);
//
// // CreateFontW
// final _CreateFontW = DynamicLibrary.open('gdi32.dll').lookupFunction<
//     IntPtr Function(
//         Int32, Int32, Int32, Int32, Int32,
//         Uint32, Uint32, Uint32, Uint32, Uint32,
//         Uint32, Uint32, Uint32, Pointer<Utf16>),
//     int Function(
//         int, int, int, int, int,
//         int, int, int, int, int,
//         int, int, int, Pointer<Utf16>)>('CreateFontW');
//
// int CreateFontW(
//     int nHeight,
//     int nWidth,
//     int nEscapement,
//     int nOrientation,
//     int fnWeight,
//     int fdwItalic,
//     int fdwUnderline,
//     int fdwStrikeOut,
//     int fdwCharSet,
//     int fdwOutputPrecision,
//     int fdwClipPrecision,
//     int fdwQuality,
//     int fdwPitchAndFamily,
//     Pointer<Utf16> lpszFace,
//     ) {
//   return _CreateFontW(
//     nHeight,
//     nWidth,
//     nEscapement,
//     nOrientation,
//     fnWeight,
//     fdwItalic,
//     fdwUnderline,
//     fdwStrikeOut,
//     fdwCharSet,
//     fdwOutputPrecision,
//     fdwClipPrecision,
//     fdwQuality,
//     fdwPitchAndFamily,
//     lpszFace,
//   );
// }
//
// class WindowsBadgeHelper {
//   static bool _comInitialized = false;
//   static _ITaskbarList3? _taskbar;          // giữ lại 1 instance duy nhất
//   static int _lastCount = -1;               // để biết có cần cập nhật lại không
//
//   /// Khởi tạo COM + taskbar một lần
//   static void init() {
//     if (!Platform.isWindows) return;
//     if (_comInitialized) return;
//
//     final hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
//     if (FAILED(hr)) {
//       print('⚠️ CoInitializeEx failed: 0x${hr.toRadixString(16)}');
//       return;
//     }
//
//     _comInitialized = true;
//     _taskbar ??= _createTaskbar();
//
//     print('✅ COM initialized for taskbar badge');
//   }
//
//   /// Hiển thị / xóa badge
//   static void updateBadge(int count) {
//     print('🟢 updateBadge($count) được gọi');
//     if (!Platform.isWindows) return;
//
//     if (!_comInitialized) {
//       init();
//     }
//
//     // nếu sau init vẫn không có taskbar thì thôi
//     if (_taskbar == null) {
//       print('⚠️ ITaskbarList3 not available.');
//       return;
//     }
//
//     // nếu số badge không đổi thì khỏi gọi lại → tránh spam COM
//     if (count == _lastCount) {
//       return;
//     }
//
//     final hwnd = FindWindow(nullptr, TEXT("goonam_manage_app"));
//     print('🔍 hwnd=$hwnd');
//     if (hwnd == 0) {
//       print('⚠️ Không tìm thấy cửa sổ ứng dụng.');
//       return;
//     }
//
//     if (count <= 0) {
//       _taskbar!.SetOverlayIcon(hwnd, 0, TEXT(''));
//       _lastCount = 0;
//       print('🧹 Đã xóa badge khỏi taskbar');
//       return;
//     }
//
//     final display = count > 99 ? '99+' : '$count';
//     final hIcon = _createNumberIcon(display);
//     if (hIcon != 0) {
//       _taskbar!.SetOverlayIcon(hwnd, hIcon, TEXT('Unread: $display'));
//       _lastCount = count;
//       print('✅ Hiển thị badge taskbar: $display');
//     }
//   }
//
//   static void dispose() {
//     if (_taskbar != null) {
//       _taskbar!.release();   // giải phóng COM object
//       _taskbar = null;
//     }
//
//     if (_comInitialized) {
//       CoUninitialize();
//       _comInitialized = false;
//       print('🔻 COM uninitialized safely');
//     }
//   }
//
//   // ----- PRIVATE HELPERS -----
//
//   static _ITaskbarList3? _createTaskbar() {
//     final clsid = calloc<GUID>();
//     final iid = calloc<GUID>();
//
//     IIDFromString(TEXT('{56FDF344-FD6D-11d0-958A-006097C9A090}'), clsid);
//     IIDFromString(TEXT('{EA1AFB91-9E28-4B86-90E9-9E9F8A5EEFAF}'), iid);
//
//     final ptr = calloc<COMObject>();
//     final hr = CoCreateInstance(clsid, nullptr, CLSCTX.CLSCTX_ALL, iid, ptr.cast());
//
//     calloc.free(clsid);
//     calloc.free(iid);
//
//     if (FAILED(hr)) {
//       calloc.free(ptr);
//       print('❌ CoCreateInstance thất bại: 0x${hr.toRadixString(16)}');
//       return null;
//     }
//
//     final taskbar = _ITaskbarList3(ptr);
//
//     // 🔥 GỌI HrInit() trước khi dùng bất kỳ hàm nào khác
//     final hrInit = taskbar.HrInit();
//     if (FAILED(hrInit)) {
//       print('❌ HrInit thất bại: 0x${hrInit.toRadixString(16)}');
//       taskbar.release();
//       return null;
//     }
//
//     print('✅ ITaskbarList3 initialized successfully');
//     return taskbar;
//   }
//
//
//   static int _createNumberIcon(String number) {
//     const int size = 32;
//
//     final hdcScreen = GetDC(NULL);
//     final hdc = CreateCompatibleDC(hdcScreen);
//     final bmp = CreateCompatibleBitmap(hdcScreen, size, size);
//     ReleaseDC(NULL, hdcScreen);
//     SelectObject(hdc, bmp);
//
//     // nền
//     PatBlt(hdc, 0, 0, size, size, BLACKNESS);
//
//     // vòng tròn đỏ
//     final redBrush = CreateSolidBrush(RGB(220, 0, 0));
//     SelectObject(hdc, redBrush);
//     Ellipse(hdc, 0, 0, size, size);
//
//     // chữ trắng
//     final hFont = CreateFontW(
//       -18, 0, 0, 0,
//       FW_BOLD, 0, 0, 0,
//       ANSI_CHARSET, OUT_DEFAULT_PRECIS,
//       CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY,
//       DEFAULT_PITCH | FF_SWISS,
//       TEXT('Segoe UI'),
//     );
//     SelectObject(hdc, hFont);
//     SetBkMode(hdc, TRANSPARENT);
//     SetTextColor(hdc, RGB(255, 255, 255));
//
//     final rect = calloc<RECT>()
//       ..ref.left = 0
//       ..ref.top = 0
//       ..ref.right = size
//       ..ref.bottom = size;
//
//     final txt = TEXT(number);
//     DrawText(hdc, txt, -1, rect, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
//
//     final iconInfo = calloc<ICONINFO>()
//       ..ref.fIcon = TRUE
//       ..ref.hbmMask = bmp
//       ..ref.hbmColor = bmp;
//
//     final hIcon = CreateIconIndirect(iconInfo);
//
//     // dọn cái mình chủ động tạo
//     DeleteObject(redBrush);
//     DeleteObject(hFont);
//     calloc.free(rect);
//     calloc.free(iconInfo);
//
//     // KHÔNG DeleteObject(bmp) và KHÔNG DeleteDC(hdc) ở đây
//
//     return hIcon;
//   }
// }
//
// class _ITaskbarList3 extends IUnknown {
//   _ITaskbarList3(Pointer<COMObject> ptr) : super(ptr);
//
//   int HrInit() {
//     final vtbl = ptr.ref.lpVtbl.cast<Pointer<Pointer<Void>>>().value;
//     final pHrInit = vtbl
//         .elementAt(3) // phương thức thứ 3 trong vtable
//         .cast<Pointer<NativeFunction<Int32 Function(Pointer<Void>)>>>()
//         .value
//         .asFunction<int Function(Pointer<Void>)>();
//     return pHrInit(ptr.cast());
//   }
//
//   int SetOverlayIcon(int hwnd, int hIcon, Pointer<Utf16> desc) {
//     final vtbl = ptr.ref.lpVtbl.cast<Pointer<Pointer<Void>>>().value;
//     final pSetOverlayIcon = vtbl
//         .elementAt(18)
//         .cast<
//         Pointer<
//             NativeFunction<
//                 Int32 Function(
//                     Pointer<Void>, IntPtr, IntPtr, Pointer<Utf16>)>>>()
//         .value
//         .asFunction<
//         int Function(Pointer<Void>, int, int, Pointer<Utf16>)>();
//     return pSetOverlayIcon(ptr.cast(), hwnd, hIcon, desc);
//   }
// }
