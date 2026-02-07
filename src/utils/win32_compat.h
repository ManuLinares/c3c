#pragma once

/**
 * Centered Windows wrapper to handle common macro conflicts between 
 * windows.h and the c3c codebase (e.g., MAX_PRIORITY, TokenType).
 */

#if defined(_WIN32) || defined(_WIN64)

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

// 1. Handle MAX_PRIORITY conflict
#ifdef MAX_PRIORITY
#define PROJECT_MAX_PRIORITY_SAVE MAX_PRIORITY
#undef MAX_PRIORITY
#endif
#define MAX_PRIORITY WindowsMAX_PRIORITY

// 2. Handle TokenType conflict
// Some files define TokenType before including this. We shadow it for windows.h.
#ifdef TokenType
#define PROJECT_TOKENTYPE_SAVE TokenType
#undef TokenType
#endif
#define TokenType WindowsTokenType

#include <windows.h>

// Restore TokenType
#undef TokenType
#ifdef PROJECT_TOKENTYPE_SAVE
#define TokenType PROJECT_TOKENTYPE_SAVE
#undef PROJECT_TOKENTYPE_SAVE
#endif

// Restore MAX_PRIORITY
#undef MAX_PRIORITY
#ifdef PROJECT_MAX_PRIORITY_SAVE
#define MAX_PRIORITY PROJECT_MAX_PRIORITY_SAVE
#undef PROJECT_MAX_PRIORITY_SAVE
#endif

#endif
