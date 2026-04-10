module libc @if(env::ANDROID);

// Checked for x86_64, this is notoriously incorrect when comparing with Rust code etc

alias Blksize_t = CInt;
alias Nlink_t = CUInt;
alias Blkcnt_t = long;
alias Ino_t = ulong;
alias Dev_t = ulong;
alias Mode_t = uint;
alias Ino64_t = ulong;
alias Blkcnt64_t = long;

struct Stat @if(env::ARCH_64_BIT)
{
	Dev_t st_dev;
	Ino_t st_ino;
	Mode_t st_mode;
	Nlink_t st_nlink;
	Uid_t st_uid;
	Gid_t st_gid;
	Dev_t st_rdev;
	ulong __pad1;
	Off_t st_size;
	Blksize_t st_blksize;
	CInt __pad2;
	Blkcnt_t st_blocks;
	Time_t st_atim_sec;
	long st_atim_nsec;
	Time_t st_mtim_sec;
	long st_mtim_nsec;
	Time_t st_ctim_sec;
	long st_ctim_nsec;
	CUInt[2] __unused;
}

struct Stat @if(env::ARCH_32_BIT)
{
	Dev_t st_dev;
	Ino_t st_ino;
	Mode_t st_mode;
	Nlink_t st_nlink;
	Uid_t st_uid;
	Gid_t st_gid;
	Dev_t st_rdev;
	CInt __pad1;
	Off_t st_size;
	Blksize_t st_blksize;
	CInt __pad2;
	Blkcnt_t st_blocks;
	Time_t st_atime;
	long st_atime_nsec;
	Time_t st_mtime;
	long st_mtime_nsec;
	Time_t st_ctime;
	long st_ctime_nsec;
	CInt[2] __unused;
}

extern fn CInt stat(ZString path, Stat* stat);

extern fn CInt get_nprocs();
extern fn CInt get_nprocs_conf();
