module adbi.querybuilder;

import std.algorithm;
import std.range;
import std.string;

import std.traits;

import adbi.database;

struct QueryBuilder {
	enum Operation {
		select,
		update,
		del,
	}
	
	Operation operation;
	const(char)[][] values;
	const(char)[][] whereClauses;
	const(char)[] fromClause;
	
	const(char)[] build() {
		const(char)[] base;
		switch(operation) {
			case Operation.select:
				base = "SELECT (%s) FROM %s".format(values.save.join(","), fromClause);
				if(whereClauses.length > 0) {
					base ~= " WHERE ";
					base ~= whereClause;
				}
				return base;
			default:
				assert(false);
		}
	}
	
	QueryBuilder where(const(char)[] condition) {
		auto result = this;
		result.whereClauses ~= condition;
		return result;
	}
	
	@property const(char)[] whereClause() {
		return whereClauses.save.map!(s => "(%s)".format(s)).join(" AND ");
	}
}
