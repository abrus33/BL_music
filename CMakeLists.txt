cmake_minimum_required(VERSION 3.16)

project(cursor_music VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 REQUIRED COMPONENTS
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
        qml/components/Sidebar.qml
        qml/components/Theme.js
        qml/pages/HomePage.qml
        qml/pages/FavoritesPage.qml
        qml/pages/LoginPage.qml
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

include(GNUInstallDirs)
install(TARGETS appcursor_music
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
