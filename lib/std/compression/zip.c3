<*
 ZIP archive module (STORE and DEFLATE).

 API:
 - fn ZipArchive? open(String path, String mode = "r", Allocator allocator = mem)
 - fn ZipArchive? recover(String path, Allocator allocator = mem)
 - fn void?       ZipArchive.extract(&self, String output_dir)
 - fn ZipEntry?   ZipArchive.stat(&self, String filename)
 - fn char[]?     ZipArchive.read_file_all(&self, String filename, Allocator allocator = mem)
 - fn void?       ZipArchive.close(&self)
*>
module std::compression::zip;
import std::core::mem, std::io, std::collections::list, std::hash::crc32, std::time, std::math;
import std::io::file, std::io::path;
import std::encoding::codepage;
import libc;
import std::compression::deflate;

faultdef
	INVALID_ARGUMENT,
	IO_ERROR,
	CORRUPTED_DATA,
	ENTRY_NOT_FOUND,
	ENCRYPTED_FILE;

<*
 Describes a single entry within a ZIP archive.
*>
struct ZipEntry
{
	String name;
	ulong uncompressed_size;
	ulong compressed_size;
	bool is_directory;
	bool is_encrypted;
	uint crc32;
	ulong offset;
	ZipMethod method;
	ushort last_mod_time;
	ushort last_mod_date;
}

fn Time ZipEntry.time(&self) => dos_date_time_to_time(self.last_mod_date, self.last_mod_time);

alias ZipEntryList = List{ZipEntry};

struct ZipArchive
{
	File* file;
	Allocator allocator;
	ZipEntryList entries;
	String mode;
	String path;
	String comment;
}

const enum ZipMethod : ushort
{
	STORE = 0,
	DEFLATE = 8,
}

<*
 Opens a ZIP archive.
 @param path : `The path to the ZIP file.`
 @param mode : `Opening mode ("r", "w", "w+").`
 @param allocator : `The allocator to use.`
 @return `The opened archive.`
 @require mode == "r" || mode == "w" || mode == "w+"
