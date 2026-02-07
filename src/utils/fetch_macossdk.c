#include <sys/stat.h>
#if !defined(_WIN32)
#include <unistd.h>
#else
#define lstat stat
#define S_ISLNK(m) 0
typedef long long ssize_t;
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include "build/build.h"
#include "utils/lib.h"
#include "utils/whereami.h"

#include <lzma.h>
#include "miniz.h"
#include "utils/dirent_compat.h" // IWYU pragma: keep

static int verbose_level = 0;

#define VERBOSE_PRINT(level, ...) do { if (verbose_level >= (level)) printf(__VA_ARGS__); } while (0)

#define IO_BUFFER_SIZE 65536
#define SMALL_IO_BUFFER_SIZE 8192

#define XAR_MAGIC 0x78617221
#define PBZX_MAGIC "pbzx"
#define CPIO_NEWC_MAGIC "070701"
#define CPIO_ODC_MAGIC "070707"
#define XZ_MAGIC_BYTES "\xfd" "7zXZ"

#define PROGRESS_START 0
#define PROGRESS_DMG_EXTRACTED 10
#define PROGRESS_PKG_UNPACKED 20
#define PROGRESS_PAYLOADS_EXTRACTED 75
#define PROGRESS_SDK_ORGANIZED 98
#define PROGRESS_DONE 100

static int count_files_recursive(const char *path)
{
	int count = 0;
#if !PLATFORM_WINDOWS
	DIR *d = opendir(path);
	if (!d) return 0;
	struct dirent *de;
	while ((de = readdir(d)))
	{
		if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0) continue;
		char *full = (char *)file_append_path(path, de->d_name);
		struct stat st;
		if (lstat(full, &st) == 0)
		{
			count++;
			if (S_ISDIR(st.st_mode)) count += count_files_recursive(full);
		}
	}
	closedir(d);
#endif
	return count;
}

static void copy_dir_recursive(const char *src, const char *dst, int *copied, int total, int p_start, int p_end)
{
#if !PLATFORM_WINDOWS
	DIR *d = opendir(src);
	if (!d) return;
	dir_make_recursive((char *)dst);
	struct dirent *de;
	while ((de = readdir(d)))
	{
		if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0) continue;
		char *s_path = (char *)file_append_path(src, de->d_name);
		char *d_path = (char *)file_append_path(dst, de->d_name);
		
		struct stat st;
		if (lstat(s_path, &st) == 0)
		{
			if (copied && total > 0)
			{
				(*copied)++;
				if ((*copied) % 100 == 0 && verbose_level == 0)
				{
					ui_print_progress("Extracting macOS SDK", p_start + (int)((p_end - p_start) * (*copied) / total));
				}
			}

			if (S_ISLNK(st.st_mode))
			{
				char link_target[4096];
				ssize_t len = readlink(s_path, link_target, sizeof(link_target) - 1);
				if (len != -1)
				{
					link_target[len] = '\0';
					file_delete_file(d_path);
					symlink(link_target, d_path);
				}
			}
			else if (S_ISDIR(st.st_mode))
			{
				copy_dir_recursive(s_path, d_path, copied, total, p_start, p_end);
			}
			else
			{
				file_copy_file(s_path, d_path, true);
			}
		}
	}
	closedir(d);
#else
	dir_make_recursive((char *)dst);
#endif
}

static char *get_macos_sdk_output_path(void)
{
	char *env_path = NULL;
#if PLATFORM_WINDOWS
	env_path = getenv("LOCALAPPDATA");
#else
	env_path = getenv("XDG_CACHE_HOME");
#endif

	if (env_path)
	{
		return file_append_path(env_path, "c3/macos_sdk");
	}

#if !PLATFORM_WINDOWS
	char *home = getenv("HOME");
	if (home) return file_append_path(home, ".cache/c3/macos_sdk");
#endif

	const char *path = find_executable_path();
	return file_append_path(path, "macos_sdk");
}

static uint32_t parse_octal(const char *s, int len)
{
	char buf[12];
	if (len > 11) len = 11;
	memcpy(buf, s, len);
	buf[len] = 0;
	return (uint32_t)strtoul(buf, NULL, 8);
}

static uint32_t parse_hex8(const char *s)
{
	char buf[9];
	memcpy(buf, s, 8);
	buf[8] = 0;
	return (uint32_t)strtoul(buf, NULL, 16);
}

