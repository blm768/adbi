module adbi.querybuilder;

import std.algorithm;
import std.conv;
import std.range;
import std.string;

import adbi.database;
import adbi.model.model;

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
		insert,
		update,
		del,
	}
	
	///
	Operation operation;
	///The names of the columns/expressions to be returned by the query
	const(char)[][] columns;
	///The conditions appearing in the WHERE clause
	const(char)[][] conditions;
	///The source table or expression
	const(char)[] table;
	
	///Creates a Query from this object
	@property Query query(Database db) {
		return db.query(statement);
	}
	
	///Creates an SQL statement from this object
	@property const(char)[] statement() {
		const(char)[] statement;
		if(table.length == 0) {
			throw new InvalidQueryError("No table provided");
		}
		switch(operation) {
			case Operation.select:
				//To do: remove saves?
				statement = "SELECT (%s) FROM %s".format(columns.save.join(","), table);
				if(conditions.length > 0) {
					statement ~= " WHERE ";
					statement ~= whereClause;
				}
				break;
			case Operation.insert:
				statement = "INSERT INTO %s (%s) VALUES (%s)".format(table, columns.save.join(","), std.range.repeat("?", columns.length).join(","));
				break;
			case Operation.update:
				//To do: consider case where there are no columns.
				statement = "UPDATE %s SET %s=?".format(table, columns.join("=?, "));
				if(conditions.length > 0) {
					statement ~= " WHERE ";
					statement ~= whereClause;
				}
				break;
			default:
				assert(false, "Unsupported operation " ~ operation.to!string());
		}
		return statement;
	}
	
	///Returns a QueryBuilder that is a copy of this one with an added whereCondition
	QueryBuilder where(const(char)[] condition) {
		auto result = this;
		result.conditions ~= condition;
		return result;
	}
	
	@property const(char)[] whereClause() {
		return conditions.save.map!(s => "(%s)".format(s))().join(" AND ");
	}
}