*>
fn ZipArchive? open(String path, String mode = "r", Allocator allocator = mem)
{
	if (mode == "w" || mode == "w+")
	{
		File f = file::open(path, mode == "w+" ? "w+" : "w+b")!;

		ZipArchive archive;
		archive.allocator = allocator;
		archive.file = allocator::new(allocator, File, f);
		archive.entries.init(allocator);
		archive.path = path.copy(allocator);
		archive.mode = mode.copy(allocator);
		return archive;
	}
	else if (mode == "r")
	{
		File f = file::open(path, "rb")!;
		defer (catch err) (void)f.close();

		f.seek(0, END)!;
		usz file_size = (usz)f.seek(0, CURSOR)!;

		if (file_size < ZipEOCD.sizeof) return CORRUPTED_DATA~;

		usz search_start = file_size > (ZipEOCD.sizeof + 65535)
			? file_size - (ZipEOCD.sizeof + 65535)
			: 0;

		ZipEOCD eocd;
		bool found = false;

		for (isz pos = (isz)(file_size - ZipEOCD.sizeof); pos >= (isz)search_start; pos--)
		{
			f.seek(pos, SET)!;
			uint sig;
			if (f.read(((char*)&sig)[:4])! != 4) break;

			if (sig == ZIP_EOCD_SIG)
			{
				f.seek(pos, SET)!;
				if (f.read(((char*)&eocd)[:ZipEOCD.sizeof])! == ZipEOCD.sizeof)
				{
					usz expected_end = (usz)pos + ZipEOCD.sizeof + eocd.comment_len;
					if (expected_end == file_size)
					{
						found = true;
						break;
					}
				}
			}
		}

		if (!found) return CORRUPTED_DATA~;

		ZipArchive archive;
		archive.allocator = allocator;
		archive.file = allocator::new(allocator, File, f);
		archive.entries.init(allocator);
		archive.path = path.copy(allocator);
		archive.mode = mode.copy(allocator);

		if (eocd.comment_len > 0)
		{
			char[] comment_data = allocator::alloc_array(allocator, char, eocd.comment_len);
			if (archive.file.read(comment_data)! == eocd.comment_len)
			{
				archive.comment = (String)comment_data;
			}
			else
			{
				allocator::free(allocator, comment_data.ptr);
			}
		}

		defer (catch err) (void)archive.close();

		archive.file.seek((isz)eocd.cd_offset, SET)!;

		usz num_entries = eocd.num_entries;


		// ZIP64 check
		if (eocd.num_entries == 0xFFFF || eocd.cd_offset == 0xFFFFFFFF)
		{
			isz locator_pos = (isz)file_size - ZipEOCD.sizeof - Zip64Locator.sizeof;
			if (locator_pos >= 0)
			{
				archive.file.seek(locator_pos, SET)!;
				Zip64Locator locator;
				if (try n = archive.file.read(((char*)&locator)[:Zip64Locator.sizeof]))
				{
					if (n == Zip64Locator.sizeof && locator.signature == ZIP64_LOCATOR_SIG)
					{
						archive.file.seek((isz)locator.offset_eocd, SET)!;
						Zip64EOCD eocd64;
						archive.file.read(((char*)&eocd64)[:Zip64EOCD.sizeof])!;
						if (eocd64.signature == ZIP64_EOCD_SIG)
						{
							archive.file.seek((isz)eocd64.offset_cd, SET)!;
							num_entries = (usz)eocd64.count_total;
						}
					}
				}
			}
		}

		for (usz i = 0; i < num_entries; i++)
		{
			ZipCDH cdh;
			if (archive.file.read(((char*)&cdh)[:ZipCDH.sizeof])! != ZipCDH.sizeof) break;
			if (cdh.signature != ZIP_CDH_SIG) break;

			char[] raw_name = allocator::alloc_array(allocator, char, cdh.filename_len);
			if (archive.file.read(raw_name)! != (usz)cdh.filename_len)
			{
				allocator::free(allocator, raw_name);
				break;
			}

			String name;
			bool is_utf8 = (cdh.flags & 0x0800) != 0;
			if (is_utf8 || is_valid_utf8(raw_name))
			{
				name = (String)raw_name;
			}
			else
			{
				name = (String)codepage::decode(allocator, raw_name, CP437)!!;
				allocator::free(allocator, raw_name.ptr);
			}

			char[] extra_field;
			if (cdh.extra_field_len > 0)
			{
				extra_field = allocator::alloc_array(allocator, char, cdh.extra_field_len);
				archive.file.read(extra_field)!;
			}

			(void)archive.file.seek(cdh.comment_len, CURSOR);

			ulong uncompressed_size = cdh.uncompressed_size;
			ulong compressed_size = cdh.compressed_size;
			ulong offset = cdh.relative_offset;

			if (cdh.uncompressed_size == 0xFFFFFFFF || cdh.compressed_size == 0xFFFFFFFF || cdh.relative_offset == 0xFFFFFFFF)
			{
				ByteReader reader = { .bytes = extra_field };
				while (reader.available()! >= 4)
				{
					ushort id = io::read_le_ushort(&reader)!;
					ushort size = io::read_le_ushort(&reader)!;

					if (id == ZIP64_EXTRA_ID)
					{
						int remaining = size;
						if (cdh.uncompressed_size == 0xFFFFFFFF && remaining >= 8)
						{
							uncompressed_size = io::read_le_ulong(&reader)!;
							remaining -= 8;
						}
						if (cdh.compressed_size == 0xFFFFFFFF && remaining >= 8)
						{
							compressed_size = io::read_le_ulong(&reader)!;
							remaining -= 8;
						}
						if (cdh.relative_offset == 0xFFFFFFFF && remaining >= 8)
						{
							offset = io::read_le_ulong(&reader)!;
							remaining -= 8;
						}
						break;
					}
					reader.seek(size, CURSOR)!;
				}
			}
			if (extra_field.len > 0) allocator::free(allocator, extra_field);

			bool is_directory = name.ends_with("/") || name.ends_with("\\");
			if (!is_directory)
			{
				ushort host_system = cdh.version_made_by >> 8;
				if (host_system == 0 || host_system == 10) // MS-DOS or NTFS
				{
					if ((cdh.external_attr & 0x10) != 0) is_directory = true;
				}
				else if (host_system == 3) // Unix
				{
					if (((cdh.external_attr >> 16) & 0x4000) != 0) is_directory = true;
				}
			}

			ZipEntry entry = {
				.name = name,
				.uncompressed_size = uncompressed_size,
				.compressed_size = compressed_size,
				.crc32 = cdh.crc32,
				.offset = offset,
				.method = cdh.method,
				.last_mod_time = cdh.last_mod_time,
				.last_mod_date = cdh.last_mod_date,
				.is_directory = is_directory,
				.is_encrypted = (cdh.flags & 1) != 0
			};

			archive.entries.push(entry);
		}

		return archive;
	}
	return INVALID_ARGUMENT~;
}