static uint64_t read_be64(FILE *f)
{
	uint8_t b[8];
	if (fread(b, 1, 8, f) != 8) return 0;
	uint64_t v = 0;
	for (int i = 0; i < 8; i++) v = (v << 8) | b[i];
	return v;
}

static uint32_t read_be32(FILE *f)
{
	uint8_t b[4];
	if (fread(b, 1, 4, f) != 4) return 0;
	return (uint32_t)((b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]);
}

static uint64_t read_be64_f(FILE *f)
{
	uint8_t b[8];
	if (fread(b, 1, 8, f) != 8) return 0;
	uint64_t v = 0;
	for (int i = 0; i < 8; i++) v = (v << 8) | b[i];
	return v;
}

typedef struct {
	const char *base_dir;
	FILE *in;
	lzma_stream *strm;
	bool is_lzma;
	uint64_t remaining_chunk;
	uint64_t main_flags;
	uint8_t buffer[IO_BUFFER_SIZE];
	uint8_t in_buffer[IO_BUFFER_SIZE];
	size_t buf_pos;
	size_t buf_len;
} CpioState;

static bool cpio_read(CpioState *s, void *dst, size_t len)
{
	uint8_t *p = (uint8_t *)dst;
	while (len > 0)
	{
		if (s->buf_pos >= s->buf_len)
		{
			if (s->remaining_chunk == 0)
			{
				if (!(s->main_flags & 0x01000000ULL)) {
					return false;
				}
				
				uint64_t chunk_flags = read_be64(s->in);
				uint64_t chunk_size = read_be64(s->in);

				if (chunk_flags == 0 && chunk_size == 0) {
					s->main_flags = 0;
					return false;
				}
				
				uint8_t xz_peek[6];
				long pos = ftell(s->in);
				if (fread(xz_peek, 1, 6, s->in) == 6 && memcmp(xz_peek, XZ_MAGIC_BYTES, 6) == 0) {
					s->is_lzma = true;
				} else {
					s->is_lzma = false;
				}
				fseek(s->in, pos, SEEK_SET);

				s->main_flags = chunk_flags;
				s->remaining_chunk = chunk_size;
				
				
				if (s->is_lzma) {
					lzma_end(s->strm);
					lzma_stream tmp = LZMA_STREAM_INIT;
					*(s->strm) = tmp;
					if (lzma_stream_decoder(s->strm, UINT64_MAX, LZMA_CONCATENATED) != LZMA_OK) {
						VERBOSE_PRINT(1, "    ERROR: Failed to re-init LZMA decoder\n");
						return false;
					}
				}
			}

			if (s->is_lzma)
			{
				s->strm->next_out = s->buffer;
				s->strm->avail_out = sizeof(s->buffer);
				
				while (s->strm->avail_out == sizeof(s->buffer))
				{
					if (s->strm->avail_in == 0 && s->remaining_chunk > 0)
					{
						size_t to_read = (size_t)(s->remaining_chunk < sizeof(s->in_buffer) ? s->remaining_chunk : sizeof(s->in_buffer));
						size_t n = fread(s->in_buffer, 1, to_read, s->in);
						if (n == 0) break;
						s->strm->next_in = s->in_buffer;
						s->strm->avail_in = n;
						s->remaining_chunk -= n;
					}
					
					lzma_ret ret = lzma_code(s->strm, LZMA_RUN);
					if (ret == LZMA_STREAM_END) break;
					if (ret != LZMA_OK) break;
					if (s->strm->avail_in == 0 && s->remaining_chunk == 0) break;
				}
				s->buf_len = sizeof(s->buffer) - s->strm->avail_out;
				s->buf_pos = 0;
				
				if (s->buf_len == 0 && s->remaining_chunk == 0) continue;
			}
			else
			{
				size_t to_read = (size_t)(s->remaining_chunk < sizeof(s->buffer) ? s->remaining_chunk : sizeof(s->buffer));
				size_t n = fread(s->buffer, 1, to_read, s->in);
				if (n == 0) return false;
				s->buf_len = n;
				s->buf_pos = 0;
				s->remaining_chunk -= n;
			}
		}
		
		size_t avail = s->buf_len - s->buf_pos;
		if (avail == 0) return false;
		size_t to_copy = len < avail ? len : avail;
		memcpy(p, s->buffer + s->buf_pos, to_copy);
		p += to_copy;
		len -= to_copy;
		s->buf_pos += to_copy;
	}
	return true;
}

