# Prologue
cmake_minimum_required(VERSION 3.12)
project(cpp-libp2p-conan C CXX)

# Include
set(GV_other_dir_name z_other)
set(GV_other_dir ${PROJECT_SOURCE_DIR}/${GV_other_dir_name})
list(PREPEND CMAKE_MODULE_PATH "${GV_other_dir}/cmake")
include(common_var)
include(helper)
include(compiler)

macro(setup_platform_environment)
    ## Setup compilation options
    compiler_set_compilation_options()
endmacro()

macro(setup_conan)
    find_program(V_conan_cmd conan)
    if (NOT V_conan_cmd)
        message(WARNING "conan is not found!" )
    else()
        message("Found conan: ${V_conan_cmd}")
        set(V_conan_gen_files
            "${CMAKE_BINARY_DIR}/conanbuildinfo.cmake")
        set(V_conanfile
            "${PROJECT_SOURCE_DIR}/${GV_other_dir_name}/conanfile.txt")
        if (NOT EXISTS ${V_conanfile})
            message(WARNING "${V_conanfile} is not found!" )
        else()
            if (${V_conanfile} IS_NEWER_THAN ${V_conan_gen_files})
                file(REMOVE ${V_conan_gen_files})

                ## set up compiler settings
                set(V_conan_s_compiler "")
                set(V_conan_s_compiler_ver "")
                set(V_conan_s_compiler_cppstd "")
                set(V_conan_s_compiler_rt "")
                set(V_conan_s_build_type "")
                if (NOT V_conan_compiler STREQUAL "")
                    set(V_conan_s_compiler "-scompiler=${V_conan_compiler}")
                    set(V_conan_s_compiler_ver "-scompiler.version=${CMAKE_CXX_COMPILER_VERSION_MAJOR}")
                    if (V_conan_compiler STREQUAL "msvc")
                        string(SUBSTRING "${CMAKE_CXX_COMPILER_VERSION_MINOR}" 0 1 V_tmp_number)
                        set(V_conan_s_compiler_ver "${V_conan_s_compiler_ver}${V_tmp_number}")
                        set(V_conan_s_compiler_cppstd "-scompiler.cppstd=14")
                        set(V_conan_s_compiler_rt "-scompiler.runtime=dynamic")
                    else()
                        if ("${CMAKE_CXX_COMPILER_VERSION_MINOR}" STREQUAL "")
                        elseif("${CMAKE_CXX_COMPILER_VERSION_MINOR}" STREQUAL "0")
                        else()
#                            set(V_conan_s_compiler_ver "${V_conan_s_compiler_ver}.${CMAKE_CXX_COMPILER_VERSION_MINOR}")
                        endif ()
                    endif()
                endif()

                ## set up build_type
                if (CMAKE_BUILD_TYPE STREQUAL "Debug")
                    set(V_conan_s_build_type "-sbuild_type=Debug")
                else()
                    set(V_conan_s_build_type "-sbuild_type=Release")
                endif()

                ## conan install command
                set(V_conan_cmd ${V_conan_cmd} install ${V_conanfile} ${V_conan_s_compiler} ${V_conan_s_compiler_ver} ${V_conan_s_compiler_cppstd} ${V_conan_s_compiler_rt} ${V_conan_s_build_type} --build=missing)
                string(REPLACE ";" " " V_conan_cmd_str "${V_conan_cmd}")
                message("Executing: ${V_conan_cmd_str}")
                execute_process(COMMAND ${V_conan_cmd})
            endif()
        endif()
        include(${V_conan_gen_files})
    endif()
endmacro()

macro(setup_directories)
    set(GV_external_dir ${GV_other_dir_name}/external/${CMAKE_CXX_COMPILER_ID})
    message("External library path: ${GV_external_dir}")
    get_filename_component(GV_external_dir_a ${GV_external_dir} ABSOLUTE)

    set(GV_dir_gen ${GV_other_dir}/gen)
    set(GV_dir_gen_lib ${GV_dir_gen}/lib)
    set(GV_dir_gen_grpc_cpp ${GV_dir_gen}/grpc_cpp)
    dir_target(GT_dir_gen "${GV_dir_gen}" GV_other_dir)
    dir_target(GT_dir_gen_lib "${GV_dir_gen_lib}" GT_dir_gen)
    dir_target(GT_dir_gen_grpc_cpp "${GV_dir_gen_grpc_cpp}" GT_dir_gen)