<*
 Recovers a ZIP archive by scanning for Local File Headers
 when the Central Directory is missing or corrupted.
 @param path : `The path to the broken ZIP file.`
 @param allocator : `The allocator to use.`
 @return `The recovered archive.`
*>
fn ZipArchive? recover(String path, Allocator allocator = mem)
{
	File f = file::open(path, "rb")!;
	defer (catch err) (void)f.close();

	ZipArchive archive = {
		.allocator = allocator,
		.file = allocator::new(allocator, File, f),
		.path = path.copy(allocator),
		.mode = "r".copy(allocator)
	};
	archive.entries.init(allocator);
	defer (catch err) (void)archive.close();

	char[4] sig_buf;
	while (true)
	{
		ulong offset = archive.file.seek(0, CURSOR)!;
		usz n = archive.file.read(sig_buf[..])!;
		if (n < 4) break;

		if (bitorder::read(sig_buf, UIntLE) != ZIP_LFH_SIG)
		{
			(void)archive.file.seek(-3, CURSOR);
			continue;
		}

		ZipLFH lfh;
		if (archive.file.read(((char*)&lfh.version_needed)[:ZipLFH.sizeof - 4])! != ZipLFH.sizeof - 4) break;
		lfh.signature = ZIP_LFH_SIG;

		char[] raw_name = allocator::alloc_array(allocator, char, lfh.filename_len);
		if (archive.file.read(raw_name)! != (usz)lfh.filename_len)
		{
			allocator::free(allocator, raw_name);
			break;
		}

		String name;
		if ((lfh.flags & 0x0800) != 0 || is_valid_utf8(raw_name))
		{
			name = (String)raw_name;
		}
		else
		{
			name = (String)codepage::decode(allocator, raw_name, CP437)!!;
			allocator::free(allocator, raw_name.ptr);
		}

		archive.file.seek(lfh.extra_field_len, CURSOR)!;

		ZipEntry entry = {
			.name = name,
			.compressed_size = lfh.compressed_size,
			.uncompressed_size = lfh.uncompressed_size,
			.crc32 = lfh.crc32,
			.offset = offset,
			.method = lfh.method,
			.last_mod_time = lfh.last_mod_time,
			.last_mod_date = lfh.last_mod_date,
			.is_directory = name.ends_with("/") || name.ends_with("\\"),
			.is_encrypted = (lfh.flags & 1) != 0
		};

		archive.entries.push(entry);

		archive.file.seek((isz)lfh.compressed_size, CURSOR)!;
	}

	if (archive.entries.len() == 0) return CORRUPTED_DATA~;
	return archive;
}

<*
 Closes the ZIP archive, writing the central directory if in write mode.
