module adbi.sqlite3.database;

import etc.c.sqlite3;
import std.array;
import std.conv;
import std.variant;
import std.string;
import std.traits;

import std.stdio;

public import adbi.database;

pragma(lib, "sqlite3");

class Sqlite3Database: Database {
	this(const(char)[] filename) {
		int status = sqlite3_open(filename.toStringz, &connection);
		if(status) {
			//The cast is hacky, but it seems to be needed for now. Ick.
			throw new Sqlite3Error(status, "Unable to open database " ~ cast(immutable)filename);
		}
		super();
	}
	
	Query query(const(char)[] statement) {
		return new Sqlite3Query(statement);
	}
	
	void updateSchema() {
		Query q = query("SELECT name FROM sqlite_master WHERE type='table';");
		tables.clear();
		while(q.advance() == QueryStatus.hasData) {
			const(char)[] text = q.getText(0);
			tables[text] = new Sqlite3Table(text);
		}
	}
	
	~this() {
		//To do: handle other finalization steps?
		if(connection) {
			//To do: use _v2
			sqlite3_close(connection);
		}
	}
	
	//To do: file bug? (Just calling this Query gives an error.)
	class Sqlite3Query: adbi.database.Query {
		this(const(char)[] statement) {
			_statement = statement;
			_s = compileStatement(statement);
		}
		
		QueryStatus advance() {
			int qStatus = sqlite3_step(_s);
			with(QueryStatus) switch(qStatus) {
				//To do: handle busy case
				case SQLITE_BUSY:
					_status =  busy;
					break;
				case SQLITE_DONE:
					_status =  finished;
					break;
				case SQLITE_ROW:
					_status =  hasData;
					break;
				default:
					_status = finished;
					throw new Sqlite3Error(qStatus, "Error while evaluating statement");
					break;
			}
			assert(_status != QueryStatus.notStarted);
			return _status;
		}
		
		@property QueryStatus status() {
			return _status;
		}
		
		//To do: unit tests to verify that status stays consistent
		void reset() {
			int status = sqlite3_reset(_s);
			if(status)
				{throw new Sqlite3Error(status, "Unable to reset query");}
			_status = QueryStatus.notStarted;
		}
		
		@property size_t numColumns() {
			return cast(size_t)sqlite3_column_count(_s);
		}
		
		@property const(char)[] statement() {
			return _statement;
		}
		
		void bind(size_t index, int value) {
			int status = sqlite3_bind_int(_s, index, value);
			if(status)
				{throw new Sqlite3BindError(status, value);}
		}
		
		void bind(size_t index, long value) {
			int status = sqlite3_bind_int64(_s, index, value);
			if(status)
				{throw new Sqlite3BindError(status, value);}
		}
		
		void bind(size_t index, double value) {
			int status = sqlite3_bind_double(_s, index, value);
			if(status)
				{throw new Sqlite3BindError(status, value);}
		}
		
		void bind(size_t index, const(char)[] text) {
			//To do: optimize.
			int status = sqlite3_bind_text(_s, index, text.ptr, cast(int)text.length, SQLITE_TRANSIENT);
			if(status)
				{throw new Sqlite3BindError(status, text);}
		}
		
		void bind(size_t index, const(void)[] blob) {
			int status = sqlite3_bind_blob(_s, index, blob.ptr, cast(int)blob.length, SQLITE_TRANSIENT);
			if(status)
				{throw new Sqlite3BindError(status, blob);}
		}
		
		//To do: error checking?
		int getInt(size_t index) {
			return cast(long)sqlite3_column_int(_s, index);
		}
		
		long getLong(size_t index) {
			return cast(long)sqlite3_column_int64(_s, index);
		}
		
		double getDouble(size_t index) {
			return sqlite3_column_double(_s, index);
		}
		
		string getText(size_t index) {
			return sqlite3_column_text(_s, index)[0 .. sqlite3_column_bytes(_s, index)].idup;
		}
		
		immutable(void)[] getBlob(size_t index) {
			return sqlite3_column_blob(_s, index)[0 .. sqlite3_column_bytes(_s, index)].idup;
		}
		
		string getColumnName(size_t index) {
			return sqlite3_column_name(_s, index).to!string;
		}
	
		~this() {
			sqlite3_finalize(_s);
		}
		
		private:
		sqlite3_stmt* _s;
		const(char)[] _statement;
		QueryStatus _status;
	}
	
	class Sqlite3Table: Table {
		this(const(char)[] name) {
			super(name);
		}
		
		override void updateSchema() {
			auto q = query("SELECT * FROM " ~ name ~ " LIMIT 0;");
			size_t num = q.numColumns;
			columnNames = uninitializedArray!(const(char)[][])(num);
			columnIndices.clear();
			for(size_t i = 0; i < q.numColumns; ++i) {
				string name = q.getColumnName(i);
				columnNames[i] = name;
				columnIndices[name] = i;
			}
		}
	}

	protected:
	sqlite3_stmt* compileStatement(const(char)[] statement) {
		sqlite3_stmt* s;
		int status = sqlite3_prepare_v2(connection, statement.ptr, statement.length, &s, null);
		if(status) {
			throw new Sqlite3Error(status, cast(immutable)("Unable to compile statement: " ~ statement));
		}
		return s;
	}

	private:
	sqlite3* connection;
}

class Sqlite3Error: Error {
	this(int code, string msg) {super(msg ~ " (Sqlite3 error " ~ to!string(code) ~ ")");}
}

class Sqlite3BindError: Sqlite3Error {
	this(T)(int code, T value) {
		super(code, `Unable to bind value "` ~ value.to!string);
	}
}