endmacro()

macro(setup_dependency)
    list(PREPEND CMAKE_MODULE_PATH ${CMAKE_BINARY_DIR})
    list(PREPEND CMAKE_PREFIX_PATH ${CMAKE_BINARY_DIR})

    find_package(fmt REQUIRED)
    find_package(Boost REQUIRED)
    find_package(OpenSSL REQUIRED)
#    find_package(protobuf REQUIRED)
    find_package(Protobuf REQUIRED)
    find_package(tsl-hat-trie REQUIRED)
    find_package(c-ares REQUIRED)
    find_package(Microsoft.GSL REQUIRED)
    find_package(yaml-cpp REQUIRED)
endmacro()

macro(setup_build_environment)
    ## Setup directories
    setup_directories()

    ## Setup conan
    setup_conan()

    ## Setup dependency
    setup_dependency()

    ## Prepare code generator
    setup_codegen()

    ## Definitions
    add_definitions(${CONAN_DEFINES})

    ## Headers
    include_directories(
        include
        ${CMAKE_BINARY_DIR}
        ${GV_dir_gen_grpc_cpp}
        ${Boost_INCLUDE_DIRS}
        ${OpenSSL_INCLUDE_DIRS}
        ${fmt_INCLUDE_DIRS}
        ${Microsoft.GSL_INCLUDE_DIRS}
        ${yaml-cpp_INCLUDE_DIRS}
        ${GV_external_dir_a}/include
    )

    ## Libraries
    link_directories(
        ${GV_dir_gen_lib}
        ${CONAN_LIB_DIRS}
        ${GV_external_dir_a}/lib
    )

    ## Output
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${GV_dir_gen_lib})
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${GV_dir_gen_lib})
endmacro()

macro(setup_code_gen_targets)
#    codegen_grpc(
#        "${GV_other_dir}/code_to_gen/protos" "${GV_dir_gen_grpc_cpp}"
#        GL_gen_grpc
#        GT_dir_gen_grpc_cpp)
endmacro()

macro(setup_targets)
    add_subdirectory(src/src_libp2p)

    set(GV_proj_src "")
    get_filename_component(GV_src_path "src" ABSOLUTE)
    file(GLOB GV_all_mod "${GV_src_path}/mod_*")
    file(GLOB GV_all_app "${GV_src_path}/app_*")
    file(GLOB GV_all_exec "${GV_src_path}/exec_*")

    ## Code generator
    setup_code_gen_targets()

    ## Modules library
    foreach(one_dir ${GV_all_mod} ${GV_all_app})
        get_filename_component(tmp_name ${one_dir} NAME)
        file(GLOB GV_${tmp_name}_src "${one_dir}/*.cpp" "${one_dir}/*.c")
        file(GLOB tmp_sub_dirs "${one_dir}/*")
        foreach(one_sub_dir ${tmp_sub_dirs})
            if(IS_DIRECTORY ${one_sub_dir})
                file(GLOB tmp_sub_dir_files "${one_sub_dir}/*.cpp" "${one_sub_dir}/*.c")
                list(APPEND GV_${tmp_name}_src ${tmp_sub_dir_files})
            endif()
        endforeach()
        list(APPEND GV_proj_src ${GV_${tmp_name}_src})
    endforeach()

    ## Library in one
    add_library(proj_lib STATIC ${GV_proj_src})
    add_dependencies(proj_lib GT_dir_gen_lib)

    ## Main executable
    foreach(one_dir ${GV_all_exec})
        add_subdirectory(${one_dir})
    endforeach()
endmacro()

macro(main_func)
    setup_platform_environment()
    setup_build_environment()
    setup_targets()
endmacro()


main_func()
