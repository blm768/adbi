module adbi.model;

public import std.array;
import std.stdio;

public import adbi.database;
public import adbi.traits;
public import core.exception;

mixin template Model(string _tableName) {
	enum string tableName = _tableName;
	static size_t[] memberToColumn;
	static size_t[] columnToMember;
	static @property Database database() {
		return saveQuery.database;
	}
	
	private:
	static Query saveQuery;
	static Query updateQuery;
	
	public:
	@property size_t id() {
		return _id_;
	}
	
	@property bool inDatabase() {
		//To do: verify that this works for all DBs.
		if(id == 0)
			{return false;}
		//To do: don't constantly recreate this query.
		auto q = database.query("SELECT * FROM " ~ tableName ~ " WHERE id = ?;");
		q.bind(1, id);
		return q.advance() == QueryStatus.hasData;
	}
	
	void save() {
		if(inDatabase) {
			//To do: update columns.
			updateQuery.reset();
			size_t i = 1;
			foreach(memberName; __traits(allMembers, typeof(this))) {
				mixin("alias this." ~ memberName ~ " member;");
				static if(isInstanceDataMember!member) {
					static if(memberName != "_id_") {
						updateQuery.bind(i, member);
						++i;
					}
				}
			}
			updateQuery.bind(i, id);
			assert(updateQuery.advance() == QueryStatus.finished);
			//To do: remove?
			updateQuery.reset();
		} else {
			saveQuery.reset();
			size_t i = 1;
			foreach(memberName; __traits(allMembers, typeof(this))) {
				mixin("alias this." ~ memberName ~ " member;");
				static if(isInstanceDataMember!member) {
					static if(memberName != "_id_") {
						saveQuery.bind(i, member);
						++i;
					}
				}
			}
			assert(saveQuery.advance() == QueryStatus.finished);
			//To do: remove?
			saveQuery.reset();
		}
	}
	
	private:
	size_t _id_;
	
	public:
	static typeof(this) fromQuery(Query q) {
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
					*ptr = q.get!(typeof(member))(memberToColumn[i]);
				} else {
					assert(false, "Field " ~ memberName ~ " not present in database");
				}
				++i;
			}
		}
		return instance;
	}
	
	static void updateSchema(Database db) {
		char[] saveStatement = "INSERT INTO ".dup ~ tableName ~ " (";
		char[] updateStatement = "UPDATE ".dup ~ tableName ~ " SET ";
		string[] colNames;
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
						colNames ~= toColumnName!memberName;
					}
				} else {
					throw new Error("Column " ~ toColumnName!memberName ~ " does not exist in table " ~ tableName ~ ".");
				}
				++i;
			}
		}
		saveStatement ~= colNames.join(",");
		saveStatement ~= ") VALUES (";
		if(i > 1) {
			saveStatement ~= replicate("?,", i - 1)[0 .. $ - 1];
		}
		saveStatement ~= ");";
		updateStatement ~= colNames.join("=?, ");
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

mixin template reference(string name, string foreignTableName, T) {
	static Query referenceQuery;
	mixin("size_t " ~ name ~ "_id;");
	mixin("@property T " ~ name ~ `(){
		if(!referenceQuery) {
			referenceQuery = database.query("SELECT * FROM " ~ foreignTableName ~ " WHERE id = ?;");
		}
		referenceQuery.reset();
		referenceQuery.bind(1, ` ~ name ~ `_id);
		return T.fromQuery(referenceQuery);
	}`);
}

struct ModelRange(T) {
	Query q;
	
	T front() {
		return T.fromQuery(q);
	}
	
	T popFront() {
		T value = front;
		if(q.status == QueryStatus.hasData)
			{q.advance();}
		return value;
	}
	
	@property bool empty() {
		if(q.status == QueryStatus.notStarted)
			{q.advance();}
		return q.status != QueryStatus.hasData;
	}
}

