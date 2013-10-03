module adbi.database;

import std.string;
import std.traits;
import std.typetuple;
public import std.variant;

public import adbi.traits;

alias ulong RecordID;

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
	@property RecordID lastInsertedRowID();
	
	/++
	A hash table of all tables in the database
	Should never be modified by the user
	+/
	Table[string] tables;

	void createTable(const(char[]) name, const(char[][]) columnNames, const(char[][]) columnTypes) in {
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
			this.updateSchema();
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
	void bindAt(size_t index, uint value);
	void bindAt(size_t index, long value);
	void bindAt(size_t index, ulong value);
	void bindAt(size_t index, double value);
	void bindAt(size_t index, const(char)[] value);
	void bindAt(size_t index, const(void)[] value);
	void bindAt(size_t index, Variant value);
	
	void bind(T...)(T args) {
		foreach(i, value; args) {
			bindAt(i, value);
		}
	}
	
	template get(T: int) {
		alias getInt get;
	}

	template get(T: uint) {
		alias getUInt get;
	}

	template get(T: long) {
		alias getLong get;
	}

	template get(T: ulong) {
		alias getULong get;
	}
	
	template get(T: double) {
		alias getDouble get;
	}

	template get(T: char[]) {
		alias getString get; 
	}

	T get(T: string)(size_t index) {
		return cast(string)getString(index);
	}

	template get(T: void[]) {
		alias getBlob get;
	}

	int getInt(size_t index);
	uint getUInt(size_t index);
	long getLong(size_t index);
	ulong getULong(size_t index);
	double getDouble(size_t index);
	char[] getString(size_t index);
	void[] getBlob(size_t index);
	
	string getColumnName(size_t index);
}

template BindTypesOf(T) if(is(T: Query)) {
	alias TemplateMap!(BindTypeOf, __traits(getOverloads, T, "bindAt")) BindTypesOf;
}

template BindTypeOf(alias method) {
	alias ParameterTypeTuple!(method)[1] BindTypeOf;
}

pragma(msg, TemplateMap!(Stringize, BindTypesOf!(Query)));

/**
For use by Query objects

Implements bindAt!(size_t, Variant)
*/
mixin template bindVariant() {
	void bindAt(size_t index, Variant value) {
		assert(false);
	}
}
