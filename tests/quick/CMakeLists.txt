qt_add_executable(cursor_music_qml_tests quicktest.cpp)
target_compile_definitions(cursor_music_qml_tests PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
)
target_link_libraries(cursor_music_qml_tests PRIVATE
    Qt6::QuickTest
    Qt6::Qml
)
add_test(NAME cursor_music_qml_tests
    COMMAND cursor_music_qml_tests -platform offscreen
)
