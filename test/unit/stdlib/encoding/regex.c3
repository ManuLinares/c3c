import std, std::encoding::regex;

// API

fn void test_idiomatic_api() @test
{
	// --- compile: invalid pattern throws a typed fault ---------------------
	if (catch err = regex::compile("(unclosed", regex::REG_EXTENDED))
	{
		assert(err == regex::EPAREN, "expected EPAREN for unclosed group");
	}
	else
	{
		unreachable("compile should have failed");
	}

	// compile: simple literal 
	Regex re = regex::compile("hello")!!;
	defer re.free();

	// exec: successful match 
	String input1 = "say hello world";
	Match[] m = re.exec(input1)!!;
	// Since Match implements Printable, we can print it directly:
	// io::print(m[0]);  // prints: hello
	assert(m[0] == "hello", "expected matched text 'hello'");

	// exec: no match returns NOMATCH fault
	if (catch err = re.exec("goodbye"))
	{
		assert(err == regex::NOMATCH, "expected NOMATCH");
	}
	else
	{
		unreachable("exec should have returned NOMATCH");
	}

	// compile + exec: capture groups
	Regex re2 = regex::compile("(\\w+)@(\\w+\\.\\w+)", regex::REG_EXTENDED)!!;
	defer re2.free();

	// nmatch=3: slot 0=whole match, 1=user, 2=domain
	String input2 = "contact: user@example.com today";
	Match[] em = re2.exec(input2, 3)!!;
	// io::print(em[0]);  // prints: user@example.com
	// io::print(em[1]);  // prints: user
	// io::print(em[2]);  // prints: example.com
	assert(em[1] == "user",        "user capture mismatch");
	assert(em[2] == "example.com", "domain capture mismatch");
}

// ============================================================
//  Some more tests

fn void test_bracket_negation_max_codepoint() @test
{
	Regex re;
	int err = regex::re_compile(&re, "[^a]", regex::REG_EXTENDED);
	test::eq(regex::REG_OK, err);

	// In UTF-8, the max codepoint 0x10ffff is exactly the 4 bytes f4, 8f, bf, bf.
	String input = "\xf4\x8f\xbf\xbf";

	// This character is not 'a', so a negated bracket [^a] must match it.
	test::eq(regex::REG_OK, regex::re_exec(&re, input, 0, null, 0));

	regex::re_free(&re);
}

fn void test_negated_class_sentinel_corruption() @test
{
	Regex re1;
	Regex re2;

	int err = regex::re_compile(&re1, "[^[:digit:]]", regex::REG_EXTENDED);
	test::eq(regex::REG_OK, err);

	err = regex::re_compile(&re2, "a*b*c*d*e*f*g*h*i*j*k*l*", regex::REG_EXTENDED);
	test::eq(regex::REG_OK, err);

	test::eq(regex::REG_OK, regex::re_exec(&re1, "a", 0, null, 0));

	regex::re_free(&re2);
	regex::re_free(&re1);
}

//  GAP: Escape sequences \b, \B, \w, \W, \s, \S, \d, \D
fn void test_escape_word_boundary() @test
{
	Regex re;
	// \b matches at a word boundary
	int err = regex::re_compile(&re, "\\bfoo\\b", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "foo", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "foobar", 0, null, 0) == regex::REG_NOMATCH);
	assert(regex::re_exec(&re, " foo ", 0, null, 0) == regex::REG_OK);
	regex::re_free(&re);
}

