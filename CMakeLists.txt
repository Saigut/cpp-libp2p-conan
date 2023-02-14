# Prologue
cmake_minimum_required(VERSION 3.12)
project(cpp-libp2p-conan C CXX)

# Include
set(GV_other_dir z_other)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${GV_other_dir}/cmake")
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
            "${PROJECT_SOURCE_DIR}/${GV_other_dir}/conanfile.txt")
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
    endif()
endmacro()

macro(setup_build_environment)
    ## Setup Conan
    setup_conan()
    include(${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)

    add_definitions(${CONAN_DEFINES})

    ## Setup product options
    ### set_product_options()

    ## Paths
    set(GV_external_dir ${GV_other_dir}/external/${CMAKE_CXX_COMPILER_ID})
    message("External library path: ${GV_external_dir}")
    get_filename_component(GV_external_dir_a ${GV_external_dir} ABSOLUTE)

    ## Headers
    include_directories(
        include
        ${CONAN_INCLUDE_DIRS}
        ${GV_external_dir_a}/include
    )

    ## Libraries
    link_directories(
        ${GV_other_dir}/gen/lib
        ${CONAN_LIB_DIRS}
        ${GV_external_dir_a}/lib
    )

    ## Output
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
endmacro()

macro(setup_directories)
    set(V_dir_gen ${PROJECT_SOURCE_DIR}/${GV_other_dir}/gen)
    set(V_dir_gen_lib ${V_dir_gen}/lib)
    add_custom_command(
        OUTPUT "${V_dir_gen}"
        COMMAND ${CMAKE_COMMAND} -E make_directory ${V_dir_gen}
        DEPENDS "${PROJECT_SOURCE_DIR}/${GV_other_dir}"
    )
    add_custom_target(GT_dir_gen DEPENDS "${V_dir_gen}")
    add_custom_command(
        OUTPUT "${V_dir_gen_lib}"
        COMMAND ${CMAKE_COMMAND} -E make_directory ${V_dir_gen_lib}
        DEPENDS GT_dir_gen
    )
    add_custom_target(GT_dir_gen_lib DEPENDS "${V_dir_gen_lib}")
endmacro()

macro(setup_targets)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${V_dir_gen_lib})
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${V_dir_gen_lib})
    add_subdirectory(src/src-libp2p)

    set(GV_proj_src "")
    get_filename_component(GV_src_path "src" ABSOLUTE)
    file(GLOB GV_all_mod "${GV_src_path}/mod_*")
    file(GLOB GV_all_app "${GV_src_path}/app_*")
    file(GLOB GV_all_exec "${GV_src_path}/exec_*")

    setup_directories()

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
    set_target_properties(proj_lib PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${V_dir_gen_lib}")
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
