module adbi.model.relation;

public import adbi.model.model;
import adbi.statements;

/**
Associates a QueryBuilder with a Model

TODO: when writeln() is used on a Relation, it causes
an infinite loop. Regular iteration works fine.
Why?
*/
struct Relation(T) {
	alias T Model;

	//TODO: use assumeSafeAppend?
	/**
	Returns an SQL statement matching the Relation
	*/
	@property const(char)[] statement() {
		auto statement = selectStatement(Model.tableName, Model.columnNames);
		if(conditions.length) {
			statement ~= whereClause(conditions);
		}
		return statement;
	}
	
	/**
	Returns a query object for the relation
	TODO: caching?
	*/
	@property Query query() {
		return Model.database.query(statement);
	}

	///
	@property ModelRange!Model results() {
		return ModelRange!Model(query);
	}

	alias results this;

	/**
	Returns a new Relation with the condition added to it
	*/
	typeof(this) where(const(char)[] condition) {
		auto result = this;
		result.conditions ~= Condition(condition);
		return result;
	}

	/**
	Returns the number of records matching the Relation
	*/
	size_t count() {
		auto statement = selectStatement(Model.tableName, "count(*)");
		if(conditions.length) {
			statement ~= whereClause(conditions);
		}
		auto query = Model.database.query(statement);
		query.advance();
		return query.get!int(0);
	}

	Condition[] conditions;
}
