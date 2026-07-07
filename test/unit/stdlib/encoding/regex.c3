module regex_test;
import std, std::encoding::regex;

// API

fn void test_idiomatic_api() @test
{
	// --- compile: invalid pattern throws a fault ---------------------
	if (catch err = regex::compile("(unclosed", regex::REG_EXTENDED))
	{
		test::eq(err, regex::EPAREN);
		test::eq(regex::error_string(err), "Missing ')'");
	}
	else
	{
		unreachable("compile should have failed with fault regex::EPAREN");
	}

	// compile: simple literal 
	Regex re = regex::compile("hello")!!;
	defer re.free();

	// exec: successful match 
	String input1 = "say hello world";
	Match[] m = re.exec(input1)!!;
	// Since Match implements Printable, we can print it directly:
	io::print(m[0]);  // prints: hello

	test::eq(string::tformat("%s", m[0]), "hello");

	// exec: no match returns NOMATCH fault
	if (catch err = re.exec("goodbye"))
	{
		test::eq(err, regex::NOMATCH);
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
	test::eq(em[0], "user@example.com");
	test::eq(em[1], "user");
	test::eq(em[2], "example.com");
}

// ============================================================
//  Some more tests

fn void test_bracket_negation_max_codepoint() @test
{
	Regex re = regex::compile("[^a]", regex::REG_EXTENDED)!!;
	defer re.free();

	// In UTF-8, the max codepoint 0x10ffff is exactly the 4 bytes f4, 8f, bf, bf.
	String input = "\xf4\x8f\xbf\xbf";

	// This character is not 'a', so a negated bracket [^a] must match it.
	test::@check(!@catch(re.exec(input)));
}

fn void test_negated_class_sentinel_corruption() @test
{
	Regex re1 = regex::compile("[^[:digit:]]", regex::REG_EXTENDED)!!;
	defer re1.free();

	Regex re2 = regex::compile("a*b*c*d*e*f*g*h*i*j*k*l*", regex::REG_EXTENDED)!!;
	defer re2.free();

	test::@check(!@catch(re1.exec("a")));
}

//  GAP: Escape sequences \b, \B, \w, \W, \s, \S, \d, \D
fn void test_escape_word_boundary() @test
{
	Regex re = regex::compile("\\bfoo\\b", regex::REG_EXTENDED)!!;
	defer re.free();

	test::@check(!@catch(re.exec("foo")));
	test::eq(@catch(re.exec("foobar")), regex::NOMATCH);
	test::@check(!@catch(re.exec(" foo ")));
}

fn void test_escape_w() @test
{
	Regex re = regex::compile("\\w+", regex::REG_EXTENDED)!!;
	defer re.free();

	test::@check(!@catch(re.exec("hello_world")));
	test::eq(@catch(re.exec("---")), regex::NOMATCH);
}

fn void test_escape_W() @test
{
	Regex re = regex::compile("\\W", regex::REG_EXTENDED)!!;
	defer re.free();

	test::@check(!@catch(re.exec(" ")));
	test::@check(!@catch(re.exec("!")));
	test::eq(@catch(re.exec("a")), regex::NOMATCH);
}

fn void test_escape_s() @test
{
	Regex re = regex::compile("\\s+", regex::REG_EXTENDED)!!;
	defer re.free();

	test::@check(!@catch(re.exec("   ")));
	test::@check(!@catch(re.exec("\t\n")));
	test::eq(@catch(re.exec("abc")), regex::NOMATCH);
}

fn void test_escape_S() @test
{
	Regex re = regex::compile("\\S+", regex::REG_EXTENDED)!!;
	defer re.free();

	test::@check(!@catch(re.exec("abc")));
	test::eq(@catch(re.exec("   ")), regex::NOMATCH);
}

fn void test_escape_d() @test
{
	Regex re = regex::compile("\\d+", regex::REG_EXTENDED)!!;
	defer re.free();

	test::@check(!@catch(re.exec("123")));
	test::eq(@catch(re.exec("abc")), regex::NOMATCH);
}

fn void test_escape_D() @test
{
	Regex re = regex::compile("\\D+", regex::REG_EXTENDED)!!;
	defer re.free();

	test::@check(!@catch(re.exec("abc")));
	test::eq(@catch(re.exec("123")), regex::NOMATCH);
}

//  GAP: BRE backreferences \1
fn void test_backref() @test
{
	Regex re = regex::compile("^\\(a*\\)\\1$", 0)!!;
	defer re.free();

	test::@check(!@catch(re.exec("aa")));
	test::eq(@catch(re.exec("aaa")), regex::NOMATCH); // "aaa" is odd-length, so it doesn't match ^\(a*\)\1$
}

//  GAP: tre_fill_pmatch, parent-bounds reset
fn void test_submatch_parent_bounds() @test
{
	// When outer group does not participate, inner group must return -1/-1
	// Pattern: (a|(b))c  matched against "ac"
	// group 1 = "a", group 2 = -1 (not used)
	Regex re = regex::compile("(a|(b))c", regex::REG_EXTENDED)!!;
	defer re.free();

	Match[] m = re.exec("ac", 3)!!;
	test::eq(m[0].match.rm_so, 0);
	test::eq(m[0].match.rm_eo, 2); // whole match
	test::eq(m[1].match.rm_so, 0);
	test::eq(m[1].match.rm_eo, 1); // group 1 = "a"
	test::eq(m[2].match.rm_so, -1);
	test::eq(m[2].match.rm_eo, -1); // group 2 unused
}

//  GAP: Alternation in BRE with \|
fn void test_bre_alternation() @test
{
	Regex re = regex::compile("cat\\|dog", 0)!!;
	defer re.free();

	test::@check(!@catch(re.exec("cat")));
	test::@check(!@catch(re.exec("dog")));
	test::eq(@catch(re.exec("bird")), regex::NOMATCH);
}

//  GAP: eflags REG_NOTBOL / REG_NOTEOL
fn void test_eflags_notbol() @test
{
	Regex re = regex::compile("^abc", 0)!!;
	defer re.free();

	// Without flag: matches at start
	test::@check(!@catch(re.exec("abc")));
	// With REG_NOTBOL: ^ should not match at position 0
	test::eq(@catch(re.exec("abc", 1, regex::REG_NOTBOL)), regex::NOMATCH);
}

fn void test_eflags_noteol() @test
{
	Regex re = regex::compile("abc$", 0)!!;
	defer re.free();

	// Without flag: matches at end
	test::@check(!@catch(re.exec("abc")));
	// With REG_NOTEOL: $ should not match at end
	test::eq(@catch(re.exec("abc", 1, regex::REG_NOTEOL)), regex::NOMATCH);
}

//  GAP: \x hex escape sequences
fn void test_hex_escape() @test
{
	{
		// \x41 = 'A' - exercises the digit branch (4, 1) of hexval
		Regex re = regex::compile("\\x41", regex::REG_EXTENDED)!!;
		defer re.free();
		test::@check(!@catch(re.exec("A")));
		test::eq(@catch(re.exec("B")), regex::NOMATCH);
	}

	{
		// \x6e = 'n' (0x6e=110) - '6' digit branch + 'e' letter branch of hexval
		Regex re = regex::compile("\\x6e", regex::REG_EXTENDED)!!;
		defer re.free();
		test::@check(!@catch(re.exec("n")));
		test::eq(@catch(re.exec("m")), regex::NOMATCH);
	}

	{
		// \x4b = 'K' (0x4b=75) - '4' digit branch + 'b' letter branch of hexval
		// Also tests uppercase hex input: \x4B (hexval does c|=32 to fold case)
		Regex re = regex::compile("\\x4B", regex::REG_EXTENDED)!!;
		defer re.free();
		test::@check(!@catch(re.exec("K")));
		test::eq(@catch(re.exec("k")), regex::NOMATCH);
	}
}

/* ==========================================================
    taken from: (https://go.dev/src/regexp/testdata/README)
   https://go.dev/src/regexp/testdata/basic.dat?m=text
   https://go.dev/src/regexp/testdata/repetition.dat?m=text
   https://go.dev/src/regexp/testdata/nullsubexpr.dat?m=text
  ===========================================================  */

faultdef NO_ERR; // sentinel: compile_error_code returns this when no error is expected

fn void test_posix_compliance_go_testdata_333_cases() @test
{
	foreach (tc : RegexTestCase::values)
	{
		if (tc.expected_fault != NO_ERR && tc.expected_fault != regex::NOMATCH)
		{
			test::@error(regex::compile(tc.pattern.tcopy(), tc.cflags), tc.expected_fault);
			continue;
		}

		Regex re = regex::compile(tc.pattern.tcopy(), tc.cflags)!!;
		defer re.free();

		if (tc.expected_fault == regex::NOMATCH)
		{
			test::@error(re.exec(decode_input_escapes(tc.input).tcopy(), 32), regex::NOMATCH);
			continue;
		}

		Match[] pm = re.exec(decode_input_escapes(tc.input).tcopy(), 32)!!;
		for (sz s = 0; s < tc.expected_spans.len; s++)
		{
			int got_so = (s < pm.len) ? pm[s].match.rm_so : -1;
			int got_eo = (s < pm.len) ? pm[s].match.rm_eo : -1;
			test::eq(tc.expected_spans[s].start, got_so);
			test::eq(tc.expected_spans[s].end, got_eo);
		}
	}
}

<*
 Decodes literal escape sequences in the input string to actual control bytes.
 Patterns are passed through directly as the regex compiler parses escapes natively.
*>
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

// Data

struct ExpectedSpan {
    int start;
    int end;
}

enum RegexTestCase : int (
    int cflags,
    String pattern,
    String input,
    fault expected_fault,
    ExpectedSpan[] expected_spans
)
{
	CASE_0 { 0, "abracadabra$", "abracadabracadabra", NO_ERR, {{ 7, 18 }} },
	CASE_1 { 0, "a...b", "abababbb", NO_ERR, {{ 2, 7 }} },
	CASE_2 { 0, "XXXXXX", "..XXXXXX", NO_ERR, {{ 2, 8 }} },
	CASE_3 { 1, "\\)", "()", NO_ERR, {{ 1, 2 }} },
	CASE_4 { 0, "a]", "a]a", NO_ERR, {{ 0, 2 }} },
	CASE_5 { 0, "}", "}", NO_ERR, {{ 0, 1 }} },
	CASE_6 { 1, "\\}", "}", NO_ERR, {{ 0, 1 }} },
	CASE_7 { 0, "\\]", "]", NO_ERR, {{ 0, 1 }} },
	CASE_8 { 0, "]", "]", NO_ERR, {{ 0, 1 }} },
	CASE_9 { 1, "]", "]", NO_ERR, {{ 0, 1 }} },
	CASE_10 { 0, "{", "{", NO_ERR, {{ 0, 1 }} },
	CASE_11 { 0, "}", "}", NO_ERR, {{ 0, 1 }} },
	CASE_12 { 0, "^a", "ax", NO_ERR, {{ 0, 1 }} },
	CASE_13 { 0, "\\^a", "a^a", NO_ERR, {{ 1, 3 }} },
	CASE_14 { 0, "a\\^", "a^", NO_ERR, {{ 0, 2 }} },
	CASE_15 { 0, "a$", "aa", NO_ERR, {{ 1, 2 }} },
	CASE_16 { 0, "a\\$", "a$", NO_ERR, {{ 0, 2 }} },
	CASE_17 { 0, "^$", "", NO_ERR, {{ 0, 0 }} },
	CASE_18 { 1, "$^", "", NO_ERR, {{ 0, 0 }} },
	CASE_19 { 1, "a($)", "aa", NO_ERR, {{ 1, 2 }, { 2, 2 }} },
	CASE_20 { 1, "a*(^a)", "aa", NO_ERR, {{ 0, 1 }, { 0, 1 }} },
	CASE_21 { 1, "(..)*(...)*", "a", NO_ERR, {{ 0, 0 }} },
	CASE_22 { 1, "(..)*(...)*", "abcd", NO_ERR, {{ 0, 4 }, { 2, 4 }} },
	CASE_23 { 1, "(ab|a)(bc|c)", "abc", NO_ERR, {{ 0, 3 }, { 0, 2 }, { 2, 3 }} },
	CASE_24 { 1, "(ab)c|abc", "abc", NO_ERR, {{ 0, 3 }, { 0, 2 }} },
	CASE_25 { 1, "a{0}b", "ab", NO_ERR, {{ 1, 2 }} },
	CASE_26 { 1, "(a*)(b?)(b+)b{3}", "aaabbbbbbb", NO_ERR, {{ 0, 10 }, { 0, 3 }, { 3, 4 }, { 4, 7 }} },
	CASE_27 { 1, "(a*)(b{0,1})(b{1,})b{3}", "aaabbbbbbb", NO_ERR, {{ 0, 10 }, { 0, 3 }, { 3, 4 }, { 4, 7 }} },
	CASE_28 { 1, "a{9876543210}", "", regex::BADBR, {} },
	CASE_29 { 1, "((a|a)|a)", "a", NO_ERR, {{ 0, 1 }, { 0, 1 }, { 0, 1 }} },
	CASE_30 { 1, "(a*)(a|aa)", "aaaa", NO_ERR, {{ 0, 4 }, { 0, 3 }, { 3, 4 }} },
	CASE_31 { 1, "a*(a.|aa)", "aaaa", NO_ERR, {{ 0, 4 }, { 2, 4 }} },
	CASE_32 { 1, "a(b)|c(d)|a(e)f", "aef", NO_ERR, {{ 0, 3 }, { -1, -1 }, { -1, -1 }, { 1, 2 }} },
	CASE_33 { 1, "(a|b)?.*", "b", NO_ERR, {{ 0, 1 }, { 0, 1 }} },
	CASE_34 { 1, "(a|b)c|a(b|c)", "ac", NO_ERR, {{ 0, 2 }, { 0, 1 }} },
	CASE_35 { 1, "(a|b)c|a(b|c)", "ab", NO_ERR, {{ 0, 2 }, { -1, -1 }, { 1, 2 }} },
	CASE_36 { 1, "(a|b)*c|(a|ab)*c", "abc", NO_ERR, {{ 0, 3 }, { 1, 2 }} },
	CASE_37 { 1, "(a|b)*c|(a|ab)*c", "xc", NO_ERR, {{ 1, 2 }} },
	CASE_38 { 1, "(.a|.b).*|.*(.a|.b)", "xa", NO_ERR, {{ 0, 2 }, { 0, 2 }} },
	CASE_39 { 1, "a?(ab|ba)ab", "abab", NO_ERR, {{ 0, 4 }, { 0, 2 }} },
	CASE_40 { 1, "a?(ac{0}b|ba)ab", "abab", NO_ERR, {{ 0, 4 }, { 0, 2 }} },
	CASE_41 { 1, "ab|abab", "abbabab", NO_ERR, {{ 0, 2 }} },
	CASE_42 { 1, "aba|bab|bba", "baaabbbaba", NO_ERR, {{ 5, 8 }} },
	CASE_43 { 1, "aba|bab", "baaabbbaba", NO_ERR, {{ 6, 9 }} },
	CASE_44 { 1, "(aa|aaa)*|(a|aaaaa)", "aa", NO_ERR, {{ 0, 2 }, { 0, 2 }} },
	CASE_45 { 1, "(a.|.a.)*|(a|.a...)", "aa", NO_ERR, {{ 0, 2 }, { 0, 2 }} },
	CASE_46 { 1, "ab|a", "xabc", NO_ERR, {{ 1, 3 }} },
	CASE_47 { 1, "ab|a", "xxabc", NO_ERR, {{ 2, 4 }} },
	CASE_48 { 3, "(Ab|cD)*", "aBcD", NO_ERR, {{ 0, 4 }, { 2, 4 }} },
	CASE_49 { 0, "[^-]", "--a", NO_ERR, {{ 2, 3 }} },
	CASE_50 { 0, "[a-]*", "--a", NO_ERR, {{ 0, 3 }} },
	CASE_51 { 0, "[a-m-]*", "--amoma--", NO_ERR, {{ 0, 4 }} },
	CASE_52 { 1, ":::1:::0:|:::1:1:0:", ":::0:::1:::1:::0:", NO_ERR, {{ 8, 17 }} },
	CASE_53 { 1, ":::1:::0:|:::1:1:1:", ":::0:::1:::1:::0:", NO_ERR, {{ 8, 17 }} },
	CASE_54 { 1, "[[:lower:]]+", "`az{", NO_ERR, {{ 1, 3 }} },
	CASE_55 { 1, "[[:upper:]]+", "@AZ[", NO_ERR, {{ 1, 3 }} },
	CASE_56 { 0, "\\n", "\\n", NO_ERR, {{ 0, 1 }} },
	CASE_57 { 8, "\\n", "\\n", NO_ERR, {{ 0, 1 }} },
	CASE_58 { 0, "[^a]", "\\n", NO_ERR, {{ 0, 1 }} },
	CASE_59 { 0, "\\na", "\\na", NO_ERR, {{ 0, 2 }} },
	CASE_60 { 1, "(a)(b)(c)", "abc", NO_ERR, {{ 0, 3 }, { 0, 1 }, { 1, 2 }, { 2, 3 }} },
	CASE_61 { 0, "xxx", "xxx", NO_ERR, {{ 0, 3 }} },
	CASE_62 { 1, "(^|[ (,;])((([Ff]eb[^ ]* *|0*2/|\\* */?)0*[6-7]))([^0-9]|$)", "feb 6,", NO_ERR, {{ 0, 6 }} },
	CASE_63 { 1, "(^|[ (,;])((([Ff]eb[^ ]* *|0*2/|\\* */?)0*[6-7]))([^0-9]|$)", "2/7", NO_ERR, {{ 0, 3 }} },
	CASE_64 { 1, "(^|[ (,;])((([Ff]eb[^ ]* *|0*2/|\\* */?)0*[6-7]))([^0-9]|$)", "feb 1,Feb 6", NO_ERR, {{ 5, 11 }} },
	CASE_65 { 1, "((((((((((((((((((((((((((((((x))))))))))))))))))))))))))))))", "x", NO_ERR, {{ 0, 1 }, { 0, 1 }, { 0, 1 }} },
	CASE_66 { 1, "((((((((((((((((((((((((((((((x))))))))))))))))))))))))))))))*", "xx", NO_ERR, {{ 0, 2 }, { 1, 2 }, { 1, 2 }} },
	CASE_67 { 1, "a?(ab|ba)*", "ababababababababababababababababababababababababababababababababababababababababa", NO_ERR, {{ 0, 81 }, { 79, 81 }} },
	CASE_68 { 1, "abaa|abbaa|abbbaa|abbbbaa", "ababbabbbabbbabbbbabbbbaa", NO_ERR, {{ 18, 25 }} },
	CASE_69 { 1, "abaa|abbaa|abbbaa|abbbbaa", "ababbabbbabbbabbbbabaa", NO_ERR, {{ 18, 22 }} },
	CASE_70 { 1, "aaac|aabc|abac|abbc|baac|babc|bbac|bbbc", "baaabbbabac", NO_ERR, {{ 7, 11 }} },
	CASE_71 { 1, "aaaa|bbbb|cccc|ddddd|eeeeee|fffffff|gggg|hhhh|iiiii|jjjjj|kkkkk|llll", "XaaaXbbbXcccXdddXeeeXfffXgggXhhhXiiiXjjjXkkkXlllXcbaXaaaa", NO_ERR, {{ 53, 57 }} },
	CASE_72 { 1, "a*a*a*a*a*b", "aaaaaaaaab", NO_ERR, {{ 0, 10 }} },
	CASE_73 { 0, "^", "", NO_ERR, {{ 0, 0 }} },
	CASE_74 { 0, "$", "", NO_ERR, {{ 0, 0 }} },
	CASE_75 { 0, "^$", "", NO_ERR, {{ 0, 0 }} },
	CASE_76 { 0, "^a$", "a", NO_ERR, {{ 0, 1 }} },
	CASE_77 { 0, "abc", "abc", NO_ERR, {{ 0, 3 }} },
	CASE_78 { 0, "abc", "xabcy", NO_ERR, {{ 1, 4 }} },
	CASE_79 { 0, "abc", "ababc", NO_ERR, {{ 2, 5 }} },
	CASE_80 { 0, "ab*c", "abc", NO_ERR, {{ 0, 3 }} },
	CASE_81 { 0, "ab*bc", "abc", NO_ERR, {{ 0, 3 }} },
	CASE_82 { 0, "ab*bc", "abbc", NO_ERR, {{ 0, 4 }} },
	CASE_83 { 0, "ab*bc", "abbbbc", NO_ERR, {{ 0, 6 }} },
	CASE_84 { 1, "ab+bc", "abbc", NO_ERR, {{ 0, 4 }} },
	CASE_85 { 1, "ab+bc", "abbbbc", NO_ERR, {{ 0, 6 }} },
	CASE_86 { 1, "ab?bc", "abbc", NO_ERR, {{ 0, 4 }} },
	CASE_87 { 1, "ab?bc", "abc", NO_ERR, {{ 0, 3 }} },
	CASE_88 { 1, "ab?c", "abc", NO_ERR, {{ 0, 3 }} },
	CASE_89 { 0, "^abc$", "abc", NO_ERR, {{ 0, 3 }} },
	CASE_90 { 0, "^abc", "abcc", NO_ERR, {{ 0, 3 }} },
	CASE_91 { 0, "abc$", "aabc", NO_ERR, {{ 1, 4 }} },
	CASE_92 { 0, "^", "abc", NO_ERR, {{ 0, 0 }} },
	CASE_93 { 0, "$", "abc", NO_ERR, {{ 3, 3 }} },
	CASE_94 { 0, "a.c", "abc", NO_ERR, {{ 0, 3 }} },
	CASE_95 { 0, "a.c", "axc", NO_ERR, {{ 0, 3 }} },
	CASE_96 { 0, "a.*c", "axyzc", NO_ERR, {{ 0, 5 }} },
	CASE_97 { 0, "a[bc]d", "abd", NO_ERR, {{ 0, 3 }} },
	CASE_98 { 0, "a[b-d]e", "ace", NO_ERR, {{ 0, 3 }} },
	CASE_99 { 0, "a[b-d]", "aac", NO_ERR, {{ 1, 3 }} },
	CASE_100 { 0, "a[-b]", "a-", NO_ERR, {{ 0, 2 }} },
	CASE_101 { 0, "a[b-]", "a-", NO_ERR, {{ 0, 2 }} },
	CASE_102 { 0, "a]", "a]", NO_ERR, {{ 0, 2 }} },
	CASE_103 { 0, "a[]]b", "a]b", NO_ERR, {{ 0, 3 }} },
	CASE_104 { 0, "a[^bc]d", "aed", NO_ERR, {{ 0, 3 }} },
	CASE_105 { 0, "a[^-b]c", "adc", NO_ERR, {{ 0, 3 }} },
	CASE_106 { 0, "a[^]b]c", "adc", NO_ERR, {{ 0, 3 }} },
	CASE_107 { 1, "ab|cd", "abc", NO_ERR, {{ 0, 2 }} },
	CASE_108 { 1, "ab|cd", "abcd", NO_ERR, {{ 0, 2 }} },
	CASE_109 { 1, "a\\(b", "a(b", NO_ERR, {{ 0, 3 }} },
	CASE_110 { 1, "a\\(*b", "ab", NO_ERR, {{ 0, 2 }} },
	CASE_111 { 1, "a\\(*b", "a((b", NO_ERR, {{ 0, 4 }} },
	CASE_112 { 1, "((a))", "abc", NO_ERR, {{ 0, 1 }, { 0, 1 }, { 0, 1 }} },
	CASE_113 { 1, "(a)b(c)", "abc", NO_ERR, {{ 0, 3 }, { 0, 1 }, { 2, 3 }} },
	CASE_114 { 1, "a+b+c", "aabbabc", NO_ERR, {{ 4, 7 }} },
	CASE_115 { 1, "a*", "aaa", NO_ERR, {{ 0, 3 }} },
	CASE_116 { 1, "(a*)*", "-", NO_ERR, {{ 0, 0 }, { 0, 0 }} },
	CASE_117 { 1, "(a*)+", "-", NO_ERR, {{ 0, 0 }, { 0, 0 }} },
	CASE_118 { 1, "(a*|b)*", "-", NO_ERR, {{ 0, 0 }, { 0, 0 }} },
	CASE_119 { 1, "(a+|b)*", "ab", NO_ERR, {{ 0, 2 }, { 1, 2 }} },
	CASE_120 { 1, "(a+|b)+", "ab", NO_ERR, {{ 0, 2 }, { 1, 2 }} },
	CASE_121 { 1, "(a+|b)?", "ab", NO_ERR, {{ 0, 1 }, { 0, 1 }} },
	CASE_122 { 0, "[^ab]*", "cde", NO_ERR, {{ 0, 3 }} },
	CASE_123 { 1, "(^)*", "-", NO_ERR, {{ 0, 0 }, { 0, 0 }} },
	CASE_124 { 0, "a*", "", NO_ERR, {{ 0, 0 }} },
	CASE_125 { 1, "([abc])*d", "abbbcd", NO_ERR, {{ 0, 6 }, { 4, 5 }} },
	CASE_126 { 1, "([abc])*bcd", "abcd", NO_ERR, {{ 0, 4 }, { 0, 1 }} },
	CASE_127 { 1, "a|b|c|d|e", "e", NO_ERR, {{ 0, 1 }} },
	CASE_128 { 1, "(a|b|c|d|e)f", "ef", NO_ERR, {{ 0, 2 }, { 0, 1 }} },
	CASE_129 { 1, "((a*|b))*", "-", NO_ERR, {{ 0, 0 }, { 0, 0 }, { 0, 0 }} },
	CASE_130 { 0, "abcd*efg", "abcdefg", NO_ERR, {{ 0, 7 }} },
	CASE_131 { 0, "ab*", "xabyabbbz", NO_ERR, {{ 1, 3 }} },
	CASE_132 { 0, "ab*", "xayabbbz", NO_ERR, {{ 1, 2 }} },
	CASE_133 { 1, "(ab|cd)e", "abcde", NO_ERR, {{ 2, 5 }, { 2, 4 }} },
	CASE_134 { 0, "[abhgefdc]ij", "hij", NO_ERR, {{ 0, 3 }} },
	CASE_135 { 1, "(a|b)c*d", "abcd", NO_ERR, {{ 1, 4 }, { 1, 2 }} },
	CASE_136 { 1, "(ab|ab*)bc", "abc", NO_ERR, {{ 0, 3 }, { 0, 1 }} },
	CASE_137 { 1, "a([bc]*)c*", "abc", NO_ERR, {{ 0, 3 }, { 1, 3 }} },
	CASE_138 { 1, "a([bc]*)(c*d)", "abcd", NO_ERR, {{ 0, 4 }, { 1, 3 }, { 3, 4 }} },
	CASE_139 { 1, "a([bc]+)(c*d)", "abcd", NO_ERR, {{ 0, 4 }, { 1, 3 }, { 3, 4 }} },
	CASE_140 { 1, "a([bc]*)(c+d)", "abcd", NO_ERR, {{ 0, 4 }, { 1, 2 }, { 2, 4 }} },
	CASE_141 { 1, "a[bcd]*dcdcde", "adcdcde", NO_ERR, {{ 0, 7 }} },
	CASE_142 { 1, "(ab|a)b*c", "abc", NO_ERR, {{ 0, 3 }, { 0, 2 }} },
	CASE_143 { 1, "((a)(b)c)(d)", "abcd", NO_ERR, {{ 0, 4 }, { 0, 3 }, { 0, 1 }, { 1, 2 }, { 3, 4 }} },
	CASE_144 { 0, "[A-Za-z_][A-Za-z0-9_]*", "alpha", NO_ERR, {{ 0, 5 }} },
	CASE_145 { 1, "^a(bc+|b[eh])g|.h$", "abh", NO_ERR, {{ 1, 3 }} },
	CASE_146 { 1, "(bc+d$|ef*g.|h?i(j|k))", "effgz", NO_ERR, {{ 0, 5 }, { 0, 5 }} },
	CASE_147 { 1, "(bc+d$|ef*g.|h?i(j|k))", "ij", NO_ERR, {{ 0, 2 }, { 0, 2 }, { 1, 2 }} },
	CASE_148 { 1, "(bc+d$|ef*g.|h?i(j|k))", "reffgz", NO_ERR, {{ 1, 6 }, { 1, 6 }} },
	CASE_149 { 1, "(((((((((a)))))))))", "a", NO_ERR, {{ 0, 1 }, { 0, 1 }, { 0, 1 }, { 0, 1 }, { 0, 1 }, { 0, 1 }, { 0, 1 }, { 0, 1 }, { 0, 1 }, { 0, 1 }} },
	CASE_150 { 0, "multiple words", "multiple words yeah", NO_ERR, {{ 0, 14 }} },
	CASE_151 { 1, "(.*)c(.*)", "abcde", NO_ERR, {{ 0, 5 }, { 0, 2 }, { 3, 5 }} },
	CASE_152 { 0, "abcd", "abcd", NO_ERR, {{ 0, 4 }} },
	CASE_153 { 1, "a(bc)d", "abcd", NO_ERR, {{ 0, 4 }, { 1, 3 }} },
	CASE_154 { 1, "a[-]?c", "ac", NO_ERR, {{ 0, 3 }} },
	CASE_155 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Qaddafi", NO_ERR, {{ 0, 15 }, { -1, -1 }, { 10, 12 }} },
	CASE_156 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Mo'ammar Gadhafi", NO_ERR, {{ 0, 16 }, { -1, -1 }, { 11, 13 }} },
	CASE_157 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Kaddafi", NO_ERR, {{ 0, 15 }, { -1, -1 }, { 10, 12 }} },
	CASE_158 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Qadhafi", NO_ERR, {{ 0, 15 }, { -1, -1 }, { 10, 12 }} },
	CASE_159 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Gadafi", NO_ERR, {{ 0, 14 }, { -1, -1 }, { 10, 11 }} },
	CASE_160 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Mu'ammar Qadafi", NO_ERR, {{ 0, 15 }, { -1, -1 }, { 11, 12 }} },
	CASE_161 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Moamar Gaddafi", NO_ERR, {{ 0, 14 }, { -1, -1 }, { 9, 11 }} },
	CASE_162 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Mu'ammar Qadhdhafi", NO_ERR, {{ 0, 18 }, { -1, -1 }, { 13, 15 }} },
	CASE_163 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Khaddafi", NO_ERR, {{ 0, 16 }, { -1, -1 }, { 11, 13 }} },
	CASE_164 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Ghaddafy", NO_ERR, {{ 0, 16 }, { -1, -1 }, { 11, 13 }} },
	CASE_165 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Ghadafi", NO_ERR, {{ 0, 15 }, { -1, -1 }, { 11, 12 }} },
	CASE_166 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Ghaddafi", NO_ERR, {{ 0, 16 }, { -1, -1 }, { 11, 13 }} },
	CASE_167 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muamar Kaddafi", NO_ERR, {{ 0, 14 }, { -1, -1 }, { 9, 11 }} },
	CASE_168 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Quathafi", NO_ERR, {{ 0, 16 }, { -1, -1 }, { 11, 13 }} },
	CASE_169 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Muammar Gheddafi", NO_ERR, {{ 0, 16 }, { -1, -1 }, { 11, 13 }} },
	CASE_170 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Moammar Khadafy", NO_ERR, {{ 0, 15 }, { -1, -1 }, { 11, 12 }} },
	CASE_171 { 1, "M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]", "Moammar Qudhafi", NO_ERR, {{ 0, 15 }, { -1, -1 }, { 10, 12 }} },
	CASE_172 { 1, "a+(b|c)*d+", "aabcdd", NO_ERR, {{ 0, 6 }, { 3, 4 }} },
	CASE_173 { 1, "^.+$", "vivi", NO_ERR, {{ 0, 4 }} },
	CASE_174 { 1, "^(.+)$", "vivi", NO_ERR, {{ 0, 4 }, { 0, 4 }} },
	CASE_175 { 1, "^([^!.]+).att.com!(.+)$", "gryphon.att.com!eby", NO_ERR, {{ 0, 19 }, { 0, 7 }, { 16, 19 }} },
	CASE_176 { 1, "^([^!]+!)?([^!]+)$", "bas", NO_ERR, {{ 0, 3 }, { -1, -1 }, { 0, 3 }} },
	CASE_177 { 1, "^([^!]+!)?([^!]+)$", "bar!bas", NO_ERR, {{ 0, 7 }, { 0, 4 }, { 4, 7 }} },
	CASE_178 { 1, "^([^!]+!)?([^!]+)$", "foo!bas", NO_ERR, {{ 0, 7 }, { 0, 4 }, { 4, 7 }} },
	CASE_179 { 1, "^.+!([^!]+!)([^!]+)$", "foo!bar!bas", NO_ERR, {{ 0, 11 }, { 4, 8 }, { 8, 11 }} },
	CASE_180 { 1, "((foo)|(bar))!bas", "bar!bas", NO_ERR, {{ 0, 7 }, { 0, 3 }, { -1, -1 }, { 0, 3 }} },
	CASE_181 { 1, "((foo)|(bar))!bas", "foo!bar!bas", NO_ERR, {{ 4, 11 }, { 4, 7 }, { -1, -1 }, { 4, 7 }} },
	CASE_182 { 1, "((foo)|(bar))!bas", "foo!bas", NO_ERR, {{ 0, 7 }, { 0, 3 }, { 0, 3 }} },
	CASE_183 { 1, "((foo)|bar)!bas", "bar!bas", NO_ERR, {{ 0, 7 }, { 0, 3 }} },
	CASE_184 { 1, "((foo)|bar)!bas", "foo!bar!bas", NO_ERR, {{ 4, 11 }, { 4, 7 }} },
	CASE_185 { 1, "((foo)|bar)!bas", "foo!bas", NO_ERR, {{ 0, 7 }, { 0, 3 }, { 0, 3 }} },
	CASE_186 { 1, "(foo|(bar))!bas", "bar!bas", NO_ERR, {{ 0, 7 }, { 0, 3 }, { 0, 3 }} },
	CASE_187 { 1, "(foo|(bar))!bas", "foo!bar!bas", NO_ERR, {{ 4, 11 }, { 4, 7 }, { 4, 7 }} },
	CASE_188 { 1, "(foo|(bar))!bas", "foo!bas", NO_ERR, {{ 0, 7 }, { 0, 3 }} },
	CASE_189 { 1, "(foo|bar)!bas", "bar!bas", NO_ERR, {{ 0, 7 }, { 0, 3 }} },
	CASE_190 { 1, "(foo|bar)!bas", "foo!bar!bas", NO_ERR, {{ 4, 11 }, { 4, 7 }} },
	CASE_191 { 1, "(foo|bar)!bas", "foo!bas", NO_ERR, {{ 0, 7 }, { 0, 3 }} },
	CASE_192 { 1, "^(([^!]+!)?([^!]+)|.+!([^!]+!)([^!]+))$", "foo!bar!bas", NO_ERR, {{ 0, 11 }, { 0, 11 }, { -1, -1 }, { -1, -1 }, { 4, 8 }, { 8, 11 }} },
	CASE_193 { 1, "^([^!]+!)?([^!]+)$|^.+!([^!]+!)([^!]+)$", "bas", NO_ERR, {{ 0, 3 }, { -1, -1 }, { 0, 3 }} },
	CASE_194 { 1, "^([^!]+!)?([^!]+)$|^.+!([^!]+!)([^!]+)$", "bar!bas", NO_ERR, {{ 0, 7 }, { 0, 4 }, { 4, 7 }} },
	CASE_195 { 1, "^([^!]+!)?([^!]+)$|^.+!([^!]+!)([^!]+)$", "foo!bar!bas", NO_ERR, {{ 0, 11 }, { -1, -1 }, { -1, -1 }, { 4, 8 }, { 8, 11 }} },
	CASE_196 { 1, "^([^!]+!)?([^!]+)$|^.+!([^!]+!)([^!]+)$", "foo!bas", NO_ERR, {{ 0, 7 }, { 0, 4 }, { 4, 7 }} },
	CASE_197 { 1, "^(([^!]+!)?([^!]+)|.+!([^!]+!)([^!]+))$", "bas", NO_ERR, {{ 0, 3 }, { 0, 3 }, { -1, -1 }, { 0, 3 }} },
	CASE_198 { 1, "^(([^!]+!)?([^!]+)|.+!([^!]+!)([^!]+))$", "bar!bas", NO_ERR, {{ 0, 7 }, { 0, 7 }, { 0, 4 }, { 4, 7 }} },
	CASE_199 { 1, "^(([^!]+!)?([^!]+)|.+!([^!]+!)([^!]+))$", "foo!bar!bas", NO_ERR, {{ 0, 11 }, { 0, 11 }, { -1, -1 }, { -1, -1 }, { 4, 8 }, { 8, 11 }} },
	CASE_200 { 1, "^(([^!]+!)?([^!]+)|.+!([^!]+!)([^!]+))$", "foo!bas", NO_ERR, {{ 0, 7 }, { 0, 7 }, { 0, 4 }, { 4, 7 }} },
	CASE_201 { 1, ".*(/XXX).*", "/XXX", NO_ERR, {{ 0, 4 }, { 0, 4 }} },
	CASE_202 { 1, ".*(\\\\XXX).*", "\\XXX", NO_ERR, {{ 0, 4 }, { 0, 4 }} },
	CASE_203 { 1, "\\\\XXX", "\\XXX", NO_ERR, {{ 0, 4 }} },
	CASE_204 { 1, ".*(/000).*", "/000", NO_ERR, {{ 0, 4 }, { 0, 4 }} },
	CASE_205 { 1, ".*(\\\\000).*", "\\000", NO_ERR, {{ 0, 4 }, { 0, 4 }} },
	CASE_206 { 1, "\\\\000", "\\000", NO_ERR, {{ 0, 4 }} },
	CASE_207 { 1, "((..)|(.))", "", regex::NOMATCH, {} },
	CASE_208 { 1, "((..)|(.))((..)|(.))", "", regex::NOMATCH, {} },
	CASE_209 { 1, "((..)|(.))((..)|(.))((..)|(.))", "", regex::NOMATCH, {} },
	CASE_210 { 1, "((..)|(.)){1}", "", regex::NOMATCH, {} },
	CASE_211 { 1, "((..)|(.)){2}", "", regex::NOMATCH, {} },
	CASE_212 { 1, "((..)|(.)){3}", "", regex::NOMATCH, {} },
	CASE_213 { 1, "((..)|(.))*", "", NO_ERR, {{ 0, 0 }} },
	CASE_214 { 1, "((..)|(.))", "a", NO_ERR, {{ 0, 1 }, { 0, 1 }, { -1, -1 }, { 0, 1 }} },
	CASE_215 { 1, "((..)|(.))((..)|(.))", "a", regex::NOMATCH, {} },
	CASE_216 { 1, "((..)|(.))((..)|(.))((..)|(.))", "a", regex::NOMATCH, {} },
	CASE_217 { 1, "((..)|(.)){1}", "a", NO_ERR, {{ 0, 1 }, { 0, 1 }, { -1, -1 }, { 0, 1 }} },
	CASE_218 { 1, "((..)|(.)){2}", "a", regex::NOMATCH, {} },
	CASE_219 { 1, "((..)|(.)){3}", "a", regex::NOMATCH, {} },
	CASE_220 { 1, "((..)|(.))*", "a", NO_ERR, {{ 0, 1 }, { 0, 1 }, { -1, -1 }, { 0, 1 }} },
	CASE_221 { 1, "((..)|(.))", "aa", NO_ERR, {{ 0, 2 }, { 0, 2 }, { 0, 2 }, { -1, -1 }} },
	CASE_222 { 1, "((..)|(.))((..)|(.))", "aa", NO_ERR, {{ 0, 2 }, { 0, 1 }, { -1, -1 }, { 0, 1 }, { 1, 2 }, { -1, -1 }, { 1, 2 }} },
	CASE_223 { 1, "((..)|(.))((..)|(.))((..)|(.))", "aa", regex::NOMATCH, {} },
	CASE_224 { 1, "((..)|(.)){1}", "aa", NO_ERR, {{ 0, 2 }, { 0, 2 }, { 0, 2 }, { -1, -1 }} },
	CASE_225 { 1, "((..)|(.)){3}", "aa", regex::NOMATCH, {} },
	CASE_226 { 1, "((..)|(.))*", "aa", NO_ERR, {{ 0, 2 }, { 0, 2 }, { 0, 2 }, { -1, -1 }} },
	CASE_227 { 1, "((..)|(.))", "aaa", NO_ERR, {{ 0, 2 }, { 0, 2 }, { 0, 2 }, { -1, -1 }} },
	CASE_228 { 1, "((..)|(.))((..)|(.))", "aaa", NO_ERR, {{ 0, 3 }, { 0, 2 }, { 0, 2 }, { -1, -1 }, { 2, 3 }, { -1, -1 }, { 2, 3 }} },
	CASE_229 { 1, "((..)|(.))((..)|(.))((..)|(.))", "aaa", NO_ERR, {{ 0, 3 }, { 0, 1 }, { -1, -1 }, { 0, 1 }, { 1, 2 }, { -1, -1 }, { 1, 2 }, { 2, 3 }, { -1, -1 }, { 2, 3 }} },
	CASE_230 { 1, "((..)|(.)){1}", "aaa", NO_ERR, {{ 0, 2 }, { 0, 2 }, { 0, 2 }, { -1, -1 }} },
	CASE_231 { 1, "((..)|(.)){3}", "aaa", NO_ERR, {{ 0, 3 }, { 2, 3 }, { -1, -1 }, { 2, 3 }} },
	CASE_232 { 1, "((..)|(.))", "aaaa", NO_ERR, {{ 0, 2 }, { 0, 2 }, { 0, 2 }, { -1, -1 }} },
	CASE_233 { 1, "((..)|(.))((..)|(.))", "aaaa", NO_ERR, {{ 0, 4 }, { 0, 2 }, { 0, 2 }, { -1, -1 }, { 2, 4 }, { 2, 4 }, { -1, -1 }} },
	CASE_234 { 1, "((..)|(.))((..)|(.))((..)|(.))", "aaaa", NO_ERR, {{ 0, 4 }, { 0, 2 }, { 0, 2 }, { -1, -1 }, { 2, 3 }, { -1, -1 }, { 2, 3 }, { 3, 4 }, { -1, -1 }, { 3, 4 }} },
	CASE_235 { 1, "((..)|(.)){1}", "aaaa", NO_ERR, {{ 0, 2 }, { 0, 2 }, { 0, 2 }, { -1, -1 }} },
	CASE_236 { 1, "((..)|(.)){2}", "aaaa", NO_ERR, {{ 0, 4 }, { 2, 4 }, { 2, 4 }, { -1, -1 }} },
	CASE_237 { 1, "((..)|(.))", "aaaaa", NO_ERR, {{ 0, 2 }, { 0, 2 }, { 0, 2 }, { -1, -1 }} },
	CASE_238 { 1, "((..)|(.))((..)|(.))", "aaaaa", NO_ERR, {{ 0, 4 }, { 0, 2 }, { 0, 2 }, { -1, -1 }, { 2, 4 }, { 2, 4 }, { -1, -1 }} },
	CASE_239 { 1, "((..)|(.))((..)|(.))((..)|(.))", "aaaaa", NO_ERR, {{ 0, 5 }, { 0, 2 }, { 0, 2 }, { -1, -1 }, { 2, 4 }, { 2, 4 }, { -1, -1 }, { 4, 5 }, { -1, -1 }, { 4, 5 }} },
	CASE_240 { 1, "((..)|(.)){1}", "aaaaa", NO_ERR, {{ 0, 2 }, { 0, 2 }, { 0, 2 }, { -1, -1 }} },
	CASE_241 { 1, "((..)|(.)){2}", "aaaaa", NO_ERR, {{ 0, 4 }, { 2, 4 }, { 2, 4 }, { -1, -1 }} },
	CASE_242 { 1, "((..)|(.))", "aaaaaa", NO_ERR, {{ 0, 2 }, { 0, 2 }, { 0, 2 }, { -1, -1 }} },
	CASE_243 { 1, "((..)|(.))((..)|(.))", "aaaaaa", NO_ERR, {{ 0, 4 }, { 0, 2 }, { 0, 2 }, { -1, -1 }, { 2, 4 }, { 2, 4 }, { -1, -1 }} },
	CASE_244 { 1, "((..)|(.))((..)|(.))((..)|(.))", "aaaaaa", NO_ERR, {{ 0, 6 }, { 0, 2 }, { 0, 2 }, { -1, -1 }, { 2, 4 }, { 2, 4 }, { -1, -1 }, { 4, 6 }, { 4, 6 }, { -1, -1 }} },
	CASE_245 { 1, "((..)|(.)){1}", "aaaaaa", NO_ERR, {{ 0, 2 }, { 0, 2 }, { 0, 2 }, { -1, -1 }} },
	CASE_246 { 1, "((..)|(.)){2}", "aaaaaa", NO_ERR, {{ 0, 4 }, { 2, 4 }, { 2, 4 }, { -1, -1 }} },
	CASE_247 { 1, "((..)|(.)){3}", "aaaaaa", NO_ERR, {{ 0, 6 }, { 4, 6 }, { 4, 6 }, { -1, -1 }} },
	CASE_248 { 1, "((..)|(.))*", "aaaaaa", NO_ERR, {{ 0, 6 }, { 4, 6 }, { 4, 6 }, { -1, -1 }} },
	CASE_249 { 1, "X(.?){0,}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_250 { 1, "X(.?){1,}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_251 { 1, "X(.?){2,}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_252 { 1, "X(.?){3,}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_253 { 1, "X(.?){4,}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_254 { 1, "X(.?){5,}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_255 { 1, "X(.?){6,}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_256 { 1, "X(.?){8,}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 8, 8 }} },
	CASE_257 { 1, "X(.?){0,8}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_258 { 1, "X(.?){1,8}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_259 { 1, "X(.?){2,8}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_260 { 1, "X(.?){3,8}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_261 { 1, "X(.?){4,8}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_262 { 1, "X(.?){5,8}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_263 { 1, "X(.?){6,8}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_264 { 1, "X(.?){7,8}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 7, 8 }} },
	CASE_265 { 1, "X(.?){8,8}Y", "X1234567Y", NO_ERR, {{ 0, 9 }, { 8, 8 }} },
	CASE_266 { 1, "(a|ab|c|bcd){4,}(d*)", "ababcd", regex::NOMATCH, {} },
	CASE_267 { 1, "(a|ab|c|bcd){4,10}(d*)", "ababcd", regex::NOMATCH, {} },
	CASE_268 { 1, "(ab|a|c|bcd){0,}(d*)", "ababcd", NO_ERR, {{ 0, 6 }, { 3, 6 }, { 6, 6 }} },
	CASE_269 { 1, "(ab|a|c|bcd){1,}(d*)", "ababcd", NO_ERR, {{ 0, 6 }, { 3, 6 }, { 6, 6 }} },
	CASE_270 { 1, "(ab|a|c|bcd){2,}(d*)", "ababcd", NO_ERR, {{ 0, 6 }, { 3, 6 }, { 6, 6 }} },
	CASE_271 { 1, "(ab|a|c|bcd){3,}(d*)", "ababcd", NO_ERR, {{ 0, 6 }, { 3, 6 }, { 6, 6 }} },
	CASE_272 { 1, "(ab|a|c|bcd){4,}(d*)", "ababcd", regex::NOMATCH, {} },
	CASE_273 { 1, "(ab|a|c|bcd){0,10}(d*)", "ababcd", NO_ERR, {{ 0, 6 }, { 3, 6 }, { 6, 6 }} },
	CASE_274 { 1, "(ab|a|c|bcd){1,10}(d*)", "ababcd", NO_ERR, {{ 0, 6 }, { 3, 6 }, { 6, 6 }} },
	CASE_275 { 1, "(ab|a|c|bcd){2,10}(d*)", "ababcd", NO_ERR, {{ 0, 6 }, { 3, 6 }, { 6, 6 }} },
	CASE_276 { 1, "(ab|a|c|bcd){3,10}(d*)", "ababcd", NO_ERR, {{ 0, 6 }, { 3, 6 }, { 6, 6 }} },
	CASE_277 { 1, "(ab|a|c|bcd){4,10}(d*)", "ababcd", regex::NOMATCH, {} },
	CASE_278 { 1, "(ab|a|c|bcd)*(d*)", "ababcd", NO_ERR, {{ 0, 6 }, { 3, 6 }, { 6, 6 }} },
	CASE_279 { 1, "(ab|a|c|bcd)+(d*)", "ababcd", NO_ERR, {{ 0, 6 }, { 3, 6 }, { 6, 6 }} },
	CASE_280 { 1, "(a*)*", "a", NO_ERR, {{ 0, 1 }, { 0, 1 }} },
	CASE_281 { 1, "(a*)*", "x", NO_ERR, {{ 0, 0 }, { 0, 0 }} },
	CASE_282 { 1, "(a*)*", "aaaaaa", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_283 { 1, "(a*)*", "aaaaaax", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_284 { 1, "(a*)+", "a", NO_ERR, {{ 0, 1 }, { 0, 1 }} },
	CASE_285 { 1, "(a*)+", "x", NO_ERR, {{ 0, 0 }, { 0, 0 }} },
	CASE_286 { 1, "(a*)+", "aaaaaa", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_287 { 1, "(a*)+", "aaaaaax", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_288 { 1, "(a+)*", "a", NO_ERR, {{ 0, 1 }, { 0, 1 }} },
	CASE_289 { 1, "(a+)*", "x", NO_ERR, {{ 0, 0 }} },
	CASE_290 { 1, "(a+)*", "aaaaaa", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_291 { 1, "(a+)*", "aaaaaax", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_292 { 1, "(a+)+", "a", NO_ERR, {{ 0, 1 }, { 0, 1 }} },
	CASE_293 { 1, "(a+)+", "x", regex::NOMATCH, {} },
	CASE_294 { 1, "(a+)+", "aaaaaa", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_295 { 1, "(a+)+", "aaaaaax", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_296 { 1, "([a]*)*", "a", NO_ERR, {{ 0, 1 }, { 0, 1 }} },
	CASE_297 { 1, "([a]*)*", "x", NO_ERR, {{ 0, 0 }, { 0, 0 }} },
	CASE_298 { 1, "([a]*)*", "aaaaaa", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_299 { 1, "([a]*)*", "aaaaaax", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_300 { 1, "([a]*)+", "a", NO_ERR, {{ 0, 1 }, { 0, 1 }} },
	CASE_301 { 1, "([a]*)+", "x", NO_ERR, {{ 0, 0 }, { 0, 0 }} },
	CASE_302 { 1, "([a]*)+", "aaaaaa", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_303 { 1, "([a]*)+", "aaaaaax", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_304 { 1, "([^b]*)*", "a", NO_ERR, {{ 0, 1 }, { 0, 1 }} },
	CASE_305 { 1, "([^b]*)*", "b", NO_ERR, {{ 0, 0 }, { 0, 0 }} },
	CASE_306 { 1, "([^b]*)*", "aaaaaa", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_307 { 1, "([^b]*)*", "aaaaaab", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_308 { 1, "([ab]*)*", "a", NO_ERR, {{ 0, 1 }, { 0, 1 }} },
	CASE_309 { 1, "([ab]*)*", "aaaaaa", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_310 { 1, "([ab]*)*", "ababab", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_311 { 1, "([ab]*)*", "bababa", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_312 { 1, "([ab]*)*", "b", NO_ERR, {{ 0, 1 }, { 0, 1 }} },
	CASE_313 { 1, "([ab]*)*", "bbbbbb", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_314 { 1, "([ab]*)*", "aaaabcde", NO_ERR, {{ 0, 5 }, { 0, 5 }} },
	CASE_315 { 1, "([^a]*)*", "b", NO_ERR, {{ 0, 1 }, { 0, 1 }} },
	CASE_316 { 1, "([^a]*)*", "bbbbbb", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_317 { 1, "([^a]*)*", "aaaaaa", NO_ERR, {{ 0, 0 }, { 0, 0 }} },
	CASE_318 { 1, "([^ab]*)*", "ccccxx", NO_ERR, {{ 0, 6 }, { 0, 6 }} },
	CASE_319 { 1, "([^ab]*)*", "ababab", NO_ERR, {{ 0, 0 }, { 0, 0 }} },
	CASE_320 { 1, "((z)+|a)*", "zabcde", NO_ERR, {{ 0, 2 }, { 1, 2 }} },
	CASE_321 { 0, "\\(a*\\)*\\(x\\)", "x", NO_ERR, {{ 0, 1 }, { 0, 0 }, { 0, 1 }} },
	CASE_322 { 0, "\\(a*\\)*\\(x\\)", "ax", NO_ERR, {{ 0, 2 }, { 0, 1 }, { 1, 2 }} },
	CASE_323 { 0, "\\(a*\\)*\\(x\\)", "axa", NO_ERR, {{ 0, 2 }, { 0, 1 }, { 1, 2 }} },
	CASE_324 { 1, "(a*)*(x)", "x", NO_ERR, {{ 0, 1 }, { 0, 0 }, { 0, 1 }} },
	CASE_325 { 1, "(a*)*(x)", "ax", NO_ERR, {{ 0, 2 }, { 0, 1 }, { 1, 2 }} },
	CASE_326 { 1, "(a*)*(x)", "axa", NO_ERR, {{ 0, 2 }, { 0, 1 }, { 1, 2 }} },
	CASE_327 { 1, "(a*)+(x)", "x", NO_ERR, {{ 0, 1 }, { 0, 0 }, { 0, 1 }} },
	CASE_328 { 1, "(a*)+(x)", "ax", NO_ERR, {{ 0, 2 }, { 0, 1 }, { 1, 2 }} },
	CASE_329 { 1, "(a*)+(x)", "axa", NO_ERR, {{ 0, 2 }, { 0, 1 }, { 1, 2 }} },
	CASE_330 { 1, "(a*){2}(x)", "x", NO_ERR, {{ 0, 1 }, { 0, 0 }, { 0, 1 }} },
	CASE_331 { 1, "(a*){2}(x)", "ax", NO_ERR, {{ 0, 2 }, { 1, 1 }, { 1, 2 }} },
	CASE_332 { 1, "(a*){2}(x)", "axa", NO_ERR, {{ 0, 2 }, { 1, 1 }, { 1, 2 }} },
}

