module adbi.database;

public import std.typecons;

import std.algorithm;
import std.conv;
import std.string;

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

//TODO: handle QueryStatus.busy?
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
	void bindNullAt(size_t index);

	/**
	Like bindAt, but handles std.typecons.Nullable correctly

	TODO: rename? (to bindNullableAt?)
	*/
	void bindValueAt(T)(size_t index, T value) {
		static if(isNullable!T) {
			if(value.isNull) {
				bindNullAt(index);
				return;
			}
		}
		//TODO: just alias to the bindAt functions rather than
		//calling them?
		//(could be faster, but if the optimizer inlines the
		//outer call, there should be no speed difference.)
		bindAt(index, value);
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

	template get(T) if(is(T: const(char)[])) {
		alias getString get;
	}

	T get(T: string)(size_t index) {
		return cast(immutable)getString(index);
	}

	//The "is" expression is reversed because any
	//array would be implicitly convertible to a void[].
	template get(T) if(is(void[]: T)) {
		alias getBlob get;
	}

	T get(T: immutable(void)[])(size_t index) {
		return cast(immutable)getBlob(index);
	}

	template NullableType(T: Nullable!T) {
		alias NullableType = T;
	}

	//Currently broken due to DMD bug 11190
	version(none) {
		Nullable!T get(T: Nullable!T)(size_t index) {
			if(columnIsNull(index)) {
				return Nullable!T();
			} else {
				return Nullable!T(get!T(index));
			}
		}
	}

	int getInt(size_t index);
	uint getUInt(size_t index);
	long getLong(size_t index);
	ulong getULong(size_t index);
	double getDouble(size_t index);
	char[] getString(size_t index);
	void[] getBlob(size_t index);

	bool columnIsNull(size_t index);
	
	string getColumnName(size_t index);
}

alias TupleMap!(BinderTypeOf, __traits(getOverloads, Query, "bindAt")) QueryBinderTypes;

template BinderTypeOf(alias method) {
	private alias ParameterTypeTuple!(method)[1] secondArgType;
	static if(is(secondArgType: BindValue)) {
		alias BinderTypeOf = TypeTuple!();
	} else {
		alias BinderTypeOf = secondArgType;
	}
}

//Used internally by BindValue
private struct BindHandler {
	static void doBind(T)(Query q, size_t index, const(void)* data) {
		q.bindValueAt(index, *(cast(const(T)*)data));
	}

	//TODO: special handling for types that are already strings?
	static string doStringize(T)(const(void)* data) {
		return (*(cast(const(T)*)data)).to!string();
	}

	void function(Query, size_t, const(void)*) binder;
	string function(const(void)*) stringizer;

	template handlerFor(T) {
		static immutable handlerFor = BindHandler(
			&BindHandler.doBind!T,
			&BindHandler.doStringize!T,
		);
	}
}

/**
Represents a value to be bound to a query

Works a bit like a Variant (but much more specialized)
*/
struct BindValue {
	/**
	The maximum size of value a BindValue can hold

	TODO: make room for Nullable's extra boolean field in a less hackish way.
	*/
	enum maxSize = max(TupleMap!(sizeOf, QueryBinderTypes)) + bool.sizeof;

	/**
	Initializes this BindValue from a given value
	*/
	this(T)(T value) if(T.sizeof <= maxSize) {
		*(cast(T*)ptr) = value;
		_handler = &BindHandler.handlerFor!T;
	}

	/**
	Binds this value to a Query
	*/
	void bindTo(Query q, size_t index) const {
		_handler.binder(q, index, ptr);
	}

	///
	string toString() const {
		return _handler.stringizer(ptr);
	}

	/**
	Returns a pointer to the data
	*/
	@property const(void)* ptr() const {
		return cast(const(void*))&_data;
	}

	private:
	void[maxSize] _data = void;
	immutable(BindHandler)* _handler;
}