*>
fn void? ZipArchive.close(&self)
{
	defer {
		(void)self.file.close();

		foreach (&entry : self.entries)
		{
			allocator::free(self.allocator, entry.name);
		}
		self.entries.free();
		allocator::free(self.allocator, self.mode);
		allocator::free(self.allocator, self.path);
		if (self.comment.len > 0) allocator::free(self.allocator, self.comment);
		if (self.file) allocator::free(self.allocator, self.file);
	}

	if (self.mode.starts_with("w"))
	{
		self.file.flush()!;
		ulong cd_offset = self.file.seek(0, CURSOR)!;
		ulong cd_size = 0;

		for (usz i = 0; i < self.entries.len(); i++)
		{
			ZipEntry* entry = self.entries.get_ref(i);
			ZipCDH cdh = {
				.signature = ZIP_CDH_SIG,
				.version_made_by = 45, // 4.5 for ZIP64
				.version_needed = 45,
				.method = entry.method,
				.crc32 = entry.crc32,
				.filename_len = (ushort)entry.name.len
			};

			bool is_zip64 = entry.uncompressed_size >= 0xFFFFFFFF || entry.compressed_size >= 0xFFFFFFFF || entry.offset >= 0xFFFFFFFF;

			io::printfn("is_zip64 = %s, entry.uncompressed_size = %s, entry.compressed_size = %s, entry.offset = %s", is_zip64, entry.uncompressed_size, entry.compressed_size, entry.offset);
			char[] extra_data;
			if (is_zip64)
			{
				cdh.compressed_size = 0xFFFFFFFF;
				cdh.uncompressed_size = 0xFFFFFFFF;
				cdh.relative_offset = 0xFFFFFFFF;

				// Header(4) + Uncomp(8) + Comp(8) + Offset(8)
				ushort extra_size = 28;
				extra_data = allocator::alloc_array(self.allocator, char, extra_size);
				bitorder::write(ZIP64_EXTRA_ID, extra_data[:2], UShortLE);
				bitorder::write((ushort)(extra_size - 4), extra_data[2:2], UShortLE);
				bitorder::write(entry.uncompressed_size, extra_data[4:8], ULongLE);
				bitorder::write(entry.compressed_size, extra_data[12:8], ULongLE);
				bitorder::write(entry.offset, extra_data[20:8], ULongLE);

				cdh.extra_field_len = extra_size;
			}
			else
			{
				cdh.compressed_size = (uint)entry.compressed_size;
				cdh.uncompressed_size = (uint)entry.uncompressed_size;
				cdh.relative_offset = (uint)entry.offset;
			}

			// Set external attributes (MS-DOS compatibility).
			// 0x10 is the DOS directory attribute.
			cdh.external_attr = entry.is_directory ? 0x10 : 0;

			io::write_any(self.file, &cdh)!;
			self.file.write(entry.name)!;
			if (is_zip64)
			{
				self.file.write(extra_data)!;
				allocator::free(self.allocator, extra_data.ptr);
			}

			cd_size += (ulong)(ZipCDH.sizeof + entry.name.len + cdh.extra_field_len);
		}

		bool cd_zip64 = self.entries.len() >= 0xFFFF || cd_size >= 0xFFFFFFFF || cd_offset >= 0xFFFFFFFF;

		if (cd_zip64)
		{
			ulong eocd64_offset = (ulong)self.file.seek(0, CURSOR)!;

			Zip64EOCD eocd64;
			eocd64.signature = ZIP64_EOCD_SIG;
			eocd64.size = Zip64EOCD.sizeof - 12;
			eocd64.version_made = 45;
			eocd64.version_needed = 45;
			eocd64.count_this_disk = (ulong)self.entries.len();
			eocd64.count_total = (ulong)self.entries.len();
			eocd64.size_cd = cd_size;
			eocd64.offset_cd = cd_offset;

			io::write_any(self.file, &eocd64)!;

			Zip64Locator locator;
			locator.signature = ZIP64_LOCATOR_SIG;
			locator.disk_start = 0;
			locator.offset_eocd = eocd64_offset;
			locator.total_disks = 1;

			io::write_any(self.file, &locator)!;
		}

		ZipEOCD eocd;
		eocd.signature = ZIP_EOCD_SIG;
		eocd.num_entries_this_disk = (ushort)(self.entries.len() >= 0xFFFF ? 0xFFFF : self.entries.len());
		eocd.num_entries = (ushort)(self.entries.len() >= 0xFFFF ? 0xFFFF : self.entries.len());
		eocd.cd_size = (uint)(cd_size >= 0xFFFFFFFF ? 0xFFFFFFFF : cd_size);
		eocd.cd_offset = (uint)(cd_offset >= 0xFFFFFFFF ? 0xFFFFFFFF : cd_offset);
		eocd.comment_len = (ushort)self.comment.len;

		io::write_any(self.file, &eocd)!;

		if (self.comment.len > 0)
		{
			self.file.write(self.comment)!;
		}
	}
}

<*
 Extracts the entire archive to the specified directory.
 @param output_dir : `The directory to extract to.`
*>
fn void? ZipArchive.extract(&self, String output_dir) => @pool()
{
	for (usz i = 0; i < self.count(); i++)
	{
		ZipEntry entry = self.stat_at(i) ?? ENTRY_NOT_FOUND~!;
		String out_path_str;
		if (try tmp = path::temp(output_dir))
		{
			if (try combined = tmp.tappend(entry.name))
			{
				out_path_str = combined.str_view();
			}
			else
			{
				return IO_ERROR~;
			}
		}
		else
		{
			return IO_ERROR~;
		}

		if (entry.is_directory)
		{
			(void)path::mkdir(out_path_str, true);
		}
		else
		{
			if (try tmp = path::temp(out_path_str))
			{
				if (try parent = tmp.parent())
				{
					(void)path::mkdir(parent.str_view(), true);
				}
			}

			ZipEntryReader reader = self.open_reader(entry.name)!;
			defer (void)reader.close();

			File f = file::open(out_path_str, "wb")!;
			char[65536] buf;
			while (true)
			{
				usz? res = reader.read(&buf);
				if (catch excuse = res)
				{
					if (excuse == io::EOF) break;
					return excuse~;
				}
				usz n = res;
				if (n == 0) break;
				f.write(buf[:n])!;
			}
			(void)f.close();

			(void)file::set_modified_time(out_path_str, (Time_t)entry.time().to_seconds());
		}
	}

	// Set directory timestamps (reverse order for subdirectories)
	for (isz i = (isz)self.count() - 1; i >= 0; i--)
	{
		ZipEntry entry;
		if (try res = self.stat_at((usz)i))
		{
			entry = res;
		}
		else
		{
			continue;
		}
		if (!entry.is_directory) continue;

		if (try tmp = path::temp(output_dir))
		{
			if (try combined = tmp.tappend(entry.name))
			{
				String out_path_str = (String)combined.str_view();
				(void)file::set_modified_time(out_path_str, (Time_t)entry.time().to_seconds());
			}
		}
	}
}

