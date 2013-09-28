module adbi.model.model;

public import core.exception;
public import std.array;
import std.string;

public import adbi.database;
public import adbi.traits;
public import adbi.querybuilder;

public import adbi.model.join;

/++
Mixin template that makes a struct act as a model
+/
mixin template Model(string _tableName) {
	enum string tableName = _tableName;
	static string[] columnNames;
	static string[] columnTypes;
	static size_t[] memberToColumn;
	static size_t[] columnToMember;
	
	/++
	Returns the database with which this model is associated
	+/
	static @property Database database() {
		return saveQuery.database;
	}
	
	static ModelQuery!(typeof(this)) query(const(char)[] statement) {
		return ModelQuery!(typeof(this))(database.query(statement));
	}
	
	private:
	static Query saveQuery;
	static Query updateQuery;
	static Query createQuery;
	
	public:
	/++
	Returns the record's ID (corresponding to the primary key)
	+/
	@property size_t id() {
		return _id_;
	}
	
	static @property ModelQueryBuilder!(typeof(this)) all() {
		ModelQueryBuilder!(typeof(this)) q;
		//To do: file bug report? (cast seems like it shouldn't be needed)
		q.columns = cast(const(char)[][])columnNames;
		//To do: escape?
		q.table = tableName;
		return q;
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
			foreach(memberName; __traits(allMembers, typeof(this))) {
				mixin("alias this." ~ memberName ~ " member;");
				static if(isInstanceDataMember!member) {
					static if(memberName != "_id_") {
						updateQuery.bindAt(i, member);
						++i;
					}
				}
			}
			updateQuery.bindAt(i, id);
			assert(updateQuery.advance() == QueryStatus.finished);
			//To do: remove?
			updateQuery.reset();
		} else {
			saveQuery.reset();
			size_t i = 0;
			foreach(memberName; __traits(allMembers, typeof(this))) {
				mixin("alias this." ~ memberName ~ " member;");
				static if(isInstanceDataMember!member) {
					static if(memberName != "_id_") {
						saveQuery.bindAt(i, member);
						++i;
					}
				}
			}
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
		} else {
			throw new Error("Attempt to delete object that was never saved");
		}
	}
	
	private:
	@PrimaryKey
	size_t _id_;
	
	public:
	/++
	Creates an instance of the model from the query object's current result
	+/
	static typeof(this) fromQuery(Query q, size_t startIndex = 0) {
		//To do: clearer message?
		assert(q, "Attempt to retrive " ~ typeof(this).stringof ~ " without a valid query");
		if(q.status == QueryStatus.notStarted)
			{q.advance();}
		assert(q.status == QueryStatus.hasData, "Attempt to retrieve data from a query with no valid data available");
		size_t i = 0;
		typeof(this) instance;
		foreach(memberName; __traits(allMembers, typeof(this))) {
			mixin("alias instance." ~ memberName ~ " member;");
			static if(isInstanceDataMember!member) {
				if(columnToMember[i] < size_t.max) {
					auto ptr = &__traits(getMember, instance, memberName);
					*ptr = q.get!(typeof(member))(memberToColumn[i] + startIndex);
				} else {
					assert(false, "Field " ~ memberName ~ " not present in database");
				}
				++i;
			}
		}
		return instance;
	}

	static void updateColumns() {
		//If we've already run this, just return.
		if(columnNames.length > 0) {
			return;
		}
		enum typeof(this) instance = typeof(this).init;
		foreach(memberName; __traits(allMembers, typeof(this))) {
			mixin("alias instance." ~ memberName ~ " member;");
			static if(isInstanceDataMember!member) {
				alias toColumnName!memberName colName;
				static if(is(typeof(colName) == string)) {
					//We exclude the id column for convenience when implementing some of the queries.
					static if(memberName != "_id_") {
						columnNames ~= toColumnName!memberName;
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
		Database.Table t;
		try {
			t = db.tables[tableName];
		} catch(RangeError e) {
			throw new TableNotFoundException("Table " ~ tableName ~ " not found");
		}
		memberToColumn = [];
		//To do: optimize?
		columnToMember = replicate([size_t.max], t.columnNames.length);
		size_t i = 0;
		enum typeof(this) instance = typeof(this).init;
		foreach(memberName; __traits(allMembers, typeof(this))) {
			mixin("alias instance." ~ memberName ~ " member;");
			//Is this an instance member?
			//To do: test; this might not always work.
			static if(isInstanceDataMember!member) {
				alias toColumnName!memberName colName;
				//Does this member map to a column?
				static if(is(typeof(colName) == string)) {
					auto col = colName in t.columnIndices;
					//Is this column actually in the table?
					if(col) {
						memberToColumn ~= *col;
						columnToMember[*col] = member.offsetof;
					} else {
						throw new Exception("Column " ~ toColumnName!memberName ~ " does not exist in table " ~ tableName ~ ".");
					}
				}
				++i;
			}
		}
		QueryBuilder saveBuilder = builder();
		saveBuilder.operation = QueryBuilder.Operation.insert;
		saveQuery = saveBuilder.query(db);
		QueryBuilder updateBuilder = builder();
		updateBuilder.operation = QueryBuilder.operation.update;
		updateBuilder.conditions = ["id = ?"];
		updateQuery = updateBuilder.query(db);
	}

	static QueryBuilder builder() {
		QueryBuilder b;
		b.table = tableName;
		//To do: remove cast if possible.
		b.columns = cast(const(char)[][])columnNames;
		return b;
	}

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

template columnBaseType(T: int) {
	enum columnBaseType = "integer";
}

template columnBaseType(T: string) {
	enum columnBaseType = "varchar";
}

template columnBaseType(T: immutable(void)[]) {
	enum columnBaseType = "blob";
}

/++
When mixed into a model, this creates a relational link to another model using a foreign key
+/
mixin template reference(string name, string foreignTableName, T) {
	static Query referenceQuery;
	mixin("size_t " ~ name ~ "_id;");
	mixin("@property T " ~ name ~ `(){
		if(!referenceQuery) {
			referenceQuery = database.query("SELECT * FROM " ~ foreignTableName ~ " WHERE id = ? LIMIT 1;");
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
	Query q;
	
	///
	@property T front() {
		return T.fromQuery(q);
	}
	
	///Returns the front and advances the query
	T popFront() {
		T value = front;
		if(q.status == QueryStatus.hasData)
			{q.advance();}
		return value;
	}
	
	///
	@property bool empty() {
		if(q.status == QueryStatus.notStarted)
			{q.advance();}
		return q.status != QueryStatus.hasData;
	}
}

/++
Wraps a Query to include model-specific utilities
+/
struct ModelQuery(T) {
	Query query;
	
	alias query this;
	
	@property bool empty() {
		return results.empty;
	}
	
	@property ModelRange!T results() {
		return ModelRange!T(query);
	}
	
	@property T first() {
		return results.front;
	}
}


