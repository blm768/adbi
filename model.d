module adbi.model;

public import std.array;
import std.stdio;

public import adbi.database;
public import adbi.traits;

mixin template Model(string _tableName) {
	enum string tableName = _tableName;
	static size_t[] memberToColumn; 
	static size_t[] columnToMember;
	
	static void getNextFromQuery(Query q) {
		q.advance();
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
		
	}
	
	T popFront() {
		
	}
}

