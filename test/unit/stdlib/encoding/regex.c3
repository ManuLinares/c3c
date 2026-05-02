import std::encoding::regex;

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

// more more

fn void test_compile_basic() @test
{
	Regex re;
	int err = regex::re_compile(&re, "a*b", 0);
	assert(err == regex::REG_OK);
	assert(re.re_nsub == 0);
	regex::re_free(&re);
}

fn void test_compile_extended() @test
{
	Regex re;
	int err = regex::re_compile(&re, "(a*)b", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(re.re_nsub == 1);
	regex::re_free(&re);
}

fn void test_compile_error() @test
{
	Regex re;
	int err = regex::re_compile(&re, "(a*b", regex::REG_EXTENDED);
	assert(err == regex::REG_EPAREN);
}

fn void test_match_basic() @test
{
	Regex re;
	regex::re_compile(&re, "abc", 0);
	RegMatch[1] pmatch;
	int err = regex::re_exec(&re, "---abc---", 1, &pmatch[0], 0);
	assert(err == regex::REG_OK);
	assert(pmatch[0].rm_so == 3);
	assert(pmatch[0].rm_eo == 6);
	regex::re_free(&re);
}

fn void test_match_quantifier() @test
{
	Regex re;
	regex::re_compile(&re, "a*b", 0);
	RegMatch[1] pmatch;
	int err = regex::re_exec(&re, "aaab", 1, &pmatch[0], 0);
	assert(err == regex::REG_OK);
	assert(pmatch[0].rm_so == 0);
	assert(pmatch[0].rm_eo == 4);
	regex::re_free(&re);
}

fn void test_match_submatch() @test
{
	Regex re;
	regex::re_compile(&re, "(a*)b", regex::REG_EXTENDED);
	RegMatch[2] pmatch;
	int err = regex::re_exec(&re, "aaab", 2, &pmatch[0], 0);
	assert(err == regex::REG_OK);
	assert(pmatch[0].rm_so == 0);
	assert(pmatch[0].rm_eo == 4);
	assert(pmatch[1].rm_so == 0);
	assert(pmatch[1].rm_eo == 3);
	regex::re_free(&re);
}

fn void test_match_nomatch() @test
{
	Regex re;
	regex::re_compile(&re, "abc", 0);
	int err = regex::re_exec(&re, "def", 0, null, 0);
	assert(err == regex::REG_NOMATCH);
	regex::re_free(&re);
}

fn void test_match_anchors() @test
{
	Regex re;
	regex::re_compile(&re, "^abc$", 0);
	assert(regex::re_exec(&re, "abc", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "abcd", 0, null, 0) == regex::REG_NOMATCH);
	assert(regex::re_exec(&re, " abc", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

// ============================================================
//  GAP: REG_ICASE, case-insensitive matching
// ============================================================

fn void test_icase_literal() @test
{
	Regex re;
	int err = regex::re_compile(&re, "abc", regex::REG_ICASE);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "ABC", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "Abc", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "aBc", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "xyz", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

fn void test_icase_range() @test
{
	Regex re;
	// [a-z] with REG_ICASE should match uppercase letters too
	int err = regex::re_compile(&re, "[a-z]+", regex::REG_EXTENDED | regex::REG_ICASE);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "ABC", 0, null, 0) == regex::REG_OK);
	regex::re_free(&re);
}

//  GAP: REG_NEWLINE, newline-sensitive matching
fn void test_newline_dot() @test
{
	Regex re;
	// By default '.' matches '\n'
	regex::re_compile(&re, "a.b", regex::REG_EXTENDED);
	assert(regex::re_exec(&re, "a\nb", 0, null, 0) == regex::REG_OK);
	regex::re_free(&re);

	// With REG_NEWLINE, '.' must NOT match '\n'
	regex::re_compile(&re, "a.b", regex::REG_EXTENDED | regex::REG_NEWLINE);
	assert(regex::re_exec(&re, "a\nb", 0, null, 0) == regex::REG_NOMATCH);
	assert(regex::re_exec(&re, "axb", 0, null, 0) == regex::REG_OK);
	regex::re_free(&re);
}

fn void test_newline_anchor() @test
{
	Regex re;
	// With REG_NEWLINE, ^ and $ match at embedded newlines
	regex::re_compile(&re, "^foo$", regex::REG_EXTENDED | regex::REG_NEWLINE);
	assert(regex::re_exec(&re, "bar\nfoo\nbaz", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "bar\nfoo", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "foo\nbar", 0, null, 0) == regex::REG_OK);
	regex::re_free(&re);
}

//  GAP: REG_NOSUB, skip submatch tracking
fn void test_nosub_match() @test
{
	Regex re;
	// REG_NOSUB: compile succeeds, re_nsub must be 0
	int err = regex::re_compile(&re, "(a+)b", regex::REG_EXTENDED | regex::REG_NOSUB);
	assert(err == regex::REG_OK);
	// Must still report a match or no-match correctly
	assert(regex::re_exec(&re, "aaab", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "xyz", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

//  GAP: Bracket negation [^...]
fn void test_bracket_negation() @test
{
	Regex re;
	int err = regex::re_compile(&re, "[^abc]", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "a", 0, null, 0) == regex::REG_NOMATCH);
	assert(regex::re_exec(&re, "b", 0, null, 0) == regex::REG_NOMATCH);
	assert(regex::re_exec(&re, "c", 0, null, 0) == regex::REG_NOMATCH);
	assert(regex::re_exec(&re, "d", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "z", 0, null, 0) == regex::REG_OK);
	regex::re_free(&re);
}

fn void test_bracket_negation_range() @test
{
	Regex re;
	int err = regex::re_compile(&re, "[^a-z]", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "a", 0, null, 0) == regex::REG_NOMATCH);
	assert(regex::re_exec(&re, "z", 0, null, 0) == regex::REG_NOMATCH);
	assert(regex::re_exec(&re, "A", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "0", 0, null, 0) == regex::REG_OK);
	regex::re_free(&re);
}

//  GAP: Character classes in brackets [:class:]
fn void test_bracket_class_digit() @test
{
	Regex re;
	int err = regex::re_compile(&re, "[[:digit:]]", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "5", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "a", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

fn void test_bracket_class_alpha() @test
{
	Regex re;
	int err = regex::re_compile(&re, "[[:alpha:]]", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "a", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "Z", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "5", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

fn void test_bracket_class_space() @test
{
	Regex re;
	int err = regex::re_compile(&re, "[[:space:]]", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, " ", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "\t", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "a", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

fn void test_bracket_neg_class() @test
{
	Regex re;
	// Negated character class: [^[:digit:]] should not match digits
	int err = regex::re_compile(&re, "[^[:digit:]]", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "a", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "5", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

//  GAP: Quantifier expansion {m,n}, +, ?
fn void test_quantifier_exact() @test
{
	Regex re;
	// a{3} should match exactly "aaa"
	int err = regex::re_compile(&re, "a{3}", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	RegMatch[1] pm;
	assert(regex::re_exec(&re, "aaa", 1, &pm[0], 0) == regex::REG_OK);
	assert(pm[0].rm_so == 0 && pm[0].rm_eo == 3);
	// "aa" should not match (only 2)
	assert(regex::re_exec(&re, "aa", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

fn void test_quantifier_range() @test
{
	Regex re;
	// a{2,4} should match 2 to 4 a's, leftmost-longest
	int err = regex::re_compile(&re, "a{2,4}", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	RegMatch[1] pm;
	assert(regex::re_exec(&re, "aaaaa", 1, &pm[0], 0) == regex::REG_OK);
	assert(pm[0].rm_eo - pm[0].rm_so == 4); // greedy: 4 chars
	assert(regex::re_exec(&re, "a", 0, null, 0) == regex::REG_NOMATCH);
	assert(regex::re_exec(&re, "aa", 0, null, 0) == regex::REG_OK);
	regex::re_free(&re);
}

fn void test_quantifier_plus() @test
{
	Regex re;
	// a+ must match one or more a's
	int err = regex::re_compile(&re, "a+b", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	RegMatch[1] pm;
	assert(regex::re_exec(&re, "aaab", 1, &pm[0], 0) == regex::REG_OK);
	assert(pm[0].rm_so == 0 && pm[0].rm_eo == 4);
	assert(regex::re_exec(&re, "b", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

fn void test_quantifier_question() @test
{
	Regex re;
	// ab? matches "a" or "ab"
	int err = regex::re_compile(&re, "ab?", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	RegMatch[1] pm;
	assert(regex::re_exec(&re, "ab", 1, &pm[0], 0) == regex::REG_OK);
	assert(pm[0].rm_eo == 2);
	assert(regex::re_exec(&re, "a", 1, &pm[0], 0) == regex::REG_OK);
	assert(pm[0].rm_eo == 1);
	regex::re_free(&re);
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
	// \x41 = 'A'
	int err = regex::re_compile(&re, "\\x41", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "A", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "B", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

//  GAP: ERE alternation with complex sub-expressions
fn void test_ere_alternation_complex() @test
{
	Regex re;
	int err = regex::re_compile(&re, "foo|bar|baz", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "foo", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "bar", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "baz", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "qux", 0, null, 0) == regex::REG_NOMATCH);
	regex::re_free(&re);
}

//  GAP: Multiple submatches / nested groups
fn void test_nested_submatches() @test
{
	Regex re;
	int err = regex::re_compile(&re, "((a+)(b+))", regex::REG_EXTENDED);
	assert(err == regex::REG_OK);
	assert(re.re_nsub == 3);
	RegMatch[4] pm;
	assert(regex::re_exec(&re, "aaabb", 4, &pm[0], 0) == regex::REG_OK);
	assert(pm[0].rm_so == 0 && pm[0].rm_eo == 5); // full match
	assert(pm[1].rm_so == 0 && pm[1].rm_eo == 5); // outer group
	assert(pm[2].rm_so == 0 && pm[2].rm_eo == 3); // (a+)
	assert(pm[3].rm_so == 3 && pm[3].rm_eo == 5); // (b+)
	regex::re_free(&re);
}

//  GAP: BRE grouping with \( \)
fn void test_bre_grouping() @test
{
	Regex re;
	int err = regex::re_compile(&re, "\\(ab\\)*c", 0);
	assert(err == regex::REG_OK);
	assert(regex::re_exec(&re, "c", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "abc", 0, null, 0) == regex::REG_OK);
	assert(regex::re_exec(&re, "ababc", 0, null, 0) == regex::REG_OK);
	regex::re_free(&re);
}


/**********************************************************
 taken from: (https://go.dev/src/regexp/testdata/README)
 https://go.dev/src/regexp/testdata/basic.dat
 https://go.dev/src/regexp/testdata/repetition.dat
 https://go.dev/src/regexp/testdata/nullsubexpr.dat
***********************************************************/

fn void test_basic_001_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abracadabra$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abracadabracadabra`, 1, &pm[0], 0));
    test::eq(7, pm[0].rm_so);
    test::eq(18, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_001_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abracadabra$`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abracadabracadabra`, 1, &pm[0], 0));
    test::eq(7, pm[0].rm_so);
    test::eq(18, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_002_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a...b`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abababbb`, 1, &pm[0], 0));
    test::eq(2, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_002_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a...b`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abababbb`, 1, &pm[0], 0));
    test::eq(2, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_003_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `XXXXXX`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `..XXXXXX`, 1, &pm[0], 0));
    test::eq(2, pm[0].rm_so);
    test::eq(8, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_003_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `XXXXXX`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `..XXXXXX`, 1, &pm[0], 0));
    test::eq(2, pm[0].rm_so);
    test::eq(8, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_004_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `()`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_005_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a]a`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_005_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a]`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a]a`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_006_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `}`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `}`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_007_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `}`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_008_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `]`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_008_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\]`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `]`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_009_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `]`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `]`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_010_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `]`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_011_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `{`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `{`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_012_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `}`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `}`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_013_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^a`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ax`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_013_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^a`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ax`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_014_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\^a`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a^a`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_014_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\^a`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a^a`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_015_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a\^`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a^`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_015_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a\^`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a^`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_016_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aa`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_016_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a$`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aa`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_017_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a\$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a$`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_017_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a\$`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a$`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_018_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, ``, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_018_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^$`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, ``, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_019_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `$^`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, ``, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_020_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a($)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aa`, 2, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(2, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_021_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a*(^a)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_022_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(..)*(...)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_023_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(..)*(...)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcd`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(2, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_024_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a)(bc|c)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(2, pm[2].rm_so);
    test::eq(3, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_025_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab)c|abc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_026_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a{0}b`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ab`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_027_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)(b?)(b+)b{3}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaabbbbbbb`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(10, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    test::eq(3, pm[2].rm_so);
    test::eq(4, pm[2].rm_eo);
    test::eq(4, pm[3].rm_so);
    test::eq(7, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_028_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)(b{0,1})(b{1,})b{3}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaabbbbbbb`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(10, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    test::eq(3, pm[2].rm_so);
    test::eq(4, pm[2].rm_eo);
    test::eq(4, pm[3].rm_so);
    test::eq(7, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_029_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a{9876543210}`, regex::REG_EXTENDED);
    test::ne(regex::REG_OK, err);
}

fn void test_basic_030_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((a|a)|a)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(1, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_031_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)(a|aa)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaa`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    test::eq(3, pm[2].rm_so);
    test::eq(4, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_032_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a*(a.|aa)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(2, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_033_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a(b)|c(d)|a(e)f`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aef`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(1, pm[3].rm_so);
    test::eq(2, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_034_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|b)?.*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `b`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_035_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|b)c|a(b|c)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ac`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_036_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|b)c|a(b|c)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ab`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_037_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|b)*c|(a|ab)*c`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_038_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|b)*c|(a|ab)*c`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `xc`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_039_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(.a|.b).*|.*(.a|.b)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `xa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_040_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a?(ab|ba)ab`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abab`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_041_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a?(ac{0}b|ba)ab`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abab`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_042_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab|abab`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abbabab`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_043_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `aba|bab|bba`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `baaabbbaba`, 1, &pm[0], 0));
    test::eq(5, pm[0].rm_so);
    test::eq(8, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_044_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `aba|bab`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `baaabbbaba`, 1, &pm[0], 0));
    test::eq(6, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_045_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(aa|aaa)*|(a|aaaaa)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_046_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a.|.a.)*|(a|.a...)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_047_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab|a`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `xabc`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_048_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab|a`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `xxabc`, 1, &pm[0], 0));
    test::eq(2, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_049_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(Ab|cD)*`, regex::REG_EXTENDED | regex::REG_ICASE);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aBcD`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(2, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_050_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[^-]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `--a`, 1, &pm[0], 0));
    test::eq(2, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_050_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[^-]`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `--a`, 1, &pm[0], 0));
    test::eq(2, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_051_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[a-]*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `--a`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_051_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[a-]*`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `--a`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_052_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[a-m-]*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `--amoma--`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_052_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[a-m-]*`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `--amoma--`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_053_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `:::1:::0:|:::1:1:0:`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `:::0:::1:::1:::0:`, 1, &pm[0], 0));
    test::eq(8, pm[0].rm_so);
    test::eq(17, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_054_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `:::1:::0:|:::1:1:1:`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `:::0:::1:::1:::0:`, 1, &pm[0], 0));
    test::eq(8, pm[0].rm_so);
    test::eq(17, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_055_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[[:upper:]]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `A`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_056_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[[:lower:]]+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, ```az{`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_057_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[[:upper:]]+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `@AZ[`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_058_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\n`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `

`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_058_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\n`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `

`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_059_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\n`, regex::REG_EXTENDED | regex::REG_NEWLINE);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `

`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_059_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\n`, 0 | regex::REG_NEWLINE);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `

`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_060_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[^a]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `

`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_060_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[^a]`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `

`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_061_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\na`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `
a
`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_061_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\na`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `
a
`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_062_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a)(b)(c)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(2, pm[3].rm_so);
    test::eq(3, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_063_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `xxx`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `xxx`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_063_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `xxx`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `xxx`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_064_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a?(ab|ba)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababababababababababababababababababababababababababababababababababababababababa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(81, pm[0].rm_eo);
    test::eq(79, pm[1].rm_so);
    test::eq(81, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_065_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abaa|abbaa|abbbaa|abbbbaa`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababbabbbabbbabbbbabbbbaa`, 1, &pm[0], 0));
    test::eq(18, pm[0].rm_so);
    test::eq(25, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_066_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abaa|abbaa|abbbaa|abbbbaa`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababbabbbabbbabbbbabaa`, 1, &pm[0], 0));
    test::eq(18, pm[0].rm_so);
    test::eq(22, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_067_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `aaac|aabc|abac|abbc|baac|babc|bbac|bbbc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `baaabbbabac`, 1, &pm[0], 0));
    test::eq(7, pm[0].rm_so);
    test::eq(11, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_068_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `aaaa|bbbb|cccc|ddddd|eeeeee|fffffff|gggg|hhhh|iiiii|jjjjj|kkkkk|llll`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `XaaaXbbbXcccXdddXeeeXfffXgggXhhhXiiiXjjjXkkkXlllXcbaXaaaa`, 1, &pm[0], 0));
    test::eq(53, pm[0].rm_so);
    test::eq(57, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_069_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a*a*a*a*a*b`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaaaaab`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(10, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_070_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, ``, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_070_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, ``, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_071_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, ``, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_071_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `$`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, ``, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_072_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, ``, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_072_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^$`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, ``, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_073_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^a$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_073_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^a$`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_074_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_074_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abc`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_075_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `xabcy`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_075_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abc`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `xabcy`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_076_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababc`, 1, &pm[0], 0));
    test::eq(2, pm[0].rm_so);
    test::eq(5, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_076_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abc`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababc`, 1, &pm[0], 0));
    test::eq(2, pm[0].rm_so);
    test::eq(5, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_077_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab*c`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_077_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab*c`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_078_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab*bc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_078_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab*bc`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_079_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab*bc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abbc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_079_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab*bc`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abbc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_080_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab*bc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abbbbc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_080_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab*bc`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abbbbc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_081_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab+bc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abbc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_082_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab+bc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abbbbc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_083_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab?bc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abbc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_084_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab?bc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_085_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab?c`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_086_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^abc$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_086_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^abc$`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_087_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^abc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_087_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^abc`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_088_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abc$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aabc`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_088_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abc$`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aabc`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_089_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_089_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_090_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(3, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_090_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `$`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(3, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_091_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a.c`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_091_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a.c`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_092_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a.c`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `axc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_092_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a.c`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `axc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_093_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a.*c`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `axyzc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(5, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_093_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a.*c`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `axyzc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(5, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_094_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[bc]d`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abd`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_094_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[bc]d`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abd`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_095_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[b-d]e`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ace`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_095_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[b-d]e`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ace`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_096_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[b-d]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aac`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_096_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[b-d]`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aac`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_097_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[-b]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a-`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_097_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[-b]`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a-`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_098_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[b-]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a-`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_098_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[b-]`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a-`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_099_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a]`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_099_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a]`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a]`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_100_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[]]b`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a]b`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_100_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[]]b`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a]b`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_101_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[^bc]d`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aed`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_101_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[^bc]d`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aed`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_102_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[^-b]c`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `adc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_102_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[^-b]c`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `adc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_103_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[^]b]c`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `adc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_103_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[^]b]c`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `adc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_104_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab|cd`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_105_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab|cd`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcd`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_106_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a\(b`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a(b`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_107_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a\(*b`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ab`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_108_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a\(*b`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a((b`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_109_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((a))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(1, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_110_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a)b(c)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(2, pm[2].rm_so);
    test::eq(3, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_111_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a+b+c`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aabbabc`, 1, &pm[0], 0));
    test::eq(4, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_112_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaa`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_113_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `-`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_114_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `-`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_115_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*|b)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `-`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_116_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a+|b)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ab`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_117_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a+|b)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ab`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_118_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a+|b)?`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ab`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_119_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[^ab]*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `cde`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_119_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[^ab]*`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `cde`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_120_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(^)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `-`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_121_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, ``, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_121_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a*`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, ``, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_122_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([abc])*d`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abbbcd`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(4, pm[1].rm_so);
    test::eq(5, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_123_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([abc])*bcd`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcd`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_124_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a|b|c|d|e`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `e`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_125_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|b|c|d|e)f`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ef`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_126_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((a*|b))*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `-`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(0, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_127_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abcd*efg`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcdefg`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_127_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abcd*efg`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcdefg`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_128_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `xabyabbbz`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_128_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab*`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `xabyabbbz`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_129_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `xayabbbz`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_129_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `ab*`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `xayabbbz`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_130_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|cd)e`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcde`, 2, &pm[0], 0));
    test::eq(2, pm[0].rm_so);
    test::eq(5, pm[0].rm_eo);
    test::eq(2, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_131_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[abhgefdc]ij`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `hij`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_131_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[abhgefdc]ij`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `hij`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_132_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|b)c*d`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcd`, 2, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_133_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|ab*)bc`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_134_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a([bc]*)c*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_135_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a([bc]*)(c*d)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    test::eq(3, pm[2].rm_so);
    test::eq(4, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_136_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a([bc]+)(c*d)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    test::eq(3, pm[2].rm_so);
    test::eq(4, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_137_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a([bc]*)(c+d)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(2, pm[2].rm_so);
    test::eq(4, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_138_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[bcd]*dcdcde`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `adcdcde`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_139_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a)b*c`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abc`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_140_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((a)(b)c)(d)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(4, re.re_nsub);
    RegMatch[5] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcd`, 5, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(1, pm[2].rm_eo);
    test::eq(1, pm[3].rm_so);
    test::eq(2, pm[3].rm_eo);
    test::eq(3, pm[4].rm_so);
    test::eq(4, pm[4].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_141_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[A-Za-z_][A-Za-z0-9_]*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `alpha`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(5, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_141_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `[A-Za-z_][A-Za-z0-9_]*`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `alpha`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(5, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_142_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^a(bc+|b[eh])g|.h$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abh`, 1, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_143_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(bc+d$|ef*g.|h?i(j|k))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `effgz`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(5, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(5, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_144_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(bc+d$|ef*g.|h?i(j|k))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ij`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_145_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(bc+d$|ef*g.|h?i(j|k))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `reffgz`, 2, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_146_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(((((((((a)))))))))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(9, re.re_nsub);
    RegMatch[10] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 10, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(1, pm[2].rm_eo);
    test::eq(0, pm[3].rm_so);
    test::eq(1, pm[3].rm_eo);
    test::eq(0, pm[4].rm_so);
    test::eq(1, pm[4].rm_eo);
    test::eq(0, pm[5].rm_so);
    test::eq(1, pm[5].rm_eo);
    test::eq(0, pm[6].rm_so);
    test::eq(1, pm[6].rm_eo);
    test::eq(0, pm[7].rm_so);
    test::eq(1, pm[7].rm_eo);
    test::eq(0, pm[8].rm_so);
    test::eq(1, pm[8].rm_eo);
    test::eq(0, pm[9].rm_so);
    test::eq(1, pm[9].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_147_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `multiple words`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `multiple words yeah`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(14, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_147_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `multiple words`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `multiple words yeah`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(14, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_148_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(.*)c(.*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcde`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(5, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(3, pm[2].rm_so);
    test::eq(5, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_149_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abcd`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcd`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_149_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `abcd`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcd`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_150_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a(bc)d`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `abcd`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_151_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a[-]?c`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ac`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_152_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Muammar Qaddafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(15, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(10, pm[2].rm_so);
    test::eq(12, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_153_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Mo'ammar Gadhafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(16, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(11, pm[2].rm_so);
    test::eq(13, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_154_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Muammar Kaddafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(15, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(10, pm[2].rm_so);
    test::eq(12, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_155_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Muammar Qadhafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(15, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(10, pm[2].rm_so);
    test::eq(12, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_156_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Muammar Gadafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(14, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(10, pm[2].rm_so);
    test::eq(11, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_157_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Mu'ammar Qadafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(15, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(11, pm[2].rm_so);
    test::eq(12, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_158_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Moamar Gaddafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(14, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(9, pm[2].rm_so);
    test::eq(11, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_159_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Mu'ammar Qadhdhafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(18, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(13, pm[2].rm_so);
    test::eq(15, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_160_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Muammar Khaddafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(16, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(11, pm[2].rm_so);
    test::eq(13, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_161_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Muammar Ghaddafy`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(16, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(11, pm[2].rm_so);
    test::eq(13, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_162_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Muammar Ghadafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(15, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(11, pm[2].rm_so);
    test::eq(12, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_163_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Muammar Ghaddafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(16, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(11, pm[2].rm_so);
    test::eq(13, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_164_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Muamar Kaddafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(14, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(9, pm[2].rm_so);
    test::eq(11, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_165_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Muammar Quathafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(16, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(11, pm[2].rm_so);
    test::eq(13, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_166_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Muammar Gheddafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(16, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(11, pm[2].rm_so);
    test::eq(13, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_167_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Moammar Khadafy`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(15, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(11, pm[2].rm_so);
    test::eq(12, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_168_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `M[ou]'?am+[ae]r .*([AEae]l[- ])?[GKQ]h?[aeu]+([dtz][dhz]?)+af[iy]`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `Moammar Qudhafi`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(15, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(10, pm[2].rm_so);
    test::eq(12, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_169_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `a+(b|c)*d+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aabcdd`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(3, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_170_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^.+$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `vivi`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_171_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^(.+)$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `vivi`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_172_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^([^!.]+).att.com!(.+)$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `gryphon.att.com!eby`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(19, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(7, pm[1].rm_eo);
    test::eq(16, pm[2].rm_so);
    test::eq(19, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_173_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^([^!]+!)?([^!]+)$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `bas`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(3, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_174_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^([^!]+!)?([^!]+)$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `bar!bas`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    test::eq(4, pm[2].rm_so);
    test::eq(7, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_175_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^([^!]+!)?([^!]+)$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bas`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    test::eq(4, pm[2].rm_so);
    test::eq(7, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_176_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^.+!([^!]+!)([^!]+)$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bar!bas`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(11, pm[0].rm_eo);
    test::eq(4, pm[1].rm_so);
    test::eq(8, pm[1].rm_eo);
    test::eq(8, pm[2].rm_so);
    test::eq(11, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_177_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((foo)|(bar))!bas`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `bar!bas`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(0, pm[3].rm_so);
    test::eq(3, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_178_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((foo)|(bar))!bas`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bar!bas`, 4, &pm[0], 0));
    test::eq(4, pm[0].rm_so);
    test::eq(11, pm[0].rm_eo);
    test::eq(4, pm[1].rm_so);
    test::eq(7, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(4, pm[3].rm_so);
    test::eq(7, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_179_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((foo)|(bar))!bas`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bas`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(3, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_180_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((foo)|bar)!bas`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `bar!bas`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_181_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((foo)|bar)!bas`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bar!bas`, 2, &pm[0], 0));
    test::eq(4, pm[0].rm_so);
    test::eq(11, pm[0].rm_eo);
    test::eq(4, pm[1].rm_so);
    test::eq(7, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_182_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((foo)|bar)!bas`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bas`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(3, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_183_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(foo|(bar))!bas`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `bar!bas`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(3, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_184_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(foo|(bar))!bas`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bar!bas`, 3, &pm[0], 0));
    test::eq(4, pm[0].rm_so);
    test::eq(11, pm[0].rm_eo);
    test::eq(4, pm[1].rm_so);
    test::eq(7, pm[1].rm_eo);
    test::eq(4, pm[2].rm_so);
    test::eq(7, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_185_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(foo|(bar))!bas`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bas`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_186_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(foo|bar)!bas`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `bar!bas`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_187_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(foo|bar)!bas`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bar!bas`, 2, &pm[0], 0));
    test::eq(4, pm[0].rm_so);
    test::eq(11, pm[0].rm_eo);
    test::eq(4, pm[1].rm_so);
    test::eq(7, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_188_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(foo|bar)!bas`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bas`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_189_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^(([^!]+!)?([^!]+)|.+!([^!]+!)([^!]+))$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(5, re.re_nsub);
    RegMatch[6] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bar!bas`, 6, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(11, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(11, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    test::eq(4, pm[4].rm_so);
    test::eq(8, pm[4].rm_eo);
    test::eq(8, pm[5].rm_so);
    test::eq(11, pm[5].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_190_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^([^!]+!)?([^!]+)$|^.+!([^!]+!)([^!]+)$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(4, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `bas`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(3, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_191_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^([^!]+!)?([^!]+)$|^.+!([^!]+!)([^!]+)$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(4, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `bar!bas`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    test::eq(4, pm[2].rm_so);
    test::eq(7, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_192_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^([^!]+!)?([^!]+)$|^.+!([^!]+!)([^!]+)$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(4, re.re_nsub);
    RegMatch[5] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bar!bas`, 5, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(11, pm[0].rm_eo);
    test::eq(-1, pm[1].rm_so);
    test::eq(-1, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(4, pm[3].rm_so);
    test::eq(8, pm[3].rm_eo);
    test::eq(8, pm[4].rm_so);
    test::eq(11, pm[4].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_193_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^([^!]+!)?([^!]+)$|^.+!([^!]+!)([^!]+)$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(4, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bas`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    test::eq(4, pm[2].rm_so);
    test::eq(7, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_194_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^(([^!]+!)?([^!]+)|.+!([^!]+!)([^!]+))$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(5, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `bas`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(0, pm[3].rm_so);
    test::eq(3, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_195_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^(([^!]+!)?([^!]+)|.+!([^!]+!)([^!]+))$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(5, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `bar!bas`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(7, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(4, pm[2].rm_eo);
    test::eq(4, pm[3].rm_so);
    test::eq(7, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_196_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^(([^!]+!)?([^!]+)|.+!([^!]+!)([^!]+))$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(5, re.re_nsub);
    RegMatch[6] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bar!bas`, 6, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(11, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(11, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    test::eq(4, pm[4].rm_so);
    test::eq(8, pm[4].rm_eo);
    test::eq(8, pm[5].rm_so);
    test::eq(11, pm[5].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_197_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `^(([^!]+!)?([^!]+)|.+!([^!]+!)([^!]+))$`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(5, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `foo!bas`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(7, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(7, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(4, pm[2].rm_eo);
    test::eq(4, pm[3].rm_so);
    test::eq(7, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_198_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `.*(/XXX).*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `/XXX`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_199_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `.*(\\XXX).*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `\XXX`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_200_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\\XXX`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(0, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `\XXX`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_basic_201_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `.*(/000).*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `/000`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_001_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, ``, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_002_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(6, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, ``, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_003_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(9, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, ``, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_004_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){1}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, ``, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_005_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){2}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, ``, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_006_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){3}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, ``, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_007_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, ``, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_008_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(0, pm[3].rm_so);
    test::eq(1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_009_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(6, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, `a`, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_010_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(9, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, `a`, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_011_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){1}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(0, pm[3].rm_so);
    test::eq(1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_012_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){2}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, `a`, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_013_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){3}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, `a`, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_014_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(0, pm[3].rm_so);
    test::eq(1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_015_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_016_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(6, re.re_nsub);
    RegMatch[7] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aa`, 7, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(0, pm[3].rm_so);
    test::eq(1, pm[3].rm_eo);
    test::eq(1, pm[4].rm_so);
    test::eq(2, pm[4].rm_eo);
    test::eq(-1, pm[5].rm_so);
    test::eq(-1, pm[5].rm_eo);
    test::eq(1, pm[6].rm_so);
    test::eq(2, pm[6].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_017_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(9, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, `aa`, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_018_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){1}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_019_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){2}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(1, pm[3].rm_so);
    test::eq(2, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_020_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){3}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, `aa`, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_021_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_022_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_023_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(6, re.re_nsub);
    RegMatch[7] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaa`, 7, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    test::eq(2, pm[4].rm_so);
    test::eq(3, pm[4].rm_eo);
    test::eq(-1, pm[5].rm_so);
    test::eq(-1, pm[5].rm_eo);
    test::eq(2, pm[6].rm_so);
    test::eq(3, pm[6].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_024_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(9, re.re_nsub);
    RegMatch[10] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaa`, 10, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(0, pm[3].rm_so);
    test::eq(1, pm[3].rm_eo);
    test::eq(1, pm[4].rm_so);
    test::eq(2, pm[4].rm_eo);
    test::eq(-1, pm[5].rm_so);
    test::eq(-1, pm[5].rm_eo);
    test::eq(1, pm[6].rm_so);
    test::eq(2, pm[6].rm_eo);
    test::eq(2, pm[7].rm_so);
    test::eq(3, pm[7].rm_eo);
    test::eq(-1, pm[8].rm_so);
    test::eq(-1, pm[8].rm_eo);
    test::eq(2, pm[9].rm_so);
    test::eq(3, pm[9].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_025_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){1}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_026_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){2}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_027_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){3}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(2, pm[1].rm_so);
    test::eq(3, pm[1].rm_eo);
    test::eq(-1, pm[2].rm_so);
    test::eq(-1, pm[2].rm_eo);
    test::eq(2, pm[3].rm_so);
    test::eq(3, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_028_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_029_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_030_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(6, re.re_nsub);
    RegMatch[7] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaa`, 7, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    test::eq(2, pm[4].rm_so);
    test::eq(4, pm[4].rm_eo);
    test::eq(2, pm[5].rm_so);
    test::eq(4, pm[5].rm_eo);
    test::eq(-1, pm[6].rm_so);
    test::eq(-1, pm[6].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_031_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(9, re.re_nsub);
    RegMatch[10] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaa`, 10, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    test::eq(2, pm[4].rm_so);
    test::eq(3, pm[4].rm_eo);
    test::eq(-1, pm[5].rm_so);
    test::eq(-1, pm[5].rm_eo);
    test::eq(2, pm[6].rm_so);
    test::eq(3, pm[6].rm_eo);
    test::eq(3, pm[7].rm_so);
    test::eq(4, pm[7].rm_eo);
    test::eq(-1, pm[8].rm_so);
    test::eq(-1, pm[8].rm_eo);
    test::eq(3, pm[9].rm_so);
    test::eq(4, pm[9].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_032_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){1}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_033_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){2}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(2, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    test::eq(2, pm[2].rm_so);
    test::eq(4, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_034_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){3}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_035_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(2, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    test::eq(2, pm[2].rm_so);
    test::eq(4, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_036_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_037_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(6, re.re_nsub);
    RegMatch[7] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaa`, 7, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    test::eq(2, pm[4].rm_so);
    test::eq(4, pm[4].rm_eo);
    test::eq(2, pm[5].rm_so);
    test::eq(4, pm[5].rm_eo);
    test::eq(-1, pm[6].rm_so);
    test::eq(-1, pm[6].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_038_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(9, re.re_nsub);
    RegMatch[10] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaa`, 10, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(5, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    test::eq(2, pm[4].rm_so);
    test::eq(4, pm[4].rm_eo);
    test::eq(2, pm[5].rm_so);
    test::eq(4, pm[5].rm_eo);
    test::eq(-1, pm[6].rm_so);
    test::eq(-1, pm[6].rm_eo);
    test::eq(4, pm[7].rm_so);
    test::eq(5, pm[7].rm_eo);
    test::eq(-1, pm[8].rm_so);
    test::eq(-1, pm[8].rm_eo);
    test::eq(4, pm[9].rm_so);
    test::eq(5, pm[9].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_039_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){1}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_040_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){2}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(2, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    test::eq(2, pm[2].rm_so);
    test::eq(4, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_041_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){3}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(5, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_042_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(5, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_043_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_044_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(6, re.re_nsub);
    RegMatch[7] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 7, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    test::eq(2, pm[4].rm_so);
    test::eq(4, pm[4].rm_eo);
    test::eq(2, pm[5].rm_so);
    test::eq(4, pm[5].rm_eo);
    test::eq(-1, pm[6].rm_so);
    test::eq(-1, pm[6].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_045_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))((..)|(.))((..)|(.))`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(9, re.re_nsub);
    RegMatch[10] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 10, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    test::eq(2, pm[4].rm_so);
    test::eq(4, pm[4].rm_eo);
    test::eq(2, pm[5].rm_so);
    test::eq(4, pm[5].rm_eo);
    test::eq(-1, pm[6].rm_so);
    test::eq(-1, pm[6].rm_eo);
    test::eq(4, pm[7].rm_so);
    test::eq(6, pm[7].rm_eo);
    test::eq(4, pm[8].rm_so);
    test::eq(6, pm[8].rm_eo);
    test::eq(-1, pm[9].rm_so);
    test::eq(-1, pm[9].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_046_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){1}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_047_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){2}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(2, pm[1].rm_so);
    test::eq(4, pm[1].rm_eo);
    test::eq(2, pm[2].rm_so);
    test::eq(4, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_048_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.)){3}`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(4, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    test::eq(4, pm[2].rm_so);
    test::eq(6, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_049_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((..)|(.))*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(4, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    test::eq(4, pm[2].rm_so);
    test::eq(6, pm[2].rm_eo);
    test::eq(-1, pm[3].rm_so);
    test::eq(-1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_050_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){0,}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    test::eq(7, pm[1].rm_so);
    test::eq(8, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_051_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){1,}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    test::eq(7, pm[1].rm_so);
    test::eq(8, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_052_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){2,}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    test::eq(7, pm[1].rm_so);
    test::eq(8, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_053_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){3,}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    test::eq(7, pm[1].rm_so);
    test::eq(8, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_054_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){4,}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    test::eq(7, pm[1].rm_so);
    test::eq(8, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_055_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){5,}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    test::eq(7, pm[1].rm_so);
    test::eq(8, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_056_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){6,}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    test::eq(7, pm[1].rm_so);
    test::eq(8, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_057_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){7,}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    test::eq(8, pm[1].rm_so);
    test::eq(8, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_058_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){8,}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    test::eq(8, pm[1].rm_so);
    test::eq(8, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_059_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){0,8}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_060_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){1,8}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_061_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){2,8}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_062_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){3,8}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_063_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){4,8}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_064_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){5,8}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_065_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){6,8}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_066_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){7,8}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_067_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `X(.?){8,8}Y`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `X1234567Y`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(9, pm[0].rm_eo);
    test::eq(8, pm[1].rm_so);
    test::eq(8, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_068_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|ab|c|bcd){0,}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(3, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    test::eq(6, pm[2].rm_so);
    test::eq(6, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_069_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|ab|c|bcd){1,}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(3, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    test::eq(6, pm[2].rm_so);
    test::eq(6, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_070_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|ab|c|bcd){2,}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(3, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    test::eq(6, pm[2].rm_so);
    test::eq(6, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_071_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|ab|c|bcd){3,}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(3, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    test::eq(6, pm[2].rm_so);
    test::eq(6, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_072_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|ab|c|bcd){4,}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, `ababcd`, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_073_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|ab|c|bcd){0,10}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(3, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    test::eq(6, pm[2].rm_so);
    test::eq(6, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_074_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|ab|c|bcd){1,10}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(3, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    test::eq(6, pm[2].rm_so);
    test::eq(6, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_075_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|ab|c|bcd){2,10}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(3, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    test::eq(6, pm[2].rm_so);
    test::eq(6, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_076_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|ab|c|bcd){3,10}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(3, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    test::eq(6, pm[2].rm_so);
    test::eq(6, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_077_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|ab|c|bcd){4,10}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, `ababcd`, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_078_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|ab|c|bcd)*(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(3, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    test::eq(6, pm[2].rm_so);
    test::eq(6, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_079_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a|ab|c|bcd)+(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(3, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    test::eq(6, pm[2].rm_so);
    test::eq(6, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_080_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a|c|bcd){0,}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_081_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a|c|bcd){1,}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_082_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a|c|bcd){2,}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_083_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a|c|bcd){3,}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_084_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a|c|bcd){4,}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, `ababcd`, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_085_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a|c|bcd){0,10}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_086_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a|c|bcd){1,10}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_087_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a|c|bcd){2,10}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_088_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a|c|bcd){3,10}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_089_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a|c|bcd){4,10}(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, `ababcd`, 0, null, 0));
    regex::re_free(&re);
}

fn void test_repetition_090_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a|c|bcd)*(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_repetition_091_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(ab|a|c|bcd)+(d*)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababcd`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_001_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_002_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `x`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_003_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_004_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaax`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_005_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_006_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `x`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_007_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_008_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaax`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_009_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a+)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_010_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a+)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[1] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `x`, 1, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_011_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a+)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_012_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a+)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaax`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_013_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a+)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_014_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a+)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, `x`, 0, null, 0));
    regex::re_free(&re);
}

fn void test_nullsubexpr_015_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a+)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_016_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a+)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaax`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_017_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([a]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_018_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([a]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `x`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_019_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([a]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_020_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([a]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaax`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_021_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([a]*)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_022_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([a]*)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `x`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_023_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([a]*)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_024_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([a]*)+`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaax`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_025_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([^b]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_026_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([^b]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `b`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_027_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([^b]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_028_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([^b]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaab`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_029_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([ab]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `a`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_030_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([ab]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_031_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([ab]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababab`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_032_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([ab]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `bababa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_033_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([ab]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `b`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_034_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([ab]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `bbbbbb`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_035_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([ab]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaabcde`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(5, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(5, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_036_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([^a]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `b`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_037_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([^a]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `bbbbbb`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_038_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([^a]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `aaaaaa`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_039_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([^ab]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ccccxx`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(6, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(6, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_040_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `([^ab]*)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(1, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ababab`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(0, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_041_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `((z)+|a)*`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[2] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `zabcde`, 2, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(2, pm[1].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_042_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\(a*\)*\(x\)`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `x`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(1, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_043_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\(a*\)*\(x\)`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ax`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_044_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\(a*\)*\(x\)`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `axa`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_045_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\(a*\)*\(x\)\(\1\)`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `x`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(1, pm[2].rm_eo);
    test::eq(1, pm[3].rm_so);
    test::eq(1, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_046_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\(a*\)*\(x\)\(\1\)`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_NOMATCH, regex::re_exec(&re, `ax`, 0, null, 0));
    regex::re_free(&re);
}

fn void test_nullsubexpr_047_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\(a*\)*\(x\)\(\1\)`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(3, re.re_nsub);
    RegMatch[4] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `axa`, 4, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(2, pm[3].rm_so);
    test::eq(3, pm[3].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_048_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\(a*\)*\(x\)\(\1\)\(x\)`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(4, re.re_nsub);
    RegMatch[5] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `axax`, 5, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(4, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(2, pm[3].rm_so);
    test::eq(3, pm[3].rm_eo);
    test::eq(3, pm[4].rm_so);
    test::eq(4, pm[4].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_049_basic() @test
{
    Regex re;
    int err = regex::re_compile(&re, `\(a*\)*\(x\)\(\1\)\(x\)`, 0);
    test::eq(regex::REG_OK, err);
    test::eq(4, re.re_nsub);
    RegMatch[5] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `axxa`, 5, &pm[0], 0));
    test::eq(1, pm[0].rm_so);
    test::eq(3, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    test::eq(2, pm[3].rm_so);
    test::eq(2, pm[3].rm_eo);
    test::eq(2, pm[4].rm_so);
    test::eq(3, pm[4].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_050_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)*(x)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `x`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(1, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_051_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)*(x)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ax`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_052_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)*(x)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `axa`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_053_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)+(x)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `x`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(1, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_054_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)+(x)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ax`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_055_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*)+(x)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `axa`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_056_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*){2}(x)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `x`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(1, pm[0].rm_eo);
    test::eq(0, pm[1].rm_so);
    test::eq(0, pm[1].rm_eo);
    test::eq(0, pm[2].rm_so);
    test::eq(1, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_057_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*){2}(x)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `ax`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    regex::re_free(&re);
}

fn void test_nullsubexpr_058_extended() @test
{
    Regex re;
    int err = regex::re_compile(&re, `(a*){2}(x)`, regex::REG_EXTENDED);
    test::eq(regex::REG_OK, err);
    test::eq(2, re.re_nsub);
    RegMatch[3] pm;
    test::eq(regex::REG_OK, regex::re_exec(&re, `axa`, 3, &pm[0], 0));
    test::eq(0, pm[0].rm_so);
    test::eq(2, pm[0].rm_eo);
    test::eq(1, pm[1].rm_so);
    test::eq(1, pm[1].rm_eo);
    test::eq(1, pm[2].rm_so);
    test::eq(2, pm[2].rm_eo);
    regex::re_free(&re);
}