fn usz ZipArchive.count(&self) => self.entries.len();

<*
 Returns metadata for the entry at the given index.
 @require index < self.count()
*>
fn ZipEntry? ZipArchive.stat_at(&self, usz index)
{
	if (index >= self.entries.len()) return ENTRY_NOT_FOUND~;
	return self.entries.get(index);
}

<*
 Returns metadata for the entry with the given filename.
*>
fn ZipEntry? ZipArchive.stat(&self, String filename)
{
	for (usz i = 0; i < self.entries.len(); i++)
	{
		ZipEntry entry = self.entries.get(i);
		if (entry.name == filename) return entry;
	}
	return ENTRY_NOT_FOUND~;
}


<*
 Reads an entire file from the archive.
 @param filename : `The name of the file to read.`
 @param allocator : `The allocator to use.`
 @return `The uncompressed file data.`
*>
fn char[]? ZipArchive.read_file_all(&self, String filename, Allocator allocator = mem)
{
	ZipEntryReader reader = self.open_reader(filename)!;
	ZipEntry entry = self.stat(filename)!;

	char[] data;
	if (reader.method == STORE)
	{
		data = allocator::alloc_array(allocator, char, (usz)reader.size);
		reader.read(data)!;
	}
	else
	{
		self.file.seek((isz)reader.adapter.start_offset, SET)!;
		char[] compressed = allocator::alloc_array(allocator, char, (usz)entry.compressed_size);
		defer allocator::free(allocator, compressed.ptr);
		self.file.read(compressed)!;
		data = deflate::decompress(compressed, allocator)!;
	}
	defer catch allocator::free(allocator, data.ptr);

	Crc32 crc;
	crc.init();
	crc.update(data);
	if (~crc.result != entry.crc32) return CORRUPTED_DATA~;

	return data;
}


<*
 Adds a directory entry to the archive.
*>
fn void? ZipArchive.add_directory(&self, String dirname)
{
	String dir_name = dirname;
	if (!dirname.ends_with("/"))
	{
		dir_name = string::tformat("%s/", dirname);
	}

	ZipEntryWriter? writer_opt = self.open_writer(dir_name, STORE);
	if (catch err = writer_opt) return err~;

	ZipEntryWriter writer = writer_opt;
	writer.entry.is_directory = true;
	writer.close()!;
}

<*
 Writes an entire file to the archive.
 @param filename : `The name of the file to create.`
 @param data : `The data to write.`
 @param method : `Compression method.`
*>
fn void? ZipArchive.write_file(&self, String filename, char[] data, ZipMethod method = DEFLATE)
{
	ZipEntryWriter? writer = self.open_writer(filename, method);
	if (catch err = writer) return err~;

	writer.write(data)!;
	writer.close()!;
}

struct ZipEntryReader (InStream)
{
	ulong size; // Uncompressed size
	ulong pos;  // Uncompressed position
	ZipMethod method;
	// For DEFLATE
	Inflater* inflater;
	ArchiveStreamAdapter adapter;
	char* bit_buf;
}

fn usz? ZipEntryReader.read(&self, char[] buffer) @dynamic
{
	if (self.method == STORE)
	{
		return self.adapter.read(buffer);
	}
	else if (self.method == DEFLATE)
	{
		if (self.inflater == null)
		{
			self.inflater = allocator::new(self.adapter.archive.allocator, Inflater);
			self.bit_buf = allocator::alloc_array(self.adapter.archive.allocator, char, 8192);
			self.inflater.init(&self.adapter, self.bit_buf[:8192]);
		}

		usz n = self.inflater.read(buffer)!;
		if (n == 0) return io::EOF~;
		self.pos += n;
		return n;
	}

	return io::UNSUPPORTED_OPERATION~;
}

