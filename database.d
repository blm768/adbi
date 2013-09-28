module adbi.database;

import std.stdio;
import std.string;

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
	Starts a transaction
	+/
	void startTransaction();
	
	/++
	Commits the current transaction
	+/
	void commit();
	
	/++
	Rolls back the current transaction
	+/
	void rollBack();
		
	/++
	Returns the ID of the last row that was inserted
	+/
	@property size_t lastInsertedRowId();
	
	/++
	A hash table of all tables in the database
	Should never be modified by the user
	+/
	Table[string] tables;

	void createTable(string name, string[] columnNames, string[] columnTypes) in {
		//To do: make more error-safe?
		assert(columnNames.length == columnTypes.length);
	} body {
		string s = "CREATE TABLE %s (".format(name);
		foreach(i, colName; columnNames[0 .. $-1]) {
			s ~= "%s %s,".format(colName, columnTypes[i]);
		}
		//This will be a problem if the lengths don't match.
		s ~= "%s %s".format(columnNames[$-1], columnTypes[$-1]);
		s ~= ")";

		auto q = query(s);
		q.advance();

		updateSchema();
	}

	bool tableExists(string name);

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
	notStarted, hasData, finished, busy
}

struct Index {
	string name;
	string[] columns;

	void create(Database db) {
		
	}
}

interface Query {
	QueryStatus advance();
	@property QueryStatus status();
	void reset();
	@property size_t numColumns();
	@property const(char)[] statement();
	@property Database database();
	
	void bindAt(size_t index, int value);
	void bindAt(size_t index, long value);
	void bindAt(size_t index, double value);
	void bindAt(size_t index, const(char)[] text);
	void bindAt(size_t index, const(void)[] blob);
	
	void bind(T...)(T args) {
		foreach(i, value; args) {
			bindAt(i, value);
		}
	}
	
	template get(T: int) {
		alias getInt get;
	}
	
	template get(T: long) {
		alias getLong get;
	}
	
	template get(T: double) {
		alias getDouble get;
	}
	
	template get(T: string) {
		alias getString get; 
	}
	
	template get(T: immutable(void)[]) {
		alias getBlob get;
	}
	
	int getInt(size_t index);
	long getLong(size_t index);
	double getDouble(size_t index);
	string getString(size_t index);
	immutable(void)[] getBlob(size_t index);
	
	string getColumnName(size_t index);
}
