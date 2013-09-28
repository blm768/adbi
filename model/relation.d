module adbi.model.relation;

public import adbi.model.model;
import adbi.querybuilder;

/++
Associates a QueryBuilder with a Model
+/
struct Relation(Model) {
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
	
	private:
	QueryBuilder builder;
}
