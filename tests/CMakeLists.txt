find_package(GTest CONFIG REQUIRED)

add_executable(slotmap_tests test_slotmap.cpp)
target_link_libraries(slotmap_tests PRIVATE slotmap GTest::gtest_main)
target_compile_features(slotmap_tests PRIVATE cxx_std_23)

include(GoogleTest)
gtest_discover_tests(slotmap_tests)
