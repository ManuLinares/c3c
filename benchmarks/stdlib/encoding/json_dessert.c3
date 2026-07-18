// temp benchmark
// c3c compile-run -O3 benchmarks/stdlib/encoding/json_dessert.c3 --lib dessert

module bench;
import std;
import dessert;
import json;
import derive;

$expand(derive(Address::name, dessert));
struct Address
{
	String street;
	String city;
	int zip;
}

$expand(derive(Record::name, dessert));
struct Record
{
	int id;
	String name;
	String email;
	bool active;
	double balance;
	int[] scores;
	Address address;
}

// Number of records serialized/deserialized in a single payload.
const usz RECORD_COUNT = 2000;

<*
 Builds a deterministic slice of `RECORD_COUNT` records in `allocator`.
*>
fn Record[] make_records(Allocator allocator)
{
	Record[] records = alloc::new_array(allocator, Record, RECORD_COUNT);
	for (usz i = 0; i < RECORD_COUNT; i++)
	{
		int[] scores = alloc::new_array(allocator, int, 5);
		for (usz j = 0; j < 5; j++) scores[j] = (int)((i * 7 + j * 13) % 100);
		records[i] = {
			.id = (int)i,
			.name = string::format(allocator, "user_%d", i),
			.email = string::format(allocator, "user_%d@example.com", i),
			.active = (i & 1) == 0,
			.balance = (double)i * 1.5,
			.scores = scores,
			.address = {
				.street = string::format(allocator, "%d Main Street", i),
				.city = "Springfield",
				.zip = (int)(10000 + i),
			},
		};
	}
	return records;
}

<*
 Serializes `records` to a JSON string in `allocator`.
*>
fn String serialize_records(Record[] records, Allocator allocator)
{
	JsonStringSerializer s = json::string_serializer(allocator);
	return ser::serialize(&s, records)!!;
}


// Reports MB/s for serialization and deserialization of a RECORD_COUNT-sized
// JSON payload, plus the payload size and records/s.

usz iterations = 500;

fn void bench_serialize_throughput(String encoded)
{
	@pool()
	{
		Record[] records  = make_records(tmem);
		// Size of a single encoded payload, used to derive throughput in bytes.
		usz payload_bytes = encoded.len;

		Clock start = clock::now();
		usz total_bytes;
		for (usz i = 0; i < iterations; i++)
		{
			@pool()
			{
				total_bytes += format::json::tstring_serialize(records)!!.len;
			};
		}
		NanoDuration elapsed = start.mark();
		report("serialize", elapsed, total_bytes, payload_bytes);
	};
}

fn void bench_stdjson_serialize_throughput(String encoded)
{
	@pool()
	{
		Record[] records  = make_records(tmem);
		// Size of a single encoded payload, used to derive throughput in bytes.
		usz payload_bytes = encoded.len;

		Clock start = clock::now();
		usz total_bytes;
		for (usz i = 0; i < iterations; i++)
		{
			@pool()
			{
				// foreach (record : records)
				// {
					//total_bytes += encoding::json::marshal(tmem, record).len;
					total_bytes += encoding::json::marshal(tmem, records)!!.len;
				// }
			};
		}
		NanoDuration elapsed = start.mark();
		report("serialize (std::json)", elapsed, total_bytes, payload_bytes);
	};
}

fn void bench_deserialize_throughput(String encoded)
{
	@pool()
	{
		usz payload_bytes = encoded.len;

		Clock start = clock::now();
		usz total_bytes;
		for (usz i = 0; i < iterations; i++)
		{
			@pool()
			{
				Record[] decoded = format::json::deserialize{Record[]}(mem, encoded)!!;
				total_bytes += encoded.len;
			};
		}
		NanoDuration elapsed = start.mark();
		report("deserialize", elapsed, total_bytes, payload_bytes);
	};
}

fn void bench_stdjson_deserialize_throughput(String encoded)
{
	@pool()
	{
		usz payload_bytes = encoded.len;

		Clock start = clock::now();
		usz total_bytes;
		for (usz i = 0; i < iterations; i++)
		{
			@pool()
			{
				// Changed from parsing into Object* to unmarshalling into typed Record[]
				Record[] decoded = encoding::json::unmarshal(mem, encoded, Record[])!!;
				total_bytes += encoded.len;
			};
		}
		NanoDuration elapsed = start.mark();
		report("deserialize (std::json) ", elapsed, total_bytes, payload_bytes);
	};
}

fn void report(String label, NanoDuration elapsed, usz total_bytes, usz payload_bytes)
{
	double seconds = (double)elapsed / 1_000_000_000.0;
	double mb      = (double)total_bytes / (1024.0 * 1024.0);
	double records = (double)(iterations * RECORD_COUNT);
	io::printfn("%-25s | payload %6d B | %5d iters | %7.2f MB in %6.3f s | %8.2f MB/s | %10.0f records/s", label, payload_bytes, iterations, mb, seconds, mb / seconds, records / seconds);
}

fn int main(String[] args)
{
	if (args.len > 1)
	{
		if (try n = args[1].to_ulong()) iterations = (usz)n;
	}
	Record[] records = make_records(tmem);
	String encoded   = serialize_records(records, tmem);

	io::printfn("dessert throughput benchmark (%d records/payload, %d iters)", RECORD_COUNT, iterations);
	bench_serialize_throughput(encoded);
	bench_stdjson_serialize_throughput(encoded);

	bench_deserialize_throughput(encoded);

	bench_stdjson_deserialize_throughput(encoded);
	return 0;
}
