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
	@property Statement statement() {
		auto base = selectClause(Model.tableName, Model.columnNames);
		auto statement = Statement(base, whereClause(conditions));
		return statement;
	}
	
	/**
	Returns a query object for the relation
	TODO: caching?
	*/
	@property Query query() {
		auto statement = this.statement;
		auto query = Model.database.query(statement.text);
		statement.bindValues(query);
		return query;
	}

	///
	@property ModelRange!Model results() {
		return ModelRange!Model(query);
	}

	alias results this;

	/**
	Returns a new Relation with the condition added to it
	*/
	typeof(this) where(T ...)(const(char)[] condition, T values) {
		auto result = this;
		result.conditions ~= Condition(condition, values);
		return result;
	}

	Model find(RecordID id) {
		//TODO: add a limit clause!
		return where("id = ?", id).front;
	}

	/**
	Returns the number of records matching the Relation
	*/
	size_t count() {
		auto base = selectClause(Model.tableName, "count(*)");
		auto statement = Statement(base, whereClause(conditions));
		auto query = Model.database.query(statement.text);
		statement.bindValues(query);
		query.advance();
		return query.get!int(0);
	}

	Condition[] conditions;
}