static void cpio_skip(CpioState *s, size_t len)
{
	uint8_t dummy[SMALL_IO_BUFFER_SIZE];
	while (len > 0)
	{
		size_t chunk = len < sizeof(dummy) ? len : sizeof(dummy);
		cpio_read(s, dummy, chunk);
		len -= chunk;
	}
}


static void pbzx_extract(const char *pbzx_path, const char *out_dir, int range_start, int range_end)
{
	FILE *in = fopen(pbzx_path, "rb");
	if (!in) return;

	fseek(in, 0, SEEK_END);
	uint64_t total_size = (uint64_t)ftell(in);
	fseek(in, 0, SEEK_SET);

	char magic[4];
	if (fread(magic, 1, 4, in) != 4 || strncmp(magic, PBZX_MAGIC, 4) != 0)
	{
		fclose(in);
		return;
	}

	uint64_t main_flags = read_be64(in);
	
	lzma_stream strm = LZMA_STREAM_INIT;
	CpioState state = {0};
	state.base_dir = out_dir;
	state.in = in;
	state.strm = &strm;
	state.main_flags = main_flags;
	state.remaining_chunk = 0; // Trigger header read in cpio_read

	VERBOSE_PRINT(1, "  Extracting PBZX stream content...\n");
	
	while (true)
	{
		if (total_size > 0 && verbose_level == 0)
		{
			uint64_t current = (uint64_t)ftell(in);
			int p = range_start + (int)((range_end - range_start) * current / total_size);
			ui_print_progress("Extracting macOS SDK", p);
		}
		
		char magic_cpio[6];
		while (true) {
			if (!cpio_read(&state, magic_cpio, 1)) goto DONE;
			if (magic_cpio[0] != '0') continue;
			if (!cpio_read(&state, magic_cpio + 1, 5)) goto DONE;
			if (strncmp(magic_cpio, CPIO_NEWC_MAGIC, 6) == 0 || strncmp(magic_cpio, CPIO_ODC_MAGIC, 6) == 0) break;
		}
		
		uint32_t namesize, filesize, mode, header_len;
		bool is_newc = (strncmp(magic_cpio, CPIO_NEWC_MAGIC, 6) == 0);

		if (is_newc) {
			char rest[104];
			if (!cpio_read(&state, rest, 104)) break;
			mode     = parse_hex8(rest + 14 - 6);
			filesize = parse_hex8(rest + 54 - 6);
			namesize = parse_hex8(rest + 94 - 6);
			header_len = 110;
		} else {
			char rest[70];
			if (!cpio_read(&state, rest, 70)) break;
			mode     = parse_octal(rest + 12, 6); 
			namesize = parse_octal(rest + 53, 6); 
			filesize = parse_octal(rest + 59, 11);
			header_len = 76;
		}

		char *name = malloc(namesize);
		cpio_read(&state, name, namesize);

		int align = is_newc ? 4 : 1;
		size_t pad = (align - ((header_len + namesize) % align)) % align;
		if (pad) {
			cpio_skip(&state, pad);
		}

		if (strcmp(name, "TRAILER!!!") == 0)
		{
			free(name);
			break;
		}

		VERBOSE_PRINT(2, "      Extracting: %s\n", name);
		char *path = (char *)file_append_path(state.base_dir, name);
		
		if ((mode & 0170000) == 0040000) // Directory
		{
			dir_make_recursive(path);
		}
		else if ((mode & 0170000) == 0120000) // Symlink
		{
			char *target = malloc(filesize + 1);
			cpio_read(&state, target, filesize);
			target[filesize] = 0;
#if !PLATFORM_WINDOWS
			file_create_folders(path);
			symlink(target, path);
#else
			// On Windows, copy the symlink target instead of creating a symlink
			char *target_path = (char *)file_append_path(state.base_dir, target);
			if (file_exists(target_path))
			{
				file_copy_file(target_path, path, true);
			}
#endif
			free(target);
		}
		else if ((mode & 0170000) == 0100000) // Regular file
		{
			file_create_folders(path);
			FILE *out = fopen(path, "wb");
			if (out)
			{
				uint8_t fbuf[SMALL_IO_BUFFER_SIZE];
				uint32_t rem = filesize;
				while (rem > 0)
				{
					uint32_t chunk = rem < sizeof(fbuf) ? rem : (uint32_t)sizeof(fbuf);
					cpio_read(&state, fbuf, chunk);
					fwrite(fbuf, 1, chunk, out);
					rem -= chunk;
				}
				fclose(out);
				chmod(path, mode & 0777);
			}
			else
			{
				cpio_skip(&state, filesize);
			}
		}
		else
		{
			cpio_skip(&state, filesize);
		}

		size_t data_pad = (align - (filesize % align)) % align;
		if (data_pad) cpio_skip(&state, data_pad);
		
		free(name);
	}

DONE:
	lzma_end(&strm);
	fclose(in);
}