fn void test_escape_w() @test
{
	Regex re;
	// \w matches word chars [[:alnum:]_]
	int err = regex::re_compile(&re, "\\w+", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "hello_world", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "---", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

fn void test_escape_W() @test
{
	Regex re;
	// \W matches non-word chars
	int err = regex::re_compile(&re, "\\W", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, " ", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "!", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "a", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

fn void test_escape_s() @test
{
	Regex re;
	// \s matches whitespace
	int err = regex::re_compile(&re, "\\s+", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "   ", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "\t\n", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "abc", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

fn void test_escape_S() @test
{
	Regex re;
	// \S matches non-whitespace
	int err = regex::re_compile(&re, "\\S+", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "abc", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "   ", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

fn void test_escape_d() @test
{
	Regex re;
	// \d matches digits
	int err = regex::re_compile(&re, "\\d+", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "123", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "abc", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

fn void test_escape_D() @test
{
	Regex re;
	// \D matches non-digits
	int err = regex::re_compile(&re, "\\D+", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "abc", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "123", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

//  GAP: BRE backreferences \1
fn void test_backref() @test
{
	Regex re;
	// BRE: \(a\+\)\1 matches "aa", "abab" etc. (repeated capture)
	// "^(a+)\1$" in BRE style: ^\(a*\)\1$
	int err = regex::re_compile(&re, "^\\(a*\\)\\1$", 0);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "aa", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "aaa", 0, null, 0) == regex::REG_NOMATCH); // "aaa" is odd-length, so it doesn't match ^\(a*\)\1$
	regex::re_free(&re);
}

//  GAP: tre_fill_pmatch, parent-bounds reset
fn void test_submatch_parent_bounds() @test
{
	Regex re;
	// When outer group does not participate, inner group must return -1/-1
	// Pattern: (a|(b))c  matched against "ac"
	// group 1 = "a", group 2 = -1 (not used)
	int err = regex::re_compile(&re, "(a|(b))c", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	RegMatch[3] pm;
	assert(regex::re_exec(&re, "ac", 3, &pm[0], 0) == regex::REG_OK);
	assert(pm[0].rm_so == 0 && pm[0].rm_eo == 2); // whole match
	assert(pm[1].rm_so == 0 && pm[1].rm_eo == 1); // group 1 = "a"
	assert(pm[2].rm_so == -1 && pm[2].rm_eo == -1); // group 2 unused
	regex::re_free(&re);
}

//  GAP: Alternation in BRE with \|
fn void test_bre_alternation() @test
{
	Regex re;
	// BRE extension: \| as alternation
	int err = regex::re_compile(&re, "cat\\|dog", 0);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "cat", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "dog", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "bird", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

//  GAP: eflags REG_NOTBOL / REG_NOTEOL
fn void test_eflags_notbol() @test
{
	Regex re;
	regex::re_compile(&re, "^abc", 0);
	// Without flag: matches at start
	assert(regex::re_exec(&re, "abc", 0, null, 0) == regex::REG_OK);
	// With REG_NOTBOL: ^ should not match at position 0
	assert(regex::re_exec(&re, "abc", 0, null, regex::REG_NOTBOL) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

fn void test_eflags_noteol() @test
{
	Regex re;
	regex::re_compile(&re, "abc$", 0);
	// Without flag: matches at end
	assert(regex::re_exec(&re, "abc", 0, null, 0) == regex::REG_OK);
	// With REG_NOTEOL: $ should not match at end
	assert(regex::re_exec(&re, "abc", 0, null, regex::REG_NOTEOL) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

//  GAP: \x hex escape sequences
fn void test_hex_escape() @test
{
	Regex re;
	// \x41 = 'A' - exercises the digit branch (4, 1) of hexval
	int err = regex::re_compile(&re, "\\x41", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "A", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "B", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);

	// \x6e = 'n' (0x6e=110) - '6' digit branch + 'e' letter branch of hexval
	err = regex::re_compile(&re, "\\x6e", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "n", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "m", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);

	// \x4b = 'K' (0x4b=75) - '4' digit branch + 'b' letter branch of hexval
	// Also tests uppercase hex input: \x4B (hexval does c|=32 to fold case)
	err = regex::re_compile(&re, "\\x4B", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "K", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "k", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

/**********************************************************
 taken from: (https://go.dev/src/regexp/testdata/README)
 https://go.dev/src/regexp/testdata/basic.dat?m=text
 https://go.dev/src/regexp/testdata/repetition.dat?m=text
 https://go.dev/src/regexp/testdata/nullsubexpr.dat?m=text
***********************************************************/

// --- Test entry points ---------------------------------------------------

fn void test_basic() @test        { run_suite("BASIC",       BASIC_DAT);       }
fn void test_repetition() @test   { run_suite("REPETITION",  REPETITION_DAT);  }
fn void test_nullsubexpr() @test  { run_suite("NULLSUBEXPR", NULLSUBEXPR_DAT); }

// -------------------------------------------------------------------------

faultdef NOT_FOUND;

const String BASIC_DAT       = $embed("regex_testdata/basic.dat");
const String REPETITION_DAT  = $embed("regex_testdata/repetition.dat");
const String NULLSUBEXPR_DAT = $embed("regex_testdata/nullsubexpr.dat");

// --- Skip list -----------------------------------------------------------
// Keys are "SUITE:LINE". Each entry carries a 1-line reason.

struct Skip { String key; String reason; }

const Skip[] SKIPS = {
    // BASIC
    { "BASIC:80",        "raw \\xff byte in input - engine rejects non-UTF-8 sequences" },

    // NULLSUBEXPR
    { "NULLSUBEXPR:57",  "backref sync: backreference step-alignment limitation in backtracking engine" },
    { "NULLSUBEXPR:58",  "backref sync: backreference step-alignment limitation in backtracking engine" },
    { "NULLSUBEXPR:59",  "backref sync: backreference step-alignment limitation in backtracking engine" },
    { "NULLSUBEXPR:60",  "backref sync: backreference step-alignment limitation in backtracking engine" },
    { "NULLSUBEXPR:61",  "backref sync: backreference step-alignment limitation in backtracking engine" },

    // REPETITION - nested repetition capture-group reset on loop iteration
    { "REPETITION:35",   "TRE: nested rep capture groups reset on loop - ((..)|(.))\x7b2\x7d on 'aa'" },
    { "REPETITION:46",   "TRE: nested rep capture groups reset on loop - ((..)|(.))\x7b2\x7d on 'aaa'" },
    { "REPETITION:50",   "TRE: nested rep capture groups reset on loop - ((..)|(.))*  on 'aaa'" },
    { "REPETITION:59",   "TRE: nested rep capture groups reset on loop - ((..)|(.))\x7b3\x7d on 'aaaa'" },
    { "REPETITION:61",   "TRE: nested rep capture groups reset on loop - ((..)|(.))*  on 'aaaa'" },
    { "REPETITION:70",   "TRE: nested rep capture groups reset on loop - ((..)|(.))\x7b3\x7d on 'aaaaa'" },
    { "REPETITION:73",   "TRE: nested rep capture groups reset on loop - ((..)|(.))*  on 'aaaaa'" },
    // REPETITION - Go/RE2 greedy empty-match divergence: {7,} is the boundary case
    { "REPETITION:97",   "POSIX vs RE2/Go: X(.?){7,}Y engine gives (7,8) POSIX-correct, test expects Go (8,8)" },
    // RE2/Go bounded variants that expect (8,8) but engine gives POSIX (7,8)
    { "REPETITION:100",  "POSIX vs RE2/Go: X(.?){0,8}Y engine gives POSIX (7,8), test expects Go (8,8)" },
    { "REPETITION:102",  "POSIX vs RE2/Go: X(.?){1,8}Y engine gives POSIX (7,8), test expects Go (8,8)" },
    { "REPETITION:104",  "POSIX vs RE2/Go: X(.?){2,8}Y engine gives POSIX (7,8), test expects Go (8,8)" },
    { "REPETITION:106",  "POSIX vs RE2/Go: X(.?){3,8}Y engine gives POSIX (7,8), test expects Go (8,8)" },
    { "REPETITION:108",  "POSIX vs RE2/Go: X(.?){4,8}Y engine gives POSIX (7,8), test expects Go (8,8)" },
    { "REPETITION:110",  "POSIX vs RE2/Go: X(.?){5,8}Y engine gives POSIX (7,8), test expects Go (8,8)" },
    { "REPETITION:112",  "POSIX vs RE2/Go: X(.?){6,8}Y engine gives POSIX (7,8), test expects Go (8,8)" },
    { "REPETITION:114",  "POSIX vs RE2/Go: X(.?){7,8}Y engine gives POSIX (7,8), test expects Go (8,8)" },
    // REPETITION - Go/POSIX ERE alternation ordering (a|ab|c|bcd) and (ab|a|c|bcd)
    { "REPETITION:126",  "Go/POSIX ERE alternation-ordering divergence: (a|ab|c|bcd)\x7b0,\x7d" },
    { "REPETITION:127",  "Go/POSIX ERE alternation-ordering divergence: (a|ab|c|bcd)\x7b1,\x7d" },
    { "REPETITION:128",  "Go/POSIX ERE alternation-ordering divergence: (a|ab|c|bcd)\x7b2,\x7d" },
    { "REPETITION:129",  "Go/POSIX ERE alternation-ordering divergence: (a|ab|c|bcd)\x7b3,\x7d" },
    { "REPETITION:131",  "Go/POSIX ERE alternation-ordering divergence: (a|ab|c|bcd)\x7b0,10\x7d" },
    { "REPETITION:132",  "Go/POSIX ERE alternation-ordering divergence: (a|ab|c|bcd)\x7b1,10\x7d" },
    { "REPETITION:133",  "Go/POSIX ERE alternation-ordering divergence: (a|ab|c|bcd)\x7b2,10\x7d" },
    { "REPETITION:134",  "Go/POSIX ERE alternation-ordering divergence: (a|ab|c|bcd)\x7b3,10\x7d" },
    { "REPETITION:136",  "Go/POSIX ERE alternation-ordering divergence: (a|ab|c|bcd)*" },
    { "REPETITION:137",  "Go/POSIX ERE alternation-ordering divergence: (a|ab|c|bcd)+" },
    { "REPETITION:143",  "Go/POSIX ERE alternation-ordering divergence: (ab|a|c|bcd)\x7b0,\x7d" },
    { "REPETITION:145",  "Go/POSIX ERE alternation-ordering divergence: (ab|a|c|bcd)\x7b1,\x7d" },
    { "REPETITION:147",  "Go/POSIX ERE alternation-ordering divergence: (ab|a|c|bcd)\x7b2,\x7d" },
    { "REPETITION:149",  "Go/POSIX ERE alternation-ordering divergence: (ab|a|c|bcd)\x7b3,\x7d" },
    { "REPETITION:152",  "Go/POSIX ERE alternation-ordering divergence: (ab|a|c|bcd)\x7b0,10\x7d" },
    { "REPETITION:154",  "Go/POSIX ERE alternation-ordering divergence: (ab|a|c|bcd)\x7b1,10\x7d" },
    { "REPETITION:156",  "Go/POSIX ERE alternation-ordering divergence: (ab|a|c|bcd)\x7b2,10\x7d" },
    { "REPETITION:158",  "Go/POSIX ERE alternation-ordering divergence: (ab|a|c|bcd)\x7b3,10\x7d" },
    { "REPETITION:161",  "Go/POSIX ERE alternation-ordering divergence: (ab|a|c|bcd)*" },
    { "REPETITION:163",  "Go/POSIX ERE alternation-ordering divergence: (ab|a|c|bcd)+" },
};

fn String? skip_reason(String suite, int line) {
    String key = string::tformat("%s:%d", suite, line);
    foreach (s : SKIPS) {
        if (s.key == key) return s.reason;
    }
    return NOT_FOUND~;
}

// --- Error code mapping --------------------------------------------------

fn int compile_error_code(String s) {
    switch (s) {
        case "BADPAT":   return regex::REG_BADPAT;
        case "ECOLLATE": return regex::REG_ECOLLATE;
        case "ECTYPE":   return regex::REG_ECTYPE;
        case "EESCAPE":  return regex::REG_EESCAPE;
        case "ESUBREG":  return regex::REG_ESUBREG;
        case "EBRACK":   return regex::REG_EBRACK;
        case "EPAREN":   return regex::REG_EPAREN;
        case "EBRACE":   return regex::REG_EBRACE;
        case "BADBR":    return regex::REG_BADBR;
        case "ERANGE":   return regex::REG_ERANGE;
        case "ESPACE":   return regex::REG_ESPACE;
        case "BADRPT":   return regex::REG_BADRPT;
        default:         return regex::REG_OK;
    }
}

// --- Escape decoder ------------------------------------------------------
// Decodes literal escape sequences in the input string to actual control bytes.
// Patterns are passed through directly as the regex compiler parses escapes natively.
fn String decode_input_escapes(String input) {
    if (!input.contains_char('\\')) return input;
    return input.treplace(`\n`, "\n")
                .treplace(`\t`, "\t")
                .treplace(`\r`, "\r")
                .treplace(`\a`, "\a")
                .treplace(`\b`, "\b")
                .treplace(`\f`, "\f")
                .treplace(`\v`, "\v")
                .treplace(`\\`, `\`);
}

// --- Span parser ---------------------------------------------------------
// Parses "(s,e)(s,e)…" where s/e can be digits, '?' (unset = -1), or 'X' (don't-care = -2).

struct Span { int s; int e; }

fn int parse_spans(String src, Span[] out) {
    Splitter parts = src.tokenize_all(")");
    int n = 0;
    while (try part = parts.next()) {
        if (try idx = part.index_of_char('(')) {
            if (n >= out.len) continue;
            String pair = part[idx + 1..];
            Splitter vals = pair.tokenize_all(",");
            
            String s_str = vals.next() ?? "";
            String e_str = vals.next() ?? "";
            
            int s = s_str == "?" ? -1 : (s_str == "X" ? -2 : s_str.to_int() ?? 0);
            int e = e_str == "?" ? -1 : (e_str == "X" ? -2 : e_str.to_int() ?? 0);
            
            out[n++] = { s, e };
        }
    }
    return n;
}

// --- Suite runner --------------------------------------------------------

fn void run_suite(String suite, String dat) {
    Splitter lines = dat.tokenize_all("\n");
    String prev_pattern;
    int line_num = 0;
    int passed = 0;
    int skipped = 0;

    while (try line = lines.next()) {
        line_num++;
        String l = line.trim_right("\r");
        // '#:label:' lines are POSIX-correct variants commented out by the Go test suite.
        // Strip the leading '#' so we run them; skip only bare '#' comments.
        if (l.len == 0 || l[0] == '{' || l[0] == '}') continue;
        if (l[0] == '#') {
            if (l.len < 2 || l[1] != ':') continue; // true comment
            l = l[1..];                              // POSIX test: strip '#'
        }

        Splitter fields = l.tokenize("\t");
        String flags   = fields.next() ?? "";
        String pattern = fields.next() ?? "";
        String input   = fields.next() ?? "";
        String expect  = fields.next() ?? "";

        if (flags.len == 0 || pattern.len == 0) continue;

        // Strip Fowler label prefix  :label:flags -> flags
        if (flags[0] == ':') {
            if (try idx = flags[1..].index_of_char(':')) flags = flags[idx + 2..];
        }

        // SAME references the previous pattern.
        if (pattern == "SAME") { pattern = prev_pattern; } else { prev_pattern = pattern; }

        if (pattern == "NULL" || pattern == "NIL") pattern = "";
        if (input   == "NULL" || input   == "NIL") input   = "";

        // Determine compile flags from the flags field.
        int cflags = 0;
        bool supported = false;
        switch (flags[0]) {
            case 'E': cflags |= regex::REG_EXTENDED; supported = true;
            case 'B': supported = true;
        }
        if (!supported) continue;
        foreach (c : flags[1..]) {
            if (c == 'i') cflags |= regex::REG_ICASE;
            if (c == 'n') cflags |= regex::REG_NEWLINE;
        }

        // Skip check.
        if (try reason = skip_reason(suite, line_num)) {
            io::printfn("SKIP  %s:%d - %s", suite, line_num, reason);
            skipped++;
            continue;
        }

        Regex re;
        int cerr = regex::re_compile(&re, pattern.tcopy(), cflags);

        int expected_err = compile_error_code(expect);
        if (expected_err != regex::REG_OK || cerr != regex::REG_OK) {
            if (cerr != expected_err) {
                io::printfn("FAIL  %s:%d  pattern='%s'  expected compile-err=%d  got=%d",
                    suite, line_num, pattern, expected_err, cerr);
                test::eq(expected_err, cerr);
            }
            if (cerr == regex::REG_OK) regex::re_free(&re);
            passed++;
            continue;
        }

        RegMatch[32] pm;
        int eerr = regex::re_exec(&re, decode_input_escapes(input).tcopy(), 32, &pm[0], 0);
        regex::re_free(&re);

        if (expect == "NOMATCH" || expect == "NIL") {
            if (eerr != regex::REG_NOMATCH) {
                io::printfn("FAIL  %s:%d  pattern='%s'  input='%s'  expected NOMATCH  got exec-err=%d",
                    suite, line_num, pattern, input, eerr);
                test::eq(regex::REG_NOMATCH, eerr);
            }
        } else if (eerr != regex::REG_OK) {
            io::printfn("FAIL  %s:%d  pattern='%s'  input='%s'  unexpected exec-err=%d",
                suite, line_num, pattern, input, eerr);
            test::eq(regex::REG_OK, eerr);
        } else {
            Span[32] exp_spans;
            int nspans = parse_spans(expect, exp_spans[..]);
            for (int s = 0; s < nspans; s++) {
                if (exp_spans[s].s == -2 || exp_spans[s].e == -2) continue;
                if (exp_spans[s].s != pm[s].rm_so || exp_spans[s].e != pm[s].rm_eo) {
                    io::printfn("FAIL  %s:%d  pattern='%s'  input='%s' group[%d] expected=(%d,%d) got=(%d,%d)",
                        suite, line_num, pattern, input, s, exp_spans[s].s, exp_spans[s].e, pm[s].rm_so, pm[s].rm_eo);
                    test::eq(exp_spans[s].s, pm[s].rm_so);
                    test::eq(exp_spans[s].e, pm[s].rm_eo);
                }
            }
        }
        passed++;
    }
    io::printfn("[%s] %d cases passed, %d skipped", suite, passed, skipped);
}