fn void? ZipEntryReader.close(&self) @dynamic
{
	if (self.method == DEFLATE && self.inflater != null)
	{
		allocator::free(self.adapter.archive.allocator, self.bit_buf);
		allocator::free(self.adapter.archive.allocator, self.inflater);
		self.inflater = null;
		self.bit_buf = null;
	}
	return;
}

fn char? ZipEntryReader.read_byte(&self) @dynamic
{
	char[1] b;
	usz n = self.read(&b)!;
	if (n == 0) return io::EOF~;
	return b[0];
}

fn usz ZipEntryReader.len(&self) @dynamic
{
	return (usz)self.size;
}

fn usz? ZipEntryReader.available(&self) @dynamic
{
	return (usz)(self.size - self.pos);
}

fn usz? ZipEntryReader.seek(&self, isz offset, Seek seek) @dynamic
{
	if (self.method == DEFLATE) return io::UNSUPPORTED_OPERATION~;

	ulong new_pos = self.pos;
	switch (seek)
	{
		case SET:
			new_pos = (ulong)offset;
		case CURSOR:
			new_pos = (ulong)((isz)new_pos + offset);
		case END:
			new_pos = (ulong)((isz)self.size + offset);
	}
	if (new_pos > self.size) new_pos = self.size;
	self.pos = new_pos;
	self.adapter.pos = new_pos;
	return (usz)self.pos;
}

<*
 Opens a reader for an entry.
 @param filename : `The name of the file to read.`
 @return `A reader for the entry's data.`
*>
fn ZipEntryReader? ZipArchive.open_reader(&self, String filename)
{
	ZipEntry? entry = self.stat(filename);
	if (catch entry) return ENTRY_NOT_FOUND~;

	if (entry.is_encrypted) return ENCRYPTED_FILE~;

	self.file.flush()!;
	self.file.seek((isz)entry.offset, SET)!;
	ZipLFH lfh;
	self.file.read(((char*)&lfh)[:ZipLFH.sizeof])!;
	if (lfh.signature != ZIP_LFH_SIG) return CORRUPTED_DATA~;

	ZipEntryReader reader;

	reader.adapter.archive = (ZipArchive*)self;
	reader.adapter.start_offset = entry.offset + ZipLFH.sizeof + lfh.filename_len + lfh.extra_field_len;
	// For STORE: adapter.size is uncompressed size.
	// For DEFLATE: adapter.size is compressed size.
	reader.adapter.size = entry.method == STORE
		? entry.uncompressed_size
		: (entry.compressed_size == 0xFFFFFFFF ? 0xFFFFFFFFFFFFFFFF : entry.compressed_size);

	reader.size = entry.uncompressed_size;
	reader.method = entry.method;

	return reader;
}

struct ZipEntryWriter (OutStream)
{
	ZipArchive* archive;
	ZipEntry entry;
	Crc32 crc;
	ZipLFH lfh;
	ulong lfh_offset;
	char[] buffer;
	usz capacity;
}

fn usz? ZipEntryWriter.write(&self, char[] bytes) @dynamic
{
	if (bytes.len == 0) return 0;

	self.crc.update(bytes);
	self.entry.uncompressed_size += bytes.len;

	if (self.entry.method == STORE)
	{
		usz n = self.archive.file.write(bytes)!;
		self.entry.compressed_size += n;
		return n;
	}
	else
	{
		usz new_len = self.buffer.len + bytes.len;
		if (new_len > self.capacity)
		{
			usz cap2 = self.capacity * 2;
			usz new_cap = cap2 > new_len ? cap2 : new_len;
			if (new_cap < 4096) new_cap = 4096;

			char* p = allocator::realloc_array(self.archive.allocator, self.buffer.ptr, char, new_cap);
			self.buffer = p[:self.buffer.len]; // Keep length as used size
			self.capacity = new_cap;
		}

		mem::copy(self.buffer.ptr + self.buffer.len, bytes.ptr, bytes.len);
		// Update slice length
		self.buffer = self.buffer.ptr[:new_len];
		return bytes.len;
	}
}

fn void? ZipEntryWriter.write_byte(&self, char c) @dynamic
{
	char[1] b = { c };
	self.write(&b)!;
}

