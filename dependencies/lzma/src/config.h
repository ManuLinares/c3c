#ifndef LZMA_CONFIG_H
#define LZMA_CONFIG_H

#define HAVE_CHECK_CRC32 1
#define HAVE_CHECK_CRC64 1
#define HAVE_CHECK_SHA256 1
#define HAVE_DECODER_LZMA1 1
#define HAVE_DECODER_LZMA2 1

#define HAVE_STDINT_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_STDBOOL_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_LIMITS_H 1

#define HAVE_DECODERS 1

#ifdef _WIN32
#define TUKLIB_FAST_UNALIGNED_ACCESS 1
#define HAVE_VISIBILITY 0
#else
#define TUKLIB_FAST_UNALIGNED_ACCESS 1
#define HAVE_VISIBILITY 1
#define TUKLIB_PHYSMEM_SYSINFO 1
#define TUKLIB_CPUCORES_SYSCONF 1
#endif

// We don't need threading for minimal fetcher, but let's enable it if possible
#ifndef _WIN32
#define MYTHREAD_POSIX 1
#else
#define MYTHREAD_VISTA 1
#endif

#define SIZEOF_SIZE_T 8
#define VLI_CODER_COMMON 1

#endif
#define LZMA_UNRESTRICTED_CHECK
