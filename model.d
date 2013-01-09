module adbi.model;

public import core.exception;
public import std.array;
import std.string;

public import adbi.database;
public import adbi.traits;
public import adbi.querybuilder;

/++
Mixin template that makes a struct act as a model
+/
mixin template Model(string _tableName) {
	enum string tableName = _tableName;
	static string[] columnNames;
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
		q.fromClause = tableName;
		return q;
	}
	
	/++
	Returns true if the record is stored in the database, false otherwise
	+/
	@property bool inDatabase() {
		//To do: verify that this works for all DBs.
		if(id == 0)
			{return false;}
		//To do: don't constantly recreate this query.
		auto q = database.query("SELECT * FROM " ~ tableName ~ " WHERE id = ? LIMIT 1;");
		q.bind(id);
		return q.advance() == QueryStatus.hasData;
	}
	
	//To do: versions that are told if the object exists in the database?
	/++
	Saves the record to the database.
	
	If the record already exists in the database, the corresponding row will be updated.
	+/
	void save() {
		//To do: semantics of saving an object that was removed from the database?
		if(inDatabase) {
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
	
	/++
	Associates this model with a database, creating internal structures to accelerate data retrieval
	
	This function must be called before the model can be used for any queries.
	+/
	static void updateSchema(Database db) {
		char[] saveStatement = "INSERT INTO ".dup ~ tableName ~ " (";
		char[] updateStatement = "UPDATE ".dup ~ tableName ~ " SET ";
		columnNames = [];
		Database.Table t;
		try {
			t = db.tables[tableName];
		} catch(RangeError e) {
			throw new Error("Table " ~ tableName ~ " not found");
		}
		memberToColumn.length = 0;
		columnToMember = replicate([size_t.max], t.columnNames.length);
		size_t i = 0;
		enum typeof(this) instance = typeof(this).init;
		foreach(memberName; __traits(allMembers, typeof(this))) {
			mixin("alias instance." ~ memberName ~ " member;");
			//Is this an instance member?
			//To do: test; this might not always work.
			static if(isInstanceDataMember!member) {
				auto col = toColumnName!memberName in t.columnIndices;
				if(col) {
					memberToColumn ~= *col;
					columnToMember[*col] = member.offsetof;
					if(memberName != "_id_") {
						columnNames ~= toColumnName!memberName;
					}
				} else {
					throw new Error("Column " ~ toColumnName!memberName ~ " does not exist in table " ~ tableName ~ ".");
				}
				++i;
			}
		}
		saveStatement ~= columnNames.join(",");
		saveStatement ~= ") VALUES (";
		if(i > 1) {
			saveStatement ~= replicate("?,", i - 1)[0 .. $ - 1];
		}
		saveStatement ~= ");";
		updateStatement ~= columnNames.join("=?, ");
		updateStatement ~= "=? WHERE id=?;";
		saveQuery = db.query(saveStatement);
		updateQuery = db.query(updateStatement);
	}

	//If only CTFE would kick in...
	//To do: how to handle members w/ only a leading underscore?
	template toColumnName(string memberName) {
		static if(memberName[0] == '_' && memberName[$ - 1] == '_') {
			enum string toColumnName = memberName[1 .. $ - 1];
		} else {
			enum string toColumnName = memberName;
		}
	}
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
Represents a single result from a join operation
+/
struct Join(T ...) {
	mixin joinMembers!T;
	
	static Join fromQuery(Query q) {
		size_t index = 0;
		typeof(this) result;
		foreach(memberName; __traits(allMembers, Join)) {
			mixin("alias result." ~ memberName ~ " member;");
			static if(isInstanceDataMember!member) {
				auto ptr = &__traits(getMember, result, memberName);
				*ptr = typeof(*ptr).fromQuery(q, index);
				index += typeof(member).memberToColumn.length;
			}
		}
		return result;
	}
}

private template joinMembers(T ...) {
	static if(T.length > 0) {
		static if(T[0].stringof.length > 1) {
			mixin("T[0] " ~ toLower(T[0].stringof[0 .. 1]) ~ T[0].stringof[1 .. $] ~ ";");
		} else {
			mixin("T[0] " ~ toLower(T[0].stringof) ~ ";");
		}
		mixin joinMembers!(T[1 .. $]);
	}
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


