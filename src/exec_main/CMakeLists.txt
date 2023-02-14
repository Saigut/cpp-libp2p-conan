
set(V_program_name main)
add_executable(${V_program_name} main.cpp)
set(V_dep_libs ${CONAN_LIBS})
target_link_libraries(${V_program_name}
    proj_lib
    ${GV_gen_grpc_cpp_lib_bname}
    ${V_dep_libs})
target_link_libraries(${V_program_name} ${PLATFORM_LINK_LIB})
