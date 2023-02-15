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

function(compile_proto_to_cpp PB_H PB_CC PROTO)
#    get_target_property(Protobuf_INCLUDE_DIR protobuf::libprotobuf INTERFACE_INCLUDE_DIRECTORIES)
#    get_target_property(Protobuf_PROTOC_EXECUTABLE protobuf::protoc IMPORTED_LOCATION_RELEASE)

    if ("${Protobuf_PROTOC_EXECUTABLE}" STREQUAL "")
        message(FATAL_ERROR "Protobuf_PROTOC_EXECUTABLE is empty")
    endif ()
    if ("${Protobuf_INCLUDE_DIR}" STREQUAL "")
        message(FATAL_ERROR "Protobuf_INCLUDE_DIR is empty")
    endif ()

    get_filename_component(PROTO_ABS "${PROTO}" REALPATH)
    get_filename_component(PROTO_DIR ${PROTO_ABS} DIRECTORY)
    # get relative (to CMAKE_BINARY_DIR) path of current proto file
    file(RELATIVE_PATH SCHEMA_REL "${CMAKE_SOURCE_DIR}/src/src_libp2p" "${PROTO_DIR}")
    set(SCHEMA_OUT_DIR ${CMAKE_BINARY_DIR}/generated)
    file(MAKE_DIRECTORY ${SCHEMA_OUT_DIR})

    string(REGEX REPLACE "\\.proto$" ".pb.h" GEN_PB_HEADER ${PROTO})
    string(REGEX REPLACE "\\.proto$" ".pb.cc" GEN_PB ${PROTO})

    set(GEN_COMMAND ${Protobuf_PROTOC_EXECUTABLE})
    set(GEN_ARGS ${Protobuf_INCLUDE_DIR})

    add_custom_command(
        OUTPUT ${SCHEMA_OUT_DIR}/${SCHEMA_REL}/${GEN_PB_HEADER} ${SCHEMA_OUT_DIR}/${SCHEMA_REL}/${GEN_PB}
        COMMAND ${GEN_COMMAND}
        ARGS -I${CMAKE_SOURCE_DIR}/src/src_libp2p --cpp_out=${SCHEMA_OUT_DIR} ${SCHEMA_REL}/${PROTO}
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        DEPENDS protobuf::protoc
        VERBATIM
    )

    set(${PB_H} ${SCHEMA_OUT_DIR}/${SCHEMA_REL}/${GEN_PB_HEADER} PARENT_SCOPE)
    set(${PB_CC} ${SCHEMA_OUT_DIR}/${SCHEMA_REL}/${GEN_PB} PARENT_SCOPE)
endfunction()

add_custom_target(generated
    COMMENT "Building generated files..."
    )

function(disable_clang_tidy target)
    set_target_properties(${target} PROPERTIES
        C_CLANG_TIDY ""
        CXX_CLANG_TIDY ""
        )
endfunction()

function(add_proto_library NAME)
    set(SOURCES "")
    foreach (PROTO IN ITEMS ${ARGN})
        compile_proto_to_cpp(H C ${PROTO})
        list(APPEND SOURCES ${H} ${C})
    endforeach ()

    add_library(${NAME}
        ${SOURCES}
        )
    target_link_libraries(${NAME}
        protobuf::libprotobuf
        )
    target_include_directories(${NAME} PUBLIC
        ${CMAKE_BINARY_DIR}/generated/
        )
    disable_clang_tidy(${NAME})

    add_dependencies(generated ${NAME})
endfunction()

function(libp2p_install targets)
endfunction()

function(libp2p_add_library target)
    add_library(${target} ${ARGN})
endfunction()
