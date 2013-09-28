module adbi.model.relation;

public import adbi.model.model;
import adbi.querybuilder;

/++
Associates a QueryBuilder with a Model
+/
struct Relation(Model) {
	this(QueryBuilder builder) {
		this.builder = builder;
	}

	@property const(char)[] statement() {
		return builder.statement;
	}
	
	//TODO: caching?
	@property Query query() {
		return Model.database.query(statement);
	}

	@property ModelRange!Model results() {
		return ModelRange!Model(query);
	}

	alias results this;

	@property const(char)[][] columns() {
		return builder.columns;
	}
	
	@property const(char)[] table() {
		return builder.table;
	}
	
	typeof(this) where(const(char)[] condition) {
		auto result = this;
		result.builder = builder.where(condition);
		return result;
	}

	size_t count() {
		auto builder = this.builder;
		builder.columns = ["count(*)"];
		auto query = Model.database.query(builder.statement);
		query.advance();
		return query.get!int(0);
	}

	@property Model first() {
		return results.front;
	}
	
	private:
	QueryBuilder builder;
}
