module adbi.statements;

import std.algorithm;
import std.conv;
import std.range;
import std.string;

string whereClause(const(char[])[] conditions) {
	return " WHERE " ~ conditions.map!(s => "(%s)".format(s))().join(" AND ");
}

string insertStatement(const(char)[] table, const(char[])[] columns) {
	auto cols = columns.map!(s => s[])();
	return "INSERT INTO %s (%s) VALUES (%s)".format(table, cols.join(","), std.range.repeat("?", columns.length).join(","));
}

string updateStatement(const(char)[] table, const(char[])[] columns) {
	auto cols = columns.map!(s => s[])();
	return "UPDATE %s SET %s=?".format(table, cols.join("=?, "));
}

string selectStatement(const(char)[] table, const(char[])[] columns ...) {
	auto cols = columns.map!(s => s[])();
	return "SELECT %s FROM %s".format(cols.join(", "), table);
}
