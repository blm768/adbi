module adbi.statements;

import std.algorithm;
import std.array;
import std.conv;
import std.range;
import std.string;

//TODO: use immutable(char)[] where possible?
const(char)[] buildStatement(const(char)[] base, const(char)[][] clauses ...) pure {
	auto app = appender(base);
	foreach(clause; clauses) {
		if(clause.length) {
			app.put(" ");
			app.put(clause);
		}
	}
	return app.data;
}

unittest {
	assert(buildStatement("testing", "1", "2", "3") == "testing 1 2 3");
	assert(buildStatement("testing") == "testing");
}

string whereClause(const(char[])[] conditions) pure {
	if(conditions.length) {
		return " WHERE " ~ conditions.map!(s => "(%s)".format(s))().join(" AND ");
	} else {
		return "";
	}
}

unittest {
	assert(whereClause([]) == "");
}

string insertStatement(const(char)[] table, const(char[])[] columns) pure {
	auto cols = columns.map!(s => s[])();
	return "INSERT INTO %s (%s) VALUES (%s)".format(table, cols.join(","), std.range.repeat("?", columns.length).join(","));
}

unittest {

}

string updateStatement(const(char)[] table, const(char[])[] columns) pure {
	auto cols = columns.map!(s => s[])();
	return "UPDATE %s SET %s=?".format(table, cols.join("=?, "));
}

unittest {
	
}

string selectStatement(const(char)[] table, const(char[])[] columns ...) pure {
	auto cols = columns.map!(s => s[])();
	return "SELECT %s FROM %s".format(cols.join(", "), table);
}

unittest {

}
