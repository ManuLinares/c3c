#pragma once

/**
 * Centered Windows wrapper to handle common macro conflicts between 
 * windows.h and the c3c codebase.
 */

#if defined(_WIN32) || defined(_WIN64)

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#ifdef MAX_PRIORITY
#define PROJECT_MAX_PRIORITY_SAVE MAX_PRIORITY
#undef MAX_PRIORITY
#endif
#define MAX_PRIORITY WindowsMAX_PRIORITY

#ifdef TokenType
#define PROJECT_TOKENTYPE_SAVE TokenType
#undef TokenType
#endif
#define TokenType WindowsTokenType

#include <windows.h>

#undef TokenType
#ifdef PROJECT_TOKENTYPE_SAVE
#define TokenType PROJECT_TOKENTYPE_SAVE
#undef PROJECT_TOKENTYPE_SAVE
#endif

#undef MAX_PRIORITY
#ifdef PROJECT_MAX_PRIORITY_SAVE
#define MAX_PRIORITY PROJECT_MAX_PRIORITY_SAVE
#undef PROJECT_MAX_PRIORITY_SAVE
#endif

#endif
