module adbi.database;

import std.stdio;

public import adbi.table;

abstract class Database {
	Query query(const(char)[] statement);
	TableSet tables;
}

class Column {
	string name;
}

enum QueryStatus {
	hasData, finished, busy
}

interface Query {
	QueryStatus advance();
	@property size_t numCols();
	
	void bind(size_t index, int value);
	void bind(size_t index, double value);
	void bind(size_t index, const(char)[] text);
	void bind(size_t index, const(void)[] blob);
	
	long getInt(size_t index);
	double getFloat(size_t index);
	const(char)[] getText(size_t index);
	const(void)[] getBlob(size_t index);
	
	const(char)[] getColumnName(size_t index);
}

interface TableSet {
	Table opIndex(const(char)[] name);
}
