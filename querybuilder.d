module adbi.querybuilder;

import std.algorithm;
import std.conv;
import std.range;
import std.string;

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
		insert,
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
				if(whereConditions.length > 0) {
					statement ~= " WHERE ";
					statement ~= whereClause;
				}
				break;
			case Operation.insert:
				statement = "INSERT INTO %s (%s) VALUES (%s)".format(table, columns.save.join(","), std.range.repeat("?", columns.length).join(","));
				break;
			default:
				assert(false, "Unsupported operation " ~ operation.to!string());
		}
		return statement;
	}
	
	///Returns a QueryBuilder that is a copy of this one with an added whereCondition
	QueryBuilder where(const(char)[] condition) {
		auto result = this;
		result.whereConditions ~= condition;
		return result;
	}
	
	@property const(char)[] whereClause() {
		return whereConditions.save.map!(s => "(%s)".format(s))().join(" AND ");
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
	
	@property const(char)[] statement() {
		return builder.statement;
	}
	
	@property const(char)[][] columns() {
		return builder.columns;
	}
	
	@property void columns(const(char)[][] value) {
		builder.columns = value;
	}
	
	@property const(char)[] table() {
		return builder.table;
	}
	
	@property void table(const(char)[] value) {
		builder.table = value;
	}
	
	typeof(this) where(const(char)[] condition) {
		auto result = this;
		result.builder = builder.where(condition);
		return result;
	}
	
	//To do: wrap builder's methods.
	
	private:
	QueryBuilder builder;
}
