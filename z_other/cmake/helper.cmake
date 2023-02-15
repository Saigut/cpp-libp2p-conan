include_guard()

function(is_os_linux RET)
    set(${RET} FALSE)
endfunction()

function(target_link_boost_libraries TargetName)
    set(LibPrefix "")
    if(OS_WINDOWS)
        set(LibPrefix "lib")
    endif()
    foreach(arg IN LISTS ARGN)
        target_link_libraries(${TargetName} ${LibPrefix}${arg})
    endforeach()
endfunction()

# _DirTargetName[symbol]: target name. eg: GT_gen_dir
# _DirPath[string]: directory path. eg: "xx/xx", "${xx_path}"
# _Dep[symbol]: dependency of this directory, can be target name or path. eg: GT_gen_dir, xx_path
macro(dir_target _DirTargetName _DirPath _Dep)
    if (NOT "${${_Dep}}" STREQUAL "")
        set(V_Dep "${${_Dep}}")
    else()
        set(V_Dep ${_Dep})
    endif()
    add_custom_command(
        OUTPUT "${_DirPath}"
        COMMAND ${CMAKE_COMMAND} -E make_directory ${_DirPath}
        DEPENDS ${V_Dep})
    add_custom_target(${_DirTargetName} DEPENDS "${_DirPath}")
endmacro()

macro(setup_codegen_grpc)
    set(V_bin_search_path ${CONAN_BIN_DIRS})
    unset(GV_ptotoc_cmd CACHE)
    find_program(GV_ptotoc_cmd protoc PATHS ${V_bin_search_path} NO_DEFAULT_PATH)
    if (NOT GV_ptotoc_cmd)
        message(FATAL_ERROR "protoc is not found!" )
    endif()
    message("Found protoc: ${GV_ptotoc_cmd}")

    unset(GV_ptotoc_cpp_plugin CACHE)
    find_program(GV_ptotoc_cpp_plugin grpc_cpp_plugin PATHS ${V_bin_search_path} NO_DEFAULT_PATH)
    if (NOT GV_ptotoc_cpp_plugin)
        message(FATAL_ERROR "grpc_cpp_plugin is not found!")
    endif()
    message("Found grpc_cpp_plugin: ${GV_ptotoc_cpp_plugin}")
endmacro()

macro(setup_codegen)
#    setup_codegen_grpc()
endmacro()

# require: conan grpc
# _DirProto[string]: proto files path
# _DirGenCode[string]: directory to put generated code
# _LibName[symbol]: library name. eg: GL_xxx
# _Dep[symbol]: dependency
macro(codegen_grpc _DirProto _DirGenCode _LibName _Dep)
    set(V_dir_grpc_proto_r ${_DirProto})
    get_filename_component(V_dir_grpc_proto_a ${V_dir_grpc_proto_r} ABSOLUTE)
    file(GLOB V_all_proto_files "${V_dir_grpc_proto_r}/*.proto")

    if ("${V_all_proto_files}" STREQUAL "")
        message("CODEGEN GRPC WARN: Can't find proto files in directory ${_DirProto}!")
    else()
        set(V_total_gen_cpp_grpc_srcs)
        set(V_gen_grpc_cpp_src_targets)
        foreach(one_proto_file ${V_all_proto_files})
            get_filename_component(V_bname ${one_proto_file} NAME_WE)

            set(V_gen_cpp_grpc_srcs
                "${_DirGenCode}/${V_bname}.pb.h"
                "${_DirGenCode}/${V_bname}.pb.cc"
                "${_DirGenCode}/${V_bname}.grpc.pb.h"
                "${_DirGenCode}/${V_bname}.grpc.pb.cc"
                )
            list(APPEND V_total_gen_cpp_grpc_srcs ${V_gen_cpp_grpc_srcs})

            add_custom_command(
                OUTPUT ${V_gen_cpp_grpc_srcs}
                COMMAND ${GV_ptotoc_cmd}
                ARGS --grpc_out "${_DirGenCode}"
                --cpp_out "${_DirGenCode}"
                -I "${V_dir_grpc_proto_a}"
                --plugin=protoc-gen-grpc=${GV_ptotoc_cpp_plugin}
                ${one_proto_file}
                DEPENDS "${one_proto_file}" ${_Dep}
            )
            add_custom_target(GT_gen_${V_bname}_grpc_cpp_src DEPENDS ${V_gen_cpp_grpc_srcs})
            list(APPEND V_gen_grpc_cpp_src_targets GT_gen_${V_bname}_grpc_cpp_src)
        endforeach()

        add_custom_target(${_LibName}_gen_src DEPENDS ${V_gen_grpc_cpp_src_targets})

        if (NOT "${V_total_gen_cpp_grpc_srcs}" STREQUAL "")
            add_library(${_LibName} STATIC ${V_total_gen_cpp_grpc_srcs})
            add_dependencies(${_LibName} ${_LibName}_gen_src)
        endif()
    endif()
endmacro()

macro(add_proto_library TARGET)
    cmake_parse_arguments(add_proto_library "" "" "" "${ARGN}")

    set(protobuf_generate_GENERATE_EXTENSIONS .pb.h .pb.cc)

    foreach(_proto ${add_proto_library_UNPARSED_ARGUMENTS})
        get_filename_component(_abs_file ${_proto} ABSOLUTE)
        get_filename_component(_abs_dir ${_abs_file} DIRECTORY)
        get_filename_component(_basename ${_proto} NAME_WLE)
        file(RELATIVE_PATH _rel_dir ${CMAKE_SOURCE_DIR} ${_abs_dir})
        set(_generated_srcs)
        foreach(_ext ${protobuf_generate_GENERATE_EXTENSIONS})
            list(APPEND _generated_srcs "${GT_dir_gen_grpc_cpp}/${_basename}${_ext}")
        endforeach()

        add_custom_command(
            OUTPUT ${_generated_srcs}
            COMMAND ${GV_ptotoc_cmd}
            ARGS --cpp_out ${GV_dir_gen_grpc_cpp} -I ${_abs_dir} ${_abs_file}
            DEPENDS ${_abs_file} GT_dir_gen_grpc_cpp
            COMMENT "Running cpp protocol buffer compiler on ${_proto}"
            VERBATIM
        )
    endforeach()

    add_library(${TARGET} ${_generated_srcs})
    target_include_directories(${TARGET} PUBLIC ${GV_dir_gen_grpc_cpp})
    target_link_libraries(${TARGET} protobuf::protobuf)
endmacro()

function(libp2p_install targets)
endfunction()

function(libp2p_add_library target)
    add_library(${target} ${ARGN})
endfunction()
