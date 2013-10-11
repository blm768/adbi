module adbi.model.model;

public import core.exception;
//import std.array;
//import std.conv;
import std.range;
import std.string;

public import adbi.database;
public import adbi.traits;
public import adbi.statements;

public import adbi.model.association;
public import adbi.model.join;
public import adbi.model.relation;

/++
Mixin template that makes a struct act as a model
+/
mixin template Model(string _tableName) {
	enum string tableName = _tableName;

	//TODO: how to handle models with no fields?
	static immutable(string[]) columnNames = ["id", TupleMap!(toColumnName, fields!())];
	static const(char)[][] columnTypes;
	
	/++
	Returns the database with which this model is associated
	+/
	static @property Database database() {
		return saveQuery.database;
	}

	static Query query(const(char)[] statement) {
		return database.query(statement);
	}

	static @property Relation!(typeof(this)) all() {
		return Relation!(typeof(this))();
	}

	//TODO: figure out why aliasing causes a stack overflow.
	//alias all this;
	
	private:
	static Query saveQuery;
	static Query updateQuery;
	static Query createQuery;
	
	public:
	/++
	Returns the record's ID (corresponding to the primary key)

	TODO: make type of ID configurable?
	+/
	@property RecordID id() {
		return _id;
	}
	
	/++
	Returns true if the record has been saved to the database
	
	Note that this only checks the record object to see if it has
	an ID: it doesn't perform a database query.
	+/
	@property bool persisted() {
		//To do: verify that this works for all DBs.
		return id != 0;
	}

	static void createTable(Database db) {
		updateColumns();
		db.createTable(tableName, columnNames, columnTypes);
	}

	/++
	Saves the record to the database.
	
	If the record already exists in the database, the corresponding row will be updated.
	+/
	void save() {
		if(persisted) {
			updateQuery.reset();
			size_t i = 0;
			foreach(fieldName; fields!()) {
				mixin("alias this." ~ fieldName ~ " field;");
				updateQuery.bindValueAt(i, field);
				++i;
			}
			updateQuery.bindAt(i, id);
			assert(updateQuery.advance() == QueryStatus.finished);
		} else {
			saveQuery.reset();
			size_t i = 0;
			foreach(fieldName; fields!()) {
				mixin("alias this." ~ fieldName ~ " field;");
				saveQuery.bindValueAt(i, field);
				++i;
			}
			saveQuery.advance();
			_id = database.lastInsertedRowID;
		}
	}

	
	//To do: semantics of deleting an object that's not in the database?
	void destroy() {
		if(id > 0) {
			//auto q = 
			assert(false);
		} else {
			throw new Error("Attempt to delete object that was never saved");
		}
	}
	
	private:
	@PrimaryKey
	RecordID _id;
	
	public:
	/++
	Creates an instance of the model from the query object's current result
	+/
	static typeof(this) fromQuery(Query q, size_t startIndex = 0) in {
		assert(q);
	 } body {
		if(q.status == QueryStatus.notStarted)
			{q.advance();}
		assert(q.status == QueryStatus.hasData, "Attempt to retrieve data from a query with no data");

		size_t i = startIndex;
		//_id = q.get!RecordID(i);
		//++i;
		typeof(this) instance;
		foreach(fieldName; TypeTuple!("_id", fields!())) {
			mixin("alias instance." ~ fieldName ~ " field;");
			__traits(getMember, instance, fieldName) = q.get!(typeof(field))(i);
			++i;
		}
		return instance;
	}

	static void updateColumns() {
		//If we've already run this, just return.
		if(columnTypes.length > 0) {
			return;
		}
		columnTypes = ["integer primary key"];
		enum typeof(this) instance = typeof(this).init;
		foreach(fieldName; fields!()) {
			mixin("alias instance." ~ fieldName ~ " field;");
			columnTypes ~= columnType!(field);
		}
	}
	
	/++
	Associates this model with a database, creating internal structures to accelerate data retrieval
	
	This function must be called before the model can be used for any queries.
	+/
	static void updateSchema(Database db) {
		updateColumns();
		auto t = db.tables.get(tableName, null);
		if(!t) {
			throw new TableNotFoundException("Table " ~ tableName ~ " not found");
		}
		enum typeof(this) instance = typeof(this).init;
		foreach(fieldName; TypeTuple!("_id", fields!())) {
			mixin("alias instance." ~ fieldName ~ " field;");
			alias toColumnName!fieldName colName;
			auto col = colName in t.columnIndices;
			//Is this column actually in the table?
			if(!col) {
				throw new Exception("Column " ~ colName ~ " does not exist in table " ~ tableName ~ ".");
			}
		}
		saveQuery = db.query(insertClause(tableName, columnNames[1 .. $]));
		updateQuery = db.query(updateClause(tableName, columnNames[1 .. $]) ~ " WHERE id=?");
	}

	//TODO: make pure?
	string toString() {
		import std.array;
		import std.conv;
		auto text = appender(typeof(this).stringof ~ "(");
		foreach(i, field; fields!()) {
			mixin("alias this." ~ field ~ " value;");
			text.put(field);
			text.put(": ");
			text.put(value.to!string());
			static if(i < (fields!().length - 1)) {
				text.put(", ");
			}
		}
		text.put(")");
		return text.data;
	}

	template toColumnName(string memberName) {
		static if(memberName[0] == '_') {
			enum string toColumnName = memberName[1 .. $];
		} else {
			enum string toColumnName = memberName;
		}
	}

	template isField(string name) {
		alias Attributes!(__traits(getMember, typeof(this), name)) attributes;
		enum bool isField = tupleContains!(isFieldAttribute, attributes);
	}
	
	template fields() {
		private alias memberNames!(typeof(this)) names;
		alias TupleFilter!(isField, names) fields;
	}
}

class TableNotFoundException: Exception {
	this(string msg) { super(msg); }
}

enum Field;
//To do: actually make this do something?
enum PrimaryKey;
enum Indexed;

template isFieldAttribute(alias att) {
	enum isFieldAttribute = __traits(isSame, att, Field);
}

template columnType(alias value) {
	alias columnBaseType!(typeof(value)) columnType;
}

template columnBaseType(T: Nullable!T) {
	enum columnBaseType = columnBaseType!T;
}

template columnBaseType(T) if(isIntegral!T && !isSigned!T) {
	enum columnBaseType = "unsigned " ~ columnBaseType(Signed!T);
}

template columnBaseType(T: int) {
	enum columnBaseType = "integer";
}

template columnBaseType(T: long) {
	enum columnBaseType = "integer";
}

template columnBaseType(T) if(is(T: const(char)[])) {
	enum columnBaseType = "varchar";
}

template columnBaseType(T: immutable(void)[]) {
	enum columnBaseType = "blob";
}

/++
Represents a range of models from a query
+/
struct ModelRange(T) {
	alias T Model;

	this(Query q) {
		query = q;
	}

	Query query;
	
	///
	@property Model front() {
		if(empty) {
			//TODO: throw something else?
			throw new RangeError;
		} else {
			//TODO: cache?
			return Model.fromQuery(query);
		}
	}
	
	void popFront() {
		if(empty) {
			throw new RangeError;
		} else {
			query.advance();
		}
	}
	
	///
	@property bool empty() {
		if(query.status == QueryStatus.notStarted) {
			query.advance();
		}
		//TODO: change to "query.status == QueryStatus.finished"?
		return query.status != QueryStatus.hasData;
	}
}

