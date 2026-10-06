cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)
apply_standard_settings(${BINARY_NAME})
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
add_dependencies(${BINARY_NAME} flutter_assemble)

# ============================================================
# Tự động copy Visual C++ Runtime DLLs vào output folder
# ============================================================
# Đặt trong runner/CMakeLists.txt vì target ${BINARY_NAME} được tạo ở đây.
# add_custom_command(TARGET) chỉ work khi ở cùng directory với target.
# VERBATIM bắt buộc để escape path có dấu cách (Program Files (x86)).
if(WIN32 AND MSVC)
  # Tìm thư mục VCRedist — ưu tiên env var, fallback hardcoded VS path
  set(VCREDIST_DIRS "")

  if(DEFINED ENV{VCINSTALLDIR})
    file(GLOB VCREDIST_DIRS "$ENV{VCINSTALLDIR}/Redist/MSVC/*/x64/Microsoft.VC*.CRT")
  endif()

  if(NOT VCREDIST_DIRS AND DEFINED ENV{VCToolsInstallDir})
    get_filename_component(VC_ROOT "$ENV{VCToolsInstallDir}/../.." ABSOLUTE)
    file(GLOB VCREDIST_DIRS "${VC_ROOT}/Redist/MSVC/*/x64/Microsoft.VC*.CRT")
  endif()

  if(NOT VCREDIST_DIRS)
    file(GLOB VCREDIST_DIRS
      "C:/Program Files (x86)/Microsoft Visual Studio/18/BuildTools/VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT"
      "C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT"
      "C:/Program Files (x86)/Microsoft Visual Studio/2022/Community/VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT"
      "C:/Program Files (x86)/Microsoft Visual Studio/2022/Professional/VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT"
      "C:/Program Files (x86)/Microsoft Visual Studio/2022/Enterprise/VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT"
    )
  endif()

  if(VCREDIST_DIRS)
    list(GET VCREDIST_DIRS 0 VCREDIST_DIR)
    message(STATUS "Found VCRedist: ${VCREDIST_DIR}")

    # Chỉ append những DLL thực sự tồn tại
    set(VC_RUNTIME_DLLS "")
    foreach(DLL_NAME
        msvcp140.dll
        vcruntime140.dll
        vcruntime140_1.dll
        msvcp140_1.dll
        msvcp140_2.dll
        concrt140.dll)
      if(EXISTS "${VCREDIST_DIR}/${DLL_NAME}")
        list(APPEND VC_RUNTIME_DLLS "${VCREDIST_DIR}/${DLL_NAME}")
      endif()
    endforeach()

    list(LENGTH VC_RUNTIME_DLLS NUM_DLLS)
    message(STATUS "Will copy ${NUM_DLLS} VC++ Runtime DLLs")

    add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy_if_different
              ${VC_RUNTIME_DLLS}
              "$<TARGET_FILE_DIR:${BINARY_NAME}>"
      COMMENT "📦 Copying VC++ Runtime DLLs to output folder"
      VERBATIM
    )
  else()
    message(WARNING "⚠️ Không tìm thấy VCRedist folder — bỏ qua copy runtime DLLs")
  endif()
endif()
# Copy tray icon ra cạnh exe
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
          "${CMAKE_CURRENT_SOURCE_DIR}/resources/app_icon.ico"
          "$<TARGET_FILE_DIR:${BINARY_NAME}>/app_icon.ico"
  COMMENT "📦 Copying tray icon to output folder"
  VERBATIM
)
# ============================================================
# Copy Go helper exe vào output folder
# ============================================================
if(WIN32 AND EXISTS "${CMAKE_SOURCE_DIR}/../windows_helper/vie_lich_helper.exe")
  add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_SOURCE_DIR}/../windows_helper/vie_lich_helper.exe"
            "$<TARGET_FILE_DIR:${BINARY_NAME}>/vie_lich_helper.exe"
    COMMENT "📦 Copying Go helper to output folder"
    VERBATIM
  )
endif()