fn void? ZipEntryWriter.close(&self) @dynamic
{
	if (self.entry.method == DEFLATE)
	{
		if (self.buffer.len > 0)
		{
			char[]? data = deflate::compress(self.buffer, self.archive.allocator);
			if (catch data) return IO_ERROR~;
			self.archive.file.write(data)!;
			self.entry.compressed_size = data.len;

			allocator::free(self.archive.allocator, data);
			allocator::free(self.archive.allocator, self.buffer);
			self.buffer = {};
		}
	}

	self.entry.crc32 = ~self.crc.result;

	self.lfh.crc32 = self.entry.crc32;
	self.lfh.compressed_size = (uint)self.entry.compressed_size;
	self.lfh.uncompressed_size = (uint)self.entry.uncompressed_size;

	ulong end_pos = self.archive.file.seek(0, CURSOR)!;

	self.archive.file.seek((isz)self.lfh_offset, SET)!;
	io::write_any(self.archive.file, &self.lfh)!;

	self.archive.file.seek((isz)end_pos, SET)!;

	self.archive.entries.push(self.entry);
}

<*
 Opens a writer for a new entry.
 @param filename : `The name of the file to create in the archive.`
 @param method : `Compression method.`
 @return `A writer for the new entry.`
*>
fn ZipEntryWriter? ZipArchive.open_writer(&self, String filename, ZipMethod method = DEFLATE)
{
	if (!self.mode.starts_with("w")) return IO_ERROR~;

	ZipEntryWriter writer;
	writer.archive = self;
	writer.entry.name = filename.copy(self.allocator);
	defer catch allocator::free(self.allocator, writer.entry.name);

	writer.entry.method = method;
	writer.entry.offset = self.file.seek(0, CURSOR)!;
	writer.crc.init();
	writer.lfh_offset = writer.entry.offset;

	writer.lfh.signature = ZIP_LFH_SIG;
	writer.lfh.version_needed = 20;
	writer.lfh.method = method;
	writer.lfh.flags = 0x0800; // UTF-8 flag
	writer.lfh.filename_len = (ushort)filename.len;

	Time now = time::now();
	writer.lfh.last_mod_time = time_to_dos_time(now);
	writer.lfh.last_mod_date = time_to_dos_date(now);

	io::write_any(self.file, &writer.lfh)!;
	self.file.write(filename)!;

	return writer;
}

// -----------------------------------------------------------------------------
// PRIVATE IMPLEMENTATION
// -----------------------------------------------------------------------------

struct ArchiveStreamAdapter (InStream) @private
{
	ZipArchive* archive;
	ulong start_offset;
	ulong size;
	ulong pos;
}

fn usz? ArchiveStreamAdapter.read(&self, char[] buffer) @dynamic
{
	if (self.pos >= self.size) return 0;

	usz to_read = (usz)math::min((ulong)buffer.len, self.size - self.pos);
	if (to_read == 0) return 0;

	// Note: ZipArchive shared file handle access is not thread-safe.
	self.archive.file.seek((isz)(self.start_offset + self.pos), SET)!;
	usz n = self.archive.file.read(buffer[:to_read])!;
	self.pos += n;
	return n;
}

fn char? ArchiveStreamAdapter.read_byte(&self) @dynamic
{
	char[1] b;
	if (try n = self.read(b[..]))
	{
		if (n == 0) return io::EOF~;
		return b[0];
	}
	return io::EOF~;
}

struct ZipLFH @packed @private
{
	uint signature;
	ushort version_needed;
	ushort flags;
	ZipMethod method;
	ushort last_mod_time;
	ushort last_mod_date;
	uint crc32;
	uint compressed_size;
	uint uncompressed_size;
	ushort filename_len;
	ushort extra_field_len;
}

struct ZipCDH @packed @private
{
	uint signature;
	ushort version_made_by;
	ushort version_needed;
	ushort flags;
	ZipMethod method;
	ushort last_mod_time;
	ushort last_mod_date;
	uint crc32;
	uint compressed_size;
	uint uncompressed_size;
	ushort filename_len;
	ushort extra_field_len;
	ushort comment_len;
	ushort disk_number_start;
	ushort internal_attr;
	uint external_attr;
	uint relative_offset;
}

struct ZipEOCD @packed @private
{
	uint signature;
	ushort disk_number;
	ushort cd_disk_number;
	ushort num_entries_this_disk;
	ushort num_entries;
	uint cd_size;
	uint cd_offset;
	ushort comment_len;
}

const uint ZIP_LFH_SIG @private = 0x04034B50;
const uint ZIP_CDH_SIG @private = 0x02014B50;
const uint ZIP_EOCD_SIG @private = 0x06054B50;
const uint ZIP64_EOCD_SIG @private = 0x06064B50;
const uint ZIP64_LOCATOR_SIG @private = 0x07064B50;

const ushort ZIP64_EXTRA_ID @private = 0x0001;

struct Zip64EOCD @packed @private
{
	uint signature;
	ulong size; // Size of remaining record
	ushort version_made;
	ushort version_needed;
	uint disk_num;
	uint disk_start;
	ulong count_this_disk;
	ulong count_total;
	ulong size_cd;
	ulong offset_cd;
	// char[] custom_data;
}

struct Zip64Locator @packed @private
{
	uint signature;
	uint disk_start;
	ulong offset_eocd;
	uint total_disks;
}

struct Zip64ExtraField @private
{
	ushort header_id;
	ushort size;
	ulong uncompressed_size;
	ulong compressed_size;
	ulong offset;
	uint disk_start;
}

fn ushort time_to_dos_time(Time t) @private
{
	long seconds = (long)t / 1_000_000;
	int s = (int)(seconds % 60);
	int m = (int)((seconds / 60) % 60);
	int h = (int)((seconds / 3600) % 24);
	return (ushort)((h << 11) | (m << 5) | (s / 2));
}

fn ushort time_to_dos_date(Time t) @private
{
	long seconds = (long)t / 1_000_000;
	long days = seconds / 86400;

	if (days < 3652) return (ushort)((0 << 9) | (1 << 5) | 1); // 1980-01-01

	days -= 3652;
	int year = 0;
	while (true)
	{
		int y = 1980 + year;
		bool is_leap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
		int year_days = is_leap ? 366 : 365;
		if (days < (long)year_days) break;
		days -= (long)year_days;
		year++;
	}

	int[12] month_days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
	int y = 1980 + year;
	if ((y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)) month_days[1] = 29;

	int month = 0;
	while (days >= (long)month_days[month])
	{
		days -= (long)month_days[month];
		month++;
	}

	int day = (int)days + 1;
	month++;
	return (ushort)((year << 9) | (month << 5) | day);
}

fn Time dos_date_time_to_time(ushort dos_date, ushort dos_time) @private
{
	int sec = (int)((dos_time & 0x1F) * 2);
	int min = (int)((dos_time >> 5) & 0x3F);
	int hour = (int)((dos_time >> 11) & 0x1F);

	int day = (int)(dos_date & 0x1F);
	int month = (int)((dos_date >> 5) & 0xF);
	int year = (int)((dos_date >> 9) & 0x7F) + 1980;

	if (day == 0) day = 1;
	if (month == 0) month = 1;
	if (month > 12) month = 12;

	// 1970 to 1980 is 3652 days
	long total_days = 3652;

	for (int y = 1980; y < year; y++)
	{
		bool is_leap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
		total_days += is_leap ? 366 : 365;
	}

	bool is_leap_year = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
	int[12] mdays = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
	if (is_leap_year) mdays[1] = 29;

	for (int i = 0; i < month - 1; i++)
	{
		total_days += mdays[i];
	}

	total_days += (long)(day - 1);

	long total_seconds = total_days * 86400;
	total_seconds += (long)(hour * 3600);
	total_seconds += (long)(min * 60);
	total_seconds += (long)sec;

	return (Time)(total_seconds * 1_000_000);
}

fn bool is_valid_utf8(char[] bytes) @private
{
	usz i = 0;
	while (i < bytes.len)
	{
		char lead = bytes[i];
		switch (lead)
		{
			case 0x00..0x7F:
				i++;
			case 0xC2..0xDF:
				if (i + 1 >= bytes.len || (bytes[i + 1] & 0xC0) != 0x80) return false;
				i += 2;
			case 0xE0..0xEF:
				if (i + 2 >= bytes.len) return false;
				char b1 = bytes[i + 1];
				char b2 = bytes[i + 2];
				if ((b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80) return false;
				if (lead == 0xE0 && b1 < 0xA0) return false;
				if (lead == 0xED && b1 >= 0xA0) return false;
				i += 3;
			case 0xF0..0xF4:
				if (i + 3 >= bytes.len) return false;
				char b1 = bytes[i + 1];
				char b2 = bytes[i + 2];
				char b3 = bytes[i + 3];
				if ((b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80) return false;
				if (lead == 0xF0 && b1 < 0x90) return false;
				if (lead == 0xF4 && b1 >= 0x90) return false;
				i += 4;
			default:
				return false;
		}
	}
	return true;
}
