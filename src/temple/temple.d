module temple.temple;
import
  temple.util,
  temple.delims,
  temple.output_stream,
  temple.temple_context;

import
  std.array,
  std.exception,
  std.range;

string gen_temple_func_string(string temple_str)
{

	auto function_str = "";
	auto indent_level = 0;

	void push_line(string[] stmts...)
	{
		foreach(i; 0..indent_level)
		{
			function_str ~= '\t';
		}
		foreach(stmt; stmts)
		{
			function_str ~= stmt;
		}
		function_str ~= '\n';
	}

	void indent()  { indent_level++; }
	void outdent() { indent_level--; }

	push_line(`void Temple(OS)(OS __buff, TempleContext __context = TempleContext())`);
	push_line(`if(isOutputRange!(OS, string))`);
	push_line(`{`);
	indent();
	push_line(`import std.conv;`);
	push_line(`__buff.put("");`);

	push_line(`with(__context) {`);
	indent();

	auto safeswitch = 0;

	string prevTempl = "";

	while(!temple_str.empty) {
		if(safeswitch++ > 100) {
			assert(false, "nesting level too deep; throwing saftey switch: \n" ~ temple_str);
		}

		DelimPos!(OpenDelim)* oDelimPos = temple_str.nextDelim(OpenDelims);

		if(oDelimPos is null)
		{
			//No more delims; append the rest as a string
			push_line(`__buff.put("` ~ temple_str.escapeQuotes() ~ `");`);
			prevTempl.munchHeadOf(temple_str, temple_str.length);
		}
		else
		{
			immutable OpenDelim  oDelim = oDelimPos.delim;
			immutable CloseDelim cDelim = OpenToClose[oDelim];

			if(oDelimPos.pos == 0)
			{
				// Delim is at the start of temple_str
				if(oDelim.isShort()) {
					if(!prevTempl.validBeforeShort())
					{
						// Chars before % were invalid, assume it's part of a
						// string literal.
						push_line(`__buff.put("` ~ temple_str[0..oDelim.toString().length] ~ `");`);
						prevTempl.munchHeadOf(temple_str, oDelim.toString().length);
						continue;
					}
				}

				// If we made it this far, we've got valid open/close delims
				auto cDelimPos = temple_str.nextDelim([cDelim]);
				if(cDelimPos is null)
				{
					if(oDelim.isShort())
					{
						// don't require a short close delim at the end of the template
						temple_str ~= cDelim.toString();
						cDelimPos = enforce(temple_str.nextDelim([cDelim]));
					}
					else
					{
						assert(false, "Missing close delimer: " ~ cDelim.toString());
					}
				}

				// Made it this far, we've got the position of the close delimer.
				auto inbetween_delims = temple_str[oDelim.toString().length .. cDelimPos.pos];
				if(oDelim.isStr())
				{
					push_line(`__buff.put(to!string((` ~ inbetween_delims ~ `)));`);
					if(cDelim == CloseDelim.CloseShort)
					{
						push_line(`__buff.put("\n");`);
					}
				}
				else
				{
					push_line(inbetween_delims);
				}
				prevTempl.munchHeadOf(
					temple_str,
					cDelimPos.pos + cDelim.toString().length);
			}
			else
			{
				//Delim is somewhere in the string
				push_line(`__buff.put("` ~ temple_str[0..oDelimPos.pos] ~ `");`);
				prevTempl.munchHeadOf(temple_str, oDelimPos.pos);
			}
		}

	}

	outdent();
	push_line("}");
	outdent();
	push_line("}");

	return function_str;
}

template Temple(string template_string, string name = "")
{
	#line 1 "Temple"
	mixin(gen_temple_func_string(template_string));
	#line 137 "src/temple/temple.d"
	static assert(__LINE__ == 137);
}

template TempleFile(string template_string)
{
	pragma(msg, "Compiling ", template_string, "...");
	alias TempleFile = Temple!(import(template_string));
}

version(unittest)
{
	private import std.string, std.stdio, std.file : readText;

	bool isSameRender(string r1, string r2)
	{
		auto ret = r1.stripWs == r2.stripWs;

		if(ret == false)
		{
			writeln("Renders differ: ");
			writeln("------------------------------");
			writeln(r1);
			writeln("------------------------------");
			writeln(r2);
			writeln("------------------------------");
		}

		return ret;
	}
}

