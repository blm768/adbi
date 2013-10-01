module adbi.model.model;

public import core.exception;
public import std.array;
import std.string;

public import adbi.database;
public import adbi.model.traits;
public import adbi.querybuilder;

public import adbi.model.join;
public import adbi.model.relation;

alias ulong RecordId;

/++
Mixin template that makes a struct act as a model
+/
mixin template Model(string _tableName) {
	enum string tableName = _tableName;

	//TODO: make fixed-length?
	static immutable(string[]) columnNames = [fields!(typeof(this))];
	static const(char)[][] columnTypes;
	
	/++
	Returns the database with which this model is associated
	+/
	static @property Database database() {
		return saveQuery.database;
	}
	
	private:
	static Query saveQuery;
	static Query updateQuery;
	static Query createQuery;
	
	public:
	/++
	Returns the record's ID (corresponding to the primary key)

	TODO: make type of ID configurable?
	+/
	@property RecordId id() {
		return _id_;
	}
	
	static @property Relation!(typeof(this)) all() {
		return Relation!(typeof(this))(builder());
	}

	//TODO: figure out why aliasing causes a stack overflow.
	//alias all this;
	
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
		db.createTable(tableName, "id" ~ columnNames, "integer primary key" ~ columnTypes);
	}

	//To do: versions that are told if the object exists in the database?
	/++
	Saves the record to the database.
	
	If the record already exists in the database, the corresponding row will be updated.
	+/
	void save() {
		if(persisted) {
			//To do: update columns.
			updateQuery.reset();
			size_t i = 0;
			foreach(memberName; members!(typeof(this))) {
				mixin("alias this." ~ memberName ~ " member;");
				static if(isField!member) {
					static if(memberName != "_id_") {
						updateQuery.bindAt(i, member);
						++i;
					}
				}
			}
			updateQuery.bindAt(i, id);
			assert(updateQuery.advance() == QueryStatus.finished);
			//TODO: remove?
			updateQuery.reset();
		} else {
			saveQuery.reset();
			size_t i = 0;
			foreach(memberName; members!(typeof(this))) {
				mixin("alias this." ~ memberName ~ " member;");
				static if(isField!member) {
					static if(memberName != "_id_") {
						saveQuery.bindAt(i, member);
						++i;
					}
				}
			}
			//TODO: replace these assertions!
			assert(saveQuery.advance() == QueryStatus.finished);
			//To do: remove?
			saveQuery.reset();
			_id_ = database.lastInsertedRowId;
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
	RecordId _id_;
	
	public:
	/++
	Creates an instance of the model from the query object's current result
	+/
	static typeof(this) fromQuery(Query q, size_t startIndex = 0) in {
		assert(q);
	 } body {
		if(q.status == QueryStatus.notStarted)
			{q.advance();}
		//TODO: better error message?
		assert(q.status == QueryStatus.hasData, "Attempt to retrieve data from a query with no valid data available");
		size_t i = startIndex;
		typeof(this) instance;
		foreach(memberName; members!(typeof(this))) {
			mixin("alias instance." ~ memberName ~ " member;");
			static if(isField!member) {
				//For some reason, we can't just assign to member, and &member doesn't work.
				auto ptr = &__traits(getMember, instance, memberName);
				*ptr = q.get!(typeof(member))(i);
				++i;
			}
		}
		return instance;
	}

	static void updateColumns() {
		//If we've already run this, just return.
		if(columnTypes.length > 0) {
			return;
		}
		enum typeof(this) instance = typeof(this).init;
		foreach(memberName; members!(typeof(this))) {
			mixin("alias instance." ~ memberName ~ " member;");
			static if(isField!member) {
				alias toColumnName!memberName colName;
				static if(is(typeof(colName) == string)) {
					//We exclude the id column for convenience when implementing some of the queries.
					static if(memberName != "_id_") {
						columnTypes ~= columnType!(member);
					}
				}
			}
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
		size_t i = 0;
		enum typeof(this) instance = typeof(this).init;
		foreach(memberName; members!(typeof(this))) {
			mixin("alias instance." ~ memberName ~ " member;");
			//Is this an instance member?
			//To do: test; this might not always work.
			static if(isField!member) {
				alias toColumnName!memberName colName;
				//Does this member map to a column?
				static if(is(typeof(colName) == string)) {
					auto col = colName in t.columnIndices;
					//Is this column actually in the table?
					if(!col) {
						throw new Exception("Column " ~ toColumnName!memberName ~ " does not exist in table " ~ tableName ~ ".");
					}
				}
				++i;
			}
		}
		QueryBuilder saveBuilder = builder();
		saveBuilder.operation = QueryBuilder.Operation.insert;
		saveQuery = db.query(saveBuilder.statement);
		QueryBuilder updateBuilder = builder();
		updateBuilder.operation = QueryBuilder.operation.update;
		updateBuilder.conditions = ["id = ?"];
		updateQuery = db.query(updateBuilder.statement);
	}

	static QueryBuilder builder() {
		QueryBuilder b;
		b.table = tableName;
		//To do: remove cast if possible.
		b.columns = cast(const(char)[][])columnNames;
		return b;
	}

	//TODO: improve?
	template toColumnName(string memberName) {
		static if(memberName[0] == '_') {
			static if(memberName[$ - 1] == '_') {
				enum string toColumnName = memberName[1 .. $ - 1];
			} else {
				alias void toColumnName;
			}
		} else {
			enum string toColumnName = memberName;
		}
	}
}

class TableNotFoundException: Exception {
	this(string msg) { super(msg); }
}

//To do: actually make this do something?
enum PrimaryKey;
enum Indexed;

template columnType(alias value) {
	alias columnBaseType!(typeof(value)) columnType;
}

template columnBaseType(T) {}

template columnBaseType(T) if(isIntegral!T && !isSigned!T) {
	enum columnBaseType = "unsigned " + columnBaseType(Signed!T);
}

template columnBaseType(T: int) {
	enum columnBaseType = "integer";
}

template columnBaseType(T: long) {
	enum columnBaseType = "integer";
}

template columnBaseType(T: char[]) {
	enum columnBaseType = "varchar";
}

template columnBaseType(T: immutable(void)[]) {
	enum columnBaseType = "blob";
}

/++
When mixed into a model, this creates a relational link to another model using a foreign key
+/
mixin template reference(T, string name) {
	static private Query referenceQuery;
	mixin("RecordId " ~ name ~ "_id;");
	mixin("@property T " ~ name ~ `(){
		if(!referenceQuery) {
			referenceQuery = database.query("SELECT * FROM " ~ T.tableName ~ " WHERE id = ? LIMIT 1;");
		}
		referenceQuery.reset();
		referenceQuery.bind(` ~ name ~ `_id);
		return T.fromQuery(referenceQuery);
	}`);
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
		//TODO: cache?
		return Model.fromQuery(query);
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
		return query.status != QueryStatus.hasData;
	}
}

