module adbi.model;

public import std.array;
import std.stdio;

public import adbi.database;
public import adbi.traits;

mixin template Model(string _tableName) {
	enum string tableName = _tableName;
	static size_t[] memberToColumn; 
	static size_t[] columnToMember;
	
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
				}
				++i;
			}
		}
		return instance;
	}
	
	static void updateSchema(Database db) {
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
				auto col = memberName in t.columnIndices;
				if(col) {
					memberToColumn ~= *col;
					columnToMember[*col] = member.offsetof;
				} else {
					memberToColumn ~= size_t.max;
					columnToMember [i] = size_t.max;
				}
				++i;
			}
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

