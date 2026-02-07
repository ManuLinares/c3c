#pragma once
// Copyright (c) 2019-2023 Christoffer Lerno. All rights reserved.
// Use of this source code is governed by the GNU LGPLv3.0 license
// a copy of which can be found in the LICENSE file.

// Cross-platform directory iteration compatibility layer
// Provides POSIX-like opendir/readdir/closedir on Windows

#if defined(_WIN32) || defined(_WIN64)

#define WIN32_LEAN_AND_MEAN
// Only shadow if TokenType isn't already defined (some files do this before including)
#ifndef TokenType
#define TokenType WindowsTokenType
#ifdef MAX_PRIORITY
#define PROJECT_MAX_PRIORITY MAX_PRIORITY
#undef MAX_PRIORITY
#endif
#define MAX_PRIORITY WindowsMAX_PRIORITY
#include <windows.h>
#undef TokenType
#undef MAX_PRIORITY
#ifdef PROJECT_MAX_PRIORITY
#define MAX_PRIORITY PROJECT_MAX_PRIORITY
#undef PROJECT_MAX_PRIORITY
#endif
#else
#include <windows.h>
#endif

#include "lib.h"
#include <sys/stat.h>

struct dirent
{
	char d_name[MAX_PATH];
};

typedef struct
{
	HANDLE handle;
	WIN32_FIND_DATAW data;
	struct dirent entry;
	bool first;
} DIR;

static inline DIR *opendir(const char *name)
{
	DIR *dir = calloc(1, sizeof(DIR));
	char *search_path = str_printf("%s\\*", name);
	uint16_t *wpath = win_utf8to16(search_path);
	dir->handle = FindFirstFileW(wpath, &dir->data);
	free(wpath);
	if (dir->handle == INVALID_HANDLE_VALUE)
	{
		free(dir);
		return NULL;
	}
	dir->first = true;
	return dir;
}

static inline struct dirent *readdir(DIR *dir)
{
	if (!dir->first && !FindNextFileW(dir->handle, &dir->data)) return NULL;
	dir->first = false;
	char *name = win_utf16to8(dir->data.cFileName);
	strncpy(dir->entry.d_name, name, MAX_PATH);
	free(name);
	return &dir->entry;
}

static inline void closedir(DIR *dir)
{
	if (dir) FindClose(dir->handle);
	free(dir);
}

#else
// On POSIX systems, just include the standard header
#include <dirent.h> // IWYU pragma: export
#endif
