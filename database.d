module adbi.database;

import std.stdio;

/++
Represents a database connection
+/
abstract class Database {
	/++
	The subclass should call this constructor $(em after) the database connection has been established.
	+/
	this() {
		updateSchema();
	}
	
	/++
	Returns a query object for the provided statement
	+/
	Query query(const(char)[] statement);
	/++
	A hash table of all tables in the database
	Should never be modified by the user
	+/
	Table[string] tables;
	
	/++
	Updates the database object to reflect changes in the database's schema
	
	This should be called every time the database schema changes in a way that would affect this object
	(such as when a table is created).
	+/
	void updateSchema();
	
	abstract class Table {
		this(const(char)[] name) {
			_name = name;
			updateSchema();
		}
		
		void updateSchema();
		
		@property const(char)[] name() const {
			return _name;
		}
		const(char)[][] columnNames;
		size_t[string] columnIndices;
		
		private:
		const(char)[] _name;
	}
}

struct Column {
	size_t index;
	string name;
}

enum QueryStatus {
	hasData, finished, busy
}

interface Query {
	QueryStatus advance();
	void reset();
	@property size_t numColumns();
	
	void bind(size_t index, int value);
	void bind(size_t index, long value);
	void bind(size_t index, double value);
	void bind(size_t index, const(char)[] text);
	void bind(size_t index, const(void)[] blob);
	
	int getInt(size_t index);
	long getLong(size_t index);
	double getFloat(size_t index);
	const(char)[] getText(size_t index);
	const(void)[] getBlob(size_t index);
	
	string getColumnName(size_t index);
}
