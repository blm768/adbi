module adbi.model.relation;

public import adbi.model.model;
import adbi.statements;

/++
Associates a QueryBuilder with a Model
+/
struct Relation(T) {
	alias T Model;

	//TODO: use assumeSafeAppend?
	@property const(char)[] statement() {
		auto statement = selectStatement(Model.tableName, Model.columnNames);
		if(conditions.length) {
			statement ~= whereClause(conditions);
		}
		return statement;
	}
	
	//TODO: caching?
	@property Query query() {
		return Model.database.query(statement);
	}

	@property ModelRange!Model results() {
		return ModelRange!Model(query);
	}

	alias results this;

	typeof(this) where(const(char)[] condition) {
		auto result = this;
		result.conditions ~= condition;
		return result;
	}

	size_t count() {
		auto statement = selectStatement(Model.tableName, "count(*)");
		if(conditions.length) {
			statement ~= whereClause(conditions);
		}
		auto query = Model.database.query(statement);
		query.advance();
		return query.get!int(0);
	}

	@property Model first() {
		return results.front;
	}

	const(char)[][] conditions;
}