unittest
{
	alias render = Temple!"";
	auto accum = appender!string();

	render(accum);
	assert(accum.data == "");
}


unittest
{
	//Test to!string of eval delimers
	alias render = Temple!(`<%= "foo" %>`);
	auto accum = appender!string();
	render(accum);
	assert(accum.data == "foo");
}

unittest
{
	// Test delimer parsing
	alias render = Temple!("<% if(true) { %>foo<% } %>");
	auto accum = appender!string();
	render(accum);
	assert(accum.data == "foo");
}
unittest
{
	//Test raw text with no delimers
	alias render = Temple!(`foo`);
	auto accum = appender!string();
	render(accum);
	assert(accum.data == "foo");
}

unittest
{
	//Test looping
	const templ = `<% foreach(i; 0..3) { %>foo<% } %>`;
	alias render = Temple!templ;
	auto accum = appender!string();
	render(accum);
	assert(accum.data == "foofoofoo");
}

unittest
{
	//Test looping
	const templ = `<% foreach(i; 0..3) { %><%= i %><% } %>`;
	alias render = Temple!templ;
	auto accum = appender!string();
	render(accum);
	assert(accum.data == "012");
}

unittest
{
	//Test escaping of "
	const templ = `"`;
	alias render = Temple!templ;
	auto accum = appender!string();
	render(accum);
	assert(accum.data == `"`);
}

unittest
{
	//Test escaping of '
	const templ = `'`;
	alias render = Temple!templ;
	auto accum = appender!string();
	render(accum);
	assert(accum.data == `'`);
}

unittest
{
	// Test shorthand
	const templ = `
		% if(true) {
			Hello!
		% }
	`;
	alias render = Temple!(templ);
	auto accum = appender!string();
	render(accum);
	assert(isSameRender(accum.data, "Hello!"));
}

unittest
{
	// Test shorthand string eval
	const templ = `
		% if(true) {
			%= "foo"
		% }
	`;
	alias render = Temple!(templ);
	auto accum = appender!string();
	render(accum);
	assert(isSameRender(accum.data, "foo"));
}
unittest
{
	// Test shorthand only after newline
	const templ = `foo%bar`;
	alias render = Temple!(templ);
	auto accum = appender!string();
	render(accum);
	assert(accum.data == "foo%bar");
}

unittest
{
	// Ditto
	const templ = `<%= "foo%bar" %>`;
	alias render = Temple!(templ);
	auto accum = appender!string();

	render(accum);
	assert(accum.data == "foo%bar");
}

unittest
{
	auto params = TempleContext();
	params.foo = 123;
	params.bar = "test";

	const templ = `<%= var("foo") %> <%= var("bar") %>`;
	alias render = Temple!templ;
	auto accum = appender!string();

	render(accum, params);
	assert(accum.data == "123 test");
}

unittest
{
	// Loading templates from a file
	alias render = TempleFile!"../test/test1.emd";
	auto accum = appender!string();
	auto compare = readText("test/test1.emd.txt");

	render(accum);
	assert(isSameRender(accum.data, compare));
}

unittest
{
	alias render = TempleFile!"../test/test2.emd";
	auto compare = readText("test/test2.emd.txt");
	auto accum = appender!string();

	auto ctx = TempleContext();
	ctx.name = "dymk";
	ctx.will_work = true;

	render(accum, ctx);
	assert(isSameRender(accum.data, compare));
}

unittest
{
	alias render = TempleFile!"../test/test3_nester.emd";
	auto compare = readText("test/test3.emd.txt");
	auto accum = appender!string();

	render(accum);
	assert(isSameRender(accum.data, compare));
}

unittest
{
	alias render = TempleFile!"../test/test4_root.emd";
	auto compare = readText("test/test4.emd.txt");
	auto accum = appender!string();

	auto ctx = TempleContext();
	ctx.var1 = "this_is_var1";

	render(accum, ctx);
	assert(isSameRender(accum.data, compare));
}