static void xar_extract_to_dir(const char *xar_path, const char *out_dir, int range_start, int range_end)
{
	FILE *f = fopen(xar_path, "rb");
	if (!f) return;

	fseek(f, 0, SEEK_END);
	uint64_t total_size = (uint64_t)ftell(f);
	fseek(f, 0, SEEK_SET);

	uint32_t magic = read_be32(f);
	if (magic != XAR_MAGIC)
	{
		fclose(f);
		return;
	}

	uint16_t header_size = (uint16_t)((fgetc(f) << 8) | fgetc(f));
	uint16_t version = (uint16_t)((fgetc(f) << 8) | fgetc(f));
	(void)version;

	uint64_t toc_compressed = read_be64_f(f);
	uint64_t toc_uncompressed = read_be64_f(f);
	
	VERBOSE_PRINT(1, "  XAR Header: size=%u, toc_comp=%llu, toc_uncomp=%llu\n", 
		header_size, (unsigned long long)toc_compressed, (unsigned long long)toc_uncompressed);

	if (toc_compressed == 0 || toc_compressed > 100 * 1024 * 1024)
	{
		fprintf(stderr, "Error: Invalid XAR TOC size\n");
		fclose(f);
		return;
	}

	fseek(f, header_size, SEEK_SET);

	uint8_t *toc_comp_buf = malloc(toc_compressed);
	if (fread(toc_comp_buf, 1, (size_t)toc_compressed, f) != (size_t)toc_compressed)
	{
		free(toc_comp_buf);
		fclose(f);
		return;
	}

	uint8_t *toc_uncomp_buf = malloc(toc_uncompressed + 1);
	z_stream strm = { .zalloc = Z_NULL, .zfree = Z_NULL, .opaque = Z_NULL, 
	                  .avail_in = (uint32_t)toc_compressed, .next_in = toc_comp_buf, 
	                  .avail_out = (uint32_t)toc_uncompressed, .next_out = toc_uncomp_buf };
	
	if (inflateInit(&strm) != Z_OK)
	{
		free(toc_comp_buf);
		free(toc_uncomp_buf);
		fclose(f);
		return;
	}
	inflate(&strm, Z_FINISH);
	inflateEnd(&strm);
	toc_uncomp_buf[toc_uncompressed] = 0;

	uint64_t heap_offset = (uint64_t)header_size + toc_compressed;
	
	char *p = (char *)toc_uncomp_buf;
	char *path_stack[64];
	int stack_depth = 0;
	VERBOSE_PRINT(1, "  Scanning XAR TOC...\n");

	while (p && *p)
	{
		char *next_file = strstr(p, "<file");
		char *next_close = strstr(p, "</file>");

		if (next_file && (!next_close || next_file < next_close))
		{
			// Open <file>
			p = next_file + 5;
			char *name_start = strstr(p, "<name>");
			if (name_start && (!next_close || name_start < next_close))
			{
				name_start += 6;
				char *name_end = strchr(name_start, '<');
				if (name_end)
				{
					int name_len = (int)(name_end - name_start);
					char name[256];
					if (name_len > 255) name_len = 255;
					memcpy(name, name_start, name_len);
					name[name_len] = 0;
					
					path_stack[stack_depth] = str_dup(name);
					stack_depth++;

					char full_rel_path[4096] = {0};
					for (int i = 0; i < stack_depth; i++)
					{
						if (i > 0) strcat(full_rel_path, "/");
						strcat(full_rel_path, path_stack[i]);
					}

					char *abs_out_path = (char *)file_append_path(out_dir, full_rel_path);
					VERBOSE_PRINT(2, "    Found: %s\n", full_rel_path);

					if (total_size > 0 && verbose_level == 0)
					{
						int p = range_start + (int)((range_end - range_start) * ftell(f) / total_size);
						ui_print_progress("Extracting macOS SDK", p);
					}

					char *data_tag = strstr(p, "<data>");
					char *inner_file_start = strstr(p, "<file");
					if (data_tag && next_close && data_tag < next_close && (!inner_file_start || data_tag < inner_file_start))
					{
						char *off_tag = strstr(data_tag, "<offset>");
						char *sz_tag = strstr(data_tag, "<size>");
						if (off_tag && sz_tag && off_tag < next_close && sz_tag < next_close)
						{
							uint64_t offset = strtoull(off_tag + 8, NULL, 10);
							uint64_t size = strtoull(sz_tag + 6, NULL, 10);

							fseek(f, (long)(heap_offset + offset), SEEK_SET);
							file_create_folders(abs_out_path);
							FILE *out = fopen(abs_out_path, "wb");
							if (out)
							{
								uint8_t buffer[IO_BUFFER_SIZE];
								uint64_t rem = size;
								while (rem > 0)
								{
									uint64_t chunk = rem < sizeof(buffer) ? rem : sizeof(buffer);
									if (fread(buffer, 1, (size_t)chunk, f) != (size_t)chunk) break;
									fwrite(buffer, 1, (size_t)chunk, out);
									rem -= chunk;
								}
								fclose(out);
							}
						}
					}
					else
					{
						dir_make_recursive(abs_out_path);
					}
					
					p = name_end;
				}
			}
		}
		else if (next_close)
		{
			// Close </file>
			if (stack_depth > 0) stack_depth--;
			p = next_close + 7;
		}
		else
		{
			break;
		}
	}

	free(toc_comp_buf);
	free(toc_uncomp_buf);
	fclose(f);
}

