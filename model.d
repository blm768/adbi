module adbi.model;

public import std.array;
import std.stdio;

public import adbi.database;

mixin template Model(string _tableName) {
	enum string tableName = _tableName;
	static size_t[] memberToColumn; 
	static size_t[] columnToMember;
	
	static void updateSchema(Database db) {
		auto t = db.tables[tableName];
		memberToColumn.length = 0;
		columnToMember = uninitializedArray!(size_t[])(t.columnNames.length);
		typeof(this) instance;
		size_t i = 0;
		foreach(memberName; __traits(allMembers, typeof(this))) {
			mixin("alias " ~ typeof(this).stringof ~ "." ~ memberName ~ " member;");
			//Is this an instance member?
			//To do: test; this might not always work.
			if(!__traits(compiles, &(member))) {
				auto col = memberName in t.columnIndices;
				if(col) {
					writeln(memberName);
					memberToColumn ~= *col;
					columnToMember[*col] = i;
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

