set(LZMA_SOURCES
    src/common/tuklib_physmem.c
    src/common/tuklib_cpucores.c
    src/liblzma/common/common.c
    src/liblzma/common/block_util.c
    src/liblzma/common/filter_common.c
    src/liblzma/common/filter_decoder.c
    src/liblzma/common/stream_decoder.c
    src/liblzma/common/vli_decoder.c
    src/liblzma/common/block_decoder.c
    src/liblzma/common/block_header_decoder.c
    src/liblzma/common/filter_flags_decoder.c
    src/liblzma/common/stream_flags_decoder.c
    src/liblzma/common/stream_flags_common.c
    src/liblzma/common/index.c
    src/liblzma/common/index_decoder.c
    src/liblzma/common/index_hash.c
    src/liblzma/common/vli_size.c
    src/liblzma/check/check.c
    src/liblzma/check/crc32_fast.c
    src/liblzma/check/crc64_fast.c
    src/liblzma/check/sha256.c
    src/liblzma/lz/lz_decoder.c
    src/liblzma/lzma/lzma_decoder.c
    src/liblzma/lzma/lzma2_decoder.c
    src/liblzma/lzma/fastpos_table.c
)

add_library(lzma STATIC ${LZMA_SOURCES})
target_compile_definitions(lzma PRIVATE HAVE_CONFIG_H)
target_include_directories(lzma PRIVATE
    include
    src
    src/common
    src/liblzma/common
    src/liblzma/check
    src/liblzma/lz
    src/liblzma/lzma
    src/liblzma/rangecoder
    src/liblzma/simple
    src/liblzma/delta
)
