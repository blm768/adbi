module adbi.querybuilder;

import std.algorithm;
import std.range;
import std.string;

import std.traits;

import adbi.database;
import adbi.model;

/++
Represents the contents of a query in an abstract form that can be converted to an SQL statement
+/
struct QueryBuilder {
	class InvalidQueryError: Error { this(string msg) { super(msg); } }
	/++
	The operation a query will perform (i.e. SELECT)
	+/
	enum Operation {
		select,
		update,
		del,
	}
	
	///
	Operation operation;
	///The names of the columns/expressions to be returned by the query
	const(char)[][] columns;
	///The conditions appearing in the WHERE clause
	const(char)[][] whereConditions;
	///The source table or expression
	const(char)[] fromClause;
	
	///Creates a Query from this object
	@property Query query(Database db) {
		return db.query(statement);
	}
	
	///Creates an SQL statement from this object
	@property const(char)[] statement() {
		const(char)[] base;
		switch(operation) {
			case Operation.select:
				if(fromClause.length == 0) {
					throw new InvalidQueryError("No fromClause provided");
				}
				//To do: remove saves?
				base = "SELECT (%s) FROM %s".format(columns.save.join(","), fromClause);
				if(whereConditions.length > 0) {
					base ~= " WHERE ";
					base ~= whereClause;
				}
				return base;
			default:
				assert(false);
		}
	}
	
	///Returns a QueryBuilder that is a copy of this one with an added whereCondition
	QueryBuilder where(const(char)[] condition) {
		auto result = this;
		result.whereConditions ~= condition;
		return result;
	}
	
	@property const(char)[] whereClause() {
		return whereConditions.save.map!(s => "(%s)".format(s)).join(" AND ");
	}
}


//To do: move to model.d?
/++
Associates a QueryBuilder with a Model
+/
struct ModelQueryBuilder(Model) {
	@property ModelQuery!Model query() {
		return Model.query(statement);
	}
	
	QueryBuilder builder;
	alias builder this;
}
