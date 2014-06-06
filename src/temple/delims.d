/**
 * Temple (C) Dylan Knutson, 2013, distributed under the:
 * Boost Software License - Version 1.0 - August 17th, 2003
 *
 * Permission is hereby granted, free of charge, to any person or organization
 * obtaining a copy of the software and accompanying documentation covered by
 * this license (the "Software") to use, reproduce, display, distribute,
 * execute, and transmit the Software, and to prepare derivative works of the
 * Software, and to permit third-parties to whom the Software is furnished to
 * do so, all subject to the following:
 *
 * The copyright notices in the Software and this entire statement, including
 * the above license grant, this restriction and the following disclaimer,
 * must be included in all copies of the Software, in whole or in part, and
 * all derivative works of the Software, unless such copies or derivative
 * works are solely in the form of machine-executable object code generated by
 * a source language processor.
 */

module temple.delims;

import
	std.traits,
	std.typecons;

/// Represents a delimer and the index that it is located at
template DelimPos(D = Delim)
{
	alias DelimPos = Tuple!(ptrdiff_t, "pos", D, "delim");
}

/// All of the delimer types parsed by Temple
enum Delim
{
	OpenShort,
	OpenShortStr,
	Open,
	OpenStr,
	CloseShort,
	Close
}

enum Delims = [EnumMembers!Delim];

/// Subset of Delims, only including opening delimers
enum OpenDelim  : Delim
{
	OpenShort       = Delim.OpenShort,
	Open            = Delim.Open,
	OpenShortStr    = Delim.OpenShortStr,
	OpenStr         = Delim.OpenStr
};
enum OpenDelims = [EnumMembers!OpenDelim];

/// Subset of Delims, only including close delimers
enum CloseDelim : Delim
{
	CloseShort = Delim.CloseShort,
	Close      = Delim.Close
}
enum CloseDelims = [EnumMembers!CloseDelim];

/// Maps an open delimer to its matching closing delimer
/// Formally, an onto function
enum OpenToClose =
[
	OpenDelim.OpenShort    : CloseDelim.CloseShort,
	OpenDelim.OpenShortStr : CloseDelim.CloseShort,
	OpenDelim.Open         : CloseDelim.Close,
	OpenDelim.OpenStr      : CloseDelim.Close
];

string toString(in Delim d)
{
	final switch(d) with(Delim)
	{
		case OpenShort:     return "%";
		case OpenShortStr:  return "%=";
		case Open:          return "<%";
		case OpenStr:       return "<%=";
		case CloseShort:    return "\n";
		case Close:         return "%>";
	}
}

/// Is the delimer a shorthand delimer?
/// e.g., `%=`, or `%`
bool isShort(in Delim d)
{
	switch(d) with(Delim)
	{
		case OpenShortStr:
		case OpenShort   : return true;
		default: return false;
	}
}

unittest {
	static assert(Delim.OpenShort.isShort() == true);
	static assert(Delim.Close.isShort() == false);
}

/// Is the contents of the delimer evaluated and appended to
/// the template buffer? E.g. the content within `<%= %>` delims
bool isStr(in Delim d)
{
	switch(d) with(Delim)
	{
		case OpenShortStr:
		case OpenStr     : return true;
		default: return false;
	}
}

unittest
{
	static assert(Delim.OpenShort.isStr() == false);
	static assert(Delim.OpenShortStr.isStr() == true);
}
