qt_add_executable(tst_favoriteloadsession
    tst_favoriteloadsession.cpp
)

target_include_directories(tst_favoriteloadsession
    PRIVATE
        ${CMAKE_SOURCE_DIR}/src
)

target_link_libraries(tst_favoriteloadsession
    PRIVATE
        Qt6::Test
)

add_test(NAME tst_favoriteloadsession COMMAND tst_favoriteloadsession)

qt_add_executable(tst_mediaresolver
    tst_mediaresolver.cpp
    ${CMAKE_SOURCE_DIR}/src/player/MediaResolver.cpp
    ${CMAKE_SOURCE_DIR}/src/bilibili/BilibiliApiClient.cpp
    ${CMAKE_SOURCE_DIR}/src/network/HttpClient.cpp
)

target_include_directories(tst_mediaresolver
    PRIVATE
        ${CMAKE_SOURCE_DIR}/src
)

target_link_libraries(tst_mediaresolver
    PRIVATE
        Qt6::Test
        Qt6::Network
)

add_test(NAME tst_mediaresolver COMMAND tst_mediaresolver)

qt_add_executable(tst_appsettings
    tst_appsettings.cpp
    ${CMAKE_SOURCE_DIR}/src/storage/AppSettings.cpp
)

target_include_directories(tst_appsettings PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(tst_appsettings PRIVATE Qt6::Test)
add_test(NAME tst_appsettings COMMAND tst_appsettings)

qt_add_executable(tst_tlsdiagnostics
    tst_tlsdiagnostics.cpp
    ${CMAKE_SOURCE_DIR}/src/platform/android/TlsDiagnostics.cpp
)
target_include_directories(tst_tlsdiagnostics PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(tst_tlsdiagnostics PRIVATE Qt6::Test Qt6::Network)
add_test(NAME tst_tlsdiagnostics COMMAND tst_tlsdiagnostics)