static void extract_payloads(const char *pkg_data_dir, const char *out_dir)
{
	int total_pkgs = 0;
	DIR *count_d = opendir(pkg_data_dir);
	if (count_d)
	{
		struct dirent *de;
		while ((de = readdir(count_d)))
		{
			if (strstr(de->d_name, ".pkg")) total_pkgs++;
		}
		closedir(count_d);
	}

	if (total_pkgs == 0) return;

	int pkgs_done = 0;
	DIR *d = opendir(pkg_data_dir);
	if (d)
	{
		struct dirent *de;
		while ((de = readdir(d)))
		{
			if (strstr(de->d_name, ".pkg"))
			{
				char *subpkg_payload = (char *)file_append_path(pkg_data_dir, de->d_name);
				subpkg_payload = (char *)file_append_path(subpkg_payload, "Payload");
				if (file_exists(subpkg_payload))
				{
					pkgs_done++;
					VERBOSE_PRINT(1, "  Unpacking %s...\n", de->d_name);
					int p_start = PROGRESS_PKG_UNPACKED + ((PROGRESS_PAYLOADS_EXTRACTED - PROGRESS_PKG_UNPACKED) * (pkgs_done - 1) / total_pkgs);
					int p_end = PROGRESS_PKG_UNPACKED + ((PROGRESS_PAYLOADS_EXTRACTED - PROGRESS_PKG_UNPACKED) * pkgs_done / total_pkgs);
					pbzx_extract(subpkg_payload, out_dir, p_start, p_end);
				}
			}
		}
		closedir(d);
	}
}

