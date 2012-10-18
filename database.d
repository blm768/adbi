module adbi.database;

public import adbi.table;

abstract class Database {
	TableSet tables;
	
	/++
	Creates a new Query object to execute a given statement
	+/
	Query query(const(char)[] statement);
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
	long getInt(size_t index);
	double getFloat(size_t index);
	const(char)[] getText(size_t index);
	const(void)[] getBlob(size_t index);
}

interface TableSet {
	Table opIndex(const(char)[] name);
}
