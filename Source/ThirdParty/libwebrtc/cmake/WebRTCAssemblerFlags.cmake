# GCC and Clang compile preprocessed assembly using the same driver as C, but
# CMake does not inherit the C compiler arguments or flags when enabling ASM.
function(WEBRTC_SET_ASSEMBLER_FLAGS)
    if (NOT CMAKE_ASM_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$"
        OR NOT CMAKE_ASM_COMPILER STREQUAL CMAKE_C_COMPILER)
        return()
    endif ()

    set(asm_compiler_flags "${CMAKE_ASM_COMPILER_ARG1}")
    if (CMAKE_ASM_COMPILER_TARGET AND CMAKE_ASM_COMPILER_ID MATCHES "Clang")
        # An explicitly selected ASM target must also override any --target
        # options inherited from the C compiler arguments or flags.
        string(APPEND asm_compiler_flags " --target=${CMAKE_ASM_COMPILER_TARGET}")
    elseif (CMAKE_C_COMPILER_TARGET AND NOT CMAKE_ASM_COMPILER_TARGET)
        set(CMAKE_ASM_COMPILER_TARGET "${CMAKE_C_COMPILER_TARGET}" PARENT_SCOPE)
    endif ()

    set(CMAKE_ASM_FLAGS "${CMAKE_C_COMPILER_ARG1} ${CMAKE_C_FLAGS} ${asm_compiler_flags} ${CMAKE_ASM_FLAGS}" PARENT_SCOPE)

    set(configurations DEBUG RELEASE RELWITHDEBINFO MINSIZEREL ${CMAKE_BUILD_TYPE} ${CMAKE_CONFIGURATION_TYPES})
    list(TRANSFORM configurations TOUPPER)
    list(REMOVE_DUPLICATES configurations)
    foreach (configuration IN LISTS configurations)
        # Keep explicit ASM settings after inherited configuration-specific flags.
        # Use directory-scoped variables so reconfiguration does not accumulate
        # inherited flags in the cache.
        set(CMAKE_ASM_FLAGS_${configuration} "${CMAKE_C_FLAGS_${configuration}} ${asm_compiler_flags} ${CMAKE_ASM_FLAGS} ${CMAKE_ASM_FLAGS_${configuration}}" PARENT_SCOPE)
    endforeach ()
endfunction()