void fetch_macossdk(BuildOptions *options)
{
	verbose_level = options->verbosity_level;

	if (vec_size(options->files) != 1)
	{
		fprintf(stderr, "Error: fetch-macossdk expects exactly one DMG file.\n");
		exit(1);
	}
	const char *dmg_path = options->files[0];
	
	char *abs_dmg_path = realpath(dmg_path, NULL);
	if (!abs_dmg_path) 
	{
		fprintf(stderr, "Error: Could not resolve path '%s'\n", dmg_path);
		exit(1);
	}

	if (!file_exists(abs_dmg_path))
	{
		fprintf(stderr, "Error: File not found: %s\n", abs_dmg_path);
		exit(1);
	}

	VERBOSE_PRINT(1, "Fetching macOS SDK from: %s\n", abs_dmg_path);

	const char *tmp_base = dir_make_temp_dir();
	char *pkg_tmp_path = (char *)file_append_path(tmp_base, "CLT.pkg");
	
	if (verbose_level == 0) ui_print_progress("Extracting macOS SDK", PROGRESS_START);
	VERBOSE_PRINT(1, "Step 1: Extracting PKG from DMG (using 7z)...\n");
	char *extract_cmd = str_printf("7z e -so \"%s\" \"Command Line Developer Tools/Command Line Tools*.pkg\" > \"%s\"", abs_dmg_path, pkg_tmp_path);
	
	if (system(extract_cmd) != 0)
	{
		if (verbose_level == 0) printf("\n");
		fprintf(stderr, "Error: Failed to extract PKG from DMG. Ensure '7z' is installed.\n");
		exit(1);
	}

	if (verbose_level == 0) ui_print_progress("Extracting macOS SDK", PROGRESS_DMG_EXTRACTED);
	VERBOSE_PRINT(1, "Step 2: Unpacking PKG structure natively...\n");
	char *pkg_data_dir = (char *)file_append_path(tmp_base, "pkg_data");
	dir_make_recursive(pkg_data_dir);

	xar_extract_to_dir(pkg_tmp_path, pkg_data_dir, PROGRESS_DMG_EXTRACTED, PROGRESS_PKG_UNPACKED);
	if (verbose_level == 0) ui_print_progress("Extracting macOS SDK", PROGRESS_PKG_UNPACKED);

	char *out_dir = (char *)file_append_path(tmp_base, "out");
	dir_make_recursive(out_dir);

	extract_payloads(pkg_data_dir, out_dir);
	
	if (verbose_level == 0) ui_print_progress("Extracting macOS SDK", PROGRESS_PAYLOADS_EXTRACTED);
	VERBOSE_PRINT(1, "\nExtraction successful. Organizing SDKs...\n");
	char *output_base = get_macos_sdk_output_path();
	dir_make_recursive(output_base);

	char *clt_root = (char *)file_append_path(out_dir, "Library/Developer/CommandLineTools");
	char *sdks_dir = (char *)file_append_path(clt_root, "SDKs");
	
	int total_files_work = count_files_recursive(clt_root);
	int files_processed = 0;

	DIR *d = opendir(sdks_dir);
	if (d)
	{
		struct dirent *de;
		while ((de = readdir(d)))
		{
			if (strstr(de->d_name, ".sdk") && strcmp(de->d_name, ".") != 0 && strcmp(de->d_name, "..") != 0)
			{
				char *src = (char *)file_append_path(sdks_dir, de->d_name);
				char *dst = (char *)file_append_path(output_base, de->d_name);
				
				VERBOSE_PRINT(1, "Found SDK: %s\n", de->d_name);
				
				struct stat st;
				if (lstat(src, &st) == 0)
				{
					file_delete_dir(dst);
					if (S_ISLNK(st.st_mode))
					{
#if !PLATFORM_WINDOWS
						char link_target[4096];
						ssize_t len = readlink(src, link_target, sizeof(link_target) - 1);
						if (len != -1)
						{
							link_target[len] = '\0';
							symlink(link_target, dst);
						}
						files_processed++; // Link counts as 1
#endif
					}
					else if (S_ISDIR(st.st_mode))
					{
						copy_dir_recursive(src, dst, &files_processed, total_files_work, PROGRESS_PAYLOADS_EXTRACTED, PROGRESS_SDK_ORGANIZED);
					}

					// Step: Merge libc++ headers if missing (only for directory SDKs)
					if (S_ISDIR(st.st_mode))
					{
						// Apple CLT puts them in usr/include/c++/v1 relative to CLT root
						char *clt_libcxx = (char *)file_append_path(clt_root, "usr/include/c++/v1");
						char *sdk_libcxx = (char *)file_append_path(dst, "usr/include/c++/v1");
						if (file_is_dir(clt_libcxx) && !file_exists(file_append_path(sdk_libcxx, "version")))
						{
							VERBOSE_PRINT(1, "  Merging libc++ headers into SDK...\n");
							dir_make_recursive(sdk_libcxx);
							copy_dir_recursive(clt_libcxx, sdk_libcxx, &files_processed, total_files_work, PROGRESS_PAYLOADS_EXTRACTED, PROGRESS_SDK_ORGANIZED);
						}
					}
				}
			}
		}
		closedir(d);
	}
	
	file_delete_dir(tmp_base);

	if (verbose_level == 0)
	{
		ui_print_progress("Extracting macOS SDK", PROGRESS_DONE);
		printf(" Done.\n");
		fflush(stdout);
	}

	VERBOSE_PRINT(0, "The macOS SDKs were successfully extracted to %s.\n", output_base);
}
