cmake_minimum_required(VERSION 3.16)

project(cursor_music VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 6.8 REQUIRED COMPONENTS
    Quick
    QuickControls2
    Network
    Multimedia
    Svg
)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appcursor_music
    src/main.cpp
    src/app/ApplicationContext.cpp
    src/network/HttpClient.cpp
    src/storage/AppSettings.cpp
    src/storage/PersistentCookieJar.cpp
    # ==== 阶段二新增源文件 ====
    src/bilibili/BilibiliApiClient.cpp
    src/auth/AuthService.cpp
    src/bilibili/FavoriteService.cpp
    src/player/MediaResolver.cpp
    src/player/PlayerController.cpp
    src/player/PlaylistService.cpp
    src/bilibili/MusicService.cpp
)

qt_add_qml_module(appcursor_music
    URI cursor_music
    QML_FILES
        qml/Main.qml
        qml/components/AppShell.qml
        qml/components/NavigationRail.qml
        qml/components/Theme.js
        qml/components/AppIcon.qml
        qml/components/IconButton.qml
        qml/components/PageHeader.qml
        qml/components/FolderCard.qml
        qml/components/MediaList.qml
        qml/components/MediaListItem.qml
        qml/components/EmptyState.qml
        qml/components/ErrorState.qml
        qml/components/SkeletonList.qml
        qml/components/AppButton.qml
        qml/components/CoverImage.qml
        qml/components/ResponsivePlayerBar.qml
        qml/components/QueueDrawer.qml
        qml/pages/HomePage.qml
        qml/pages/FavoritesPage.qml
        qml/pages/LoginPage.qml
    RESOURCES
        icon/home.svg
        icon/search.svg
        icon/settings.svg
        icon/chevron-left.svg
        icon/chevron-right.svg
        icon/close.svg
        icon/eye.svg
        icon/eye-off.svg
        icon/info.svg
        icon/folder-heart.svg
        icon/play.svg
        icon/pause.svg
        icon/skip-back.svg
        icon/skip-forward.svg
        icon/volume-2.svg
        icon/list-music.svg
        icon/repeat-2.svg
        icon/shuffle.svg
        icon/refresh-cw.svg
        icon/log-in.svg
        icon/log-out.svg
        icon/music-2.svg
        icon/alert-circle.svg
        icon/LICENSE-lucide.txt
)

target_include_directories(appcursor_music
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

set_target_properties(appcursor_music PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appcursor_music
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Network
        Qt6::Multimedia
        Qt6::Svg
)

# 诊断仅在显式开启时编入 Android APK，普通构建不会自动向诊断站点发请求。
option(BL_ANDROID_TLS_DIAGNOSTICS "Enable the one-shot Android HTTPS probe" OFF)
option(BL_ANDROID_LIFECYCLE_DIAGNOSTICS "Observe Android application and player lifecycle" OFF)
if(ANDROID)
    # androiddeployqt 将此目录中的 Manifest 合入 APK；仅定制 Qt 后台事件循环策略。
    set_property(TARGET appcursor_music PROPERTY QT_ANDROID_PACKAGE_SOURCE_DIR
        "${CMAKE_CURRENT_SOURCE_DIR}/android"
    )
    # TLS backend 是 Qt 的加密后端插件；Qt6::Network 不会自动提供其 OpenSSL 运行库。
    # 此目录由 scripts/build-android-openssl.sh 生成，只包含本次验证的 ARM64 库。
    set(BL_ANDROID_OPENSSL_DIR "" CACHE PATH "Directory containing Android ARM64 OpenSSL 3 libraries")
    if(NOT CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
        message(FATAL_ERROR "This OpenSSL deployment currently supports arm64-v8a only.")
    endif()
    foreach(bl_ssl_library IN ITEMS libcrypto_3.so libssl_3.so)
        if(NOT EXISTS "${BL_ANDROID_OPENSSL_DIR}/${bl_ssl_library}")
            message(FATAL_ERROR
                "Missing ${bl_ssl_library}. Build Android OpenSSL as described in "
                "docs/android-tls.md and set BL_ANDROID_OPENSSL_DIR.")
        endif()
    endforeach()
    # Qt Android deployment 将这两个 .so（运行时加载的共享库）装入 APK 并在启动时加载。
    # crypto 必须先于 ssl；后者的 ELF 依赖名称也必须是 libcrypto_3.so，不能借用系统私有库。
    set_property(TARGET appcursor_music APPEND PROPERTY QT_ANDROID_EXTRA_LIBS
        "${BL_ANDROID_OPENSSL_DIR}/libcrypto_3.so"
        "${BL_ANDROID_OPENSSL_DIR}/libssl_3.so"
    )
    # 随 Android 应用保留所部署 OpenSSL 的许可证，可从 Qt 资源路径读取。
    qt_add_resources(appcursor_music openssl_license
        PREFIX "/licenses" BASE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSES"
        FILES LICENSES/OpenSSL.txt
    )
    if(BL_ANDROID_TLS_DIAGNOSTICS)
        target_sources(appcursor_music PRIVATE src/platform/android/TlsDiagnostics.cpp)
        target_compile_definitions(appcursor_music PRIVATE BL_ANDROID_TLS_DIAGNOSTICS)
    endif()
    if(BL_ANDROID_LIFECYCLE_DIAGNOSTICS)
        # 即使误在 Release 配置开启选项，也不编入生命周期日志；仅用于本轮 Debug 行为观察。
        target_sources(appcursor_music PRIVATE
            "$<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/src/platform/android/LifecycleDiagnostics.cpp>"
        )
        target_compile_definitions(appcursor_music PRIVATE "$<$<CONFIG:Debug>:BL_ANDROID_LIFECYCLE_DIAGNOSTICS>")
    endif()
endif()

include(CTest)

if(BUILD_TESTING)
    find_package(Qt6 REQUIRED COMPONENTS Test QuickTest Qml)
    add_subdirectory(tests/unit)
    add_subdirectory(tests/quick)
    qt_add_resources(cursor_music_qml_tests cursor_music_qml_test_resources
        PREFIX "/qt/qml/cursor_music"
        FILES
            icon/home.svg
            icon/chevron-left.svg
            icon/chevron-right.svg
            icon/folder-heart.svg
            icon/log-in.svg
            icon/eye.svg
            icon/eye-off.svg
            icon/play.svg
            icon/pause.svg
            icon/skip-back.svg
            icon/skip-forward.svg
            icon/volume-2.svg
            icon/list-music.svg
            icon/repeat-2.svg
            icon/shuffle.svg
            icon/close.svg
            icon/refresh-cw.svg
            icon/music-2.svg
            icon/alert-circle.svg
    )
endif()

include(GNUInstallDirs)
install(TARGETS appcursor_music
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
