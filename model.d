module adbi.model;

public import std.array;
import std.stdio;

public import adbi.database;
public import adbi.traits;

mixin template Model(string _tableName) {
	enum string tableName = _tableName;
	static size_t[] memberToColumn;
	static size_t[] columnToMember;
	
	private:
	static Query saveQuery;
	
	public:
	@property size_t id() {
		return _id_;
	}
	
	@property bool inDatabase(Database db) {
		//To do: verify that this works for all DBs.
		if(id == 0)
			{return false;}
		auto q = db.query("SELECT * FROM " ~ tableName ~ " WHERE id = ?;");
		q.bind(1, id);
		return q.advance() == QueryStatus.hasData;
	}
	
	void save(Database db) {
		saveQuery.reset();
		size_t i = 1;
		foreach(memberName; __traits(allMembers, typeof(this))) {
			mixin("alias this." ~ memberName ~ " member;");
			static if(isInstanceDataMember!member) {
				static if(memberName != "_id_") {
					//Is this column in the database?
					writeln(memberName);
					writeln(i);
					if(memberToColumn[i - 1] < size_t.max) {
						writeln(memberName);
						//enum string colName = toColumnName!memberName;
						saveQuery.bind(i, member);
					}
					++i;
				}
			}
		}
		assert(saveQuery.advance() == QueryStatus.finished);
		//To do: remove?
		saveQuery.reset();
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
		char[] saveStatement = ("INSERT INTO " ~ tableName ~ " (").dup;
		char[] colNames;
		auto t = db.tables[tableName];
		memberToColumn.length = 0;
		columnToMember = uninitializedArray!(size_t[])(t.columnNames.length);
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
						if(colNames.length > 0) {
							colNames ~= ",";
						}
						colNames ~= (toColumnName!memberName);
					}
				} else {
					memberToColumn ~= size_t.max;
					columnToMember [i] = size_t.max;
				}
				++i;
			}
		}
		saveStatement ~= colNames;
		saveStatement ~= ") VALUES (";
		if(i > 1) {
			saveStatement ~= replicate("?,", i - 1)[0 .. $ - 1];
		}
		saveStatement ~= ");";
		saveQuery = db.query(saveStatement);
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

