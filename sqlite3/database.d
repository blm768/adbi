module adbi.sqlite3.database;

import etc.c.sqlite3;
import std.array;
import std.conv;
import std.variant;
import std.string;
import std.traits;

public import adbi.database;

pragma(lib, "sqlite3");

class Sqlite3Database: Database {
	this(const(char)[] filename) {
		int status = sqlite3_open(filename.toStringz, &connection);
		if(status) {
			//The cast is hacky, but it seems to be needed for now. Ick.
			throw new Sqlite3Error(status, "Unable to open database " ~ cast(immutable)filename);
		}
	}
	
	Query query(const(char)[] statement) {
		auto q = new Sqlite3Query;
		q.statement = compileStatement(statement);
		return q;
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
		QueryStatus advance() {
			int status = sqlite3_step(statement);
			with(QueryStatus) switch(status) {
				case SQLITE_BUSY:
					return busy;
				case SQLITE_DONE:
					return finished;
				case SQLITE_ROW:
					return hasData;
				default:
					throw new Sqlite3Error(status, "Error while evaluating statement");
			}
		}
		
		@property size_t numCols() {
			return cast(size_t)sqlite3_column_count(statement);
		}
		
		void bind(size_t index, int value) {
			int status = sqlite3_bind_int(statement, index, value);
			if(status)
				{throw new Sqlite3BindError(status, value);}
		}
		
		void bind(size_t index, double value) {
			int status = sqlite3_bind_double(statement, index, value);
			if(status)
				{throw new Sqlite3BindError(status, value);}
		}
		
		void bind(size_t index, const(char)[] text) {
			//To do: optimize.
			int status = sqlite3_bind_text(statement, index, text.ptr, cast(int)text.length, SQLITE_TRANSIENT);
			if(status)
				{throw new Sqlite3BindError(status, text);}
		}
		
		void bind(size_t index, const(void)[] blob) {
			int status = sqlite3_bind_blob(statement, index, blob.ptr, cast(int)blob.length, SQLITE_TRANSIENT);
			if(status)
				{throw new Sqlite3BindError(status, blob);}
		}
		
		long getInt(size_t index) {
			return cast(long)sqlite3_column_int64(statement, index);
		}
		
		double getFloat(size_t index) {
			return sqlite3_column_double(statement, index);
		}
		
		const(char)[] getText(size_t index) {
			return sqlite3_column_text(statement, index)[0 .. sqlite3_column_bytes(statement, index)];
		}
		
		const(void)[] getBlob(size_t index) {
			return sqlite3_column_blob(statement, index)[0 .. sqlite3_column_bytes(statement, index)];
		}
		
		const(char)[] getColumnName(size_t index) {
			return sqlite3_column_name(statement, index).to!string;
		}
	
		~this() {
			sqlite3_finalize(statement);
		}
		
		private:
		sqlite3_stmt* statement;
	}
	
	protected:
	sqlite3_stmt* compileStatement(const(char)[] statement) {
		sqlite3_stmt* s;
		int status = sqlite3_prepare_v2(connection, statement.ptr, statement.length, &s, null);
		if(status) {
			throw new Sqlite3Error(status, "");
		}
		return s;
	}
	
	private:
	sqlite3* connection;
}

class Sqlite3Error: Error {
	this(int code, string msg) {super("Sqlite error " ~ to!string(code) ~ ": " ~ msg);}
}

class Sqlite3BindError: Sqlite3Error {
	this(T)(int code, T value) {
		super(code, `Unable to bind value "` ~ value.to!string);
	}
}