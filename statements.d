module adbi.statements;

import std.algorithm;
import std.array;
import std.conv;
import std.range;
import std.string;
import std.variant;

import adbi.database;

struct Clause {
	const(char)[] expression;
	BindValue[] values;

	void bindValues(Query q, size_t index) {
		foreach(value; values) {
			value.bindTo(q, index);
			++index;
		}
	}
}

struct Statement {
	this(Clause[] clauses ...) pure in {
		assert(clauses.length > 0);
	} body {
		auto text = appender(clauses[0].expression);
		foreach(clause; clauses[1 .. $]) {
			if(clause.expression.length) {
				text.put(" ");
				text.put(clause.expression);
			}
		}
		
		this.text = text.data;
		//The clauses array may contain a stack reference, so it must
		//be duplicated.
		//TODO: optimize?
		this.clauses = clauses.dup;
	}


	const(char)[] text;
	Clause[] clauses;

	void bindValues(Query q) {
		size_t index = 0;
		foreach(clause; clauses) {
			clause.bindValues(q, index);
			index += clause.values.length;
		}
	}
}

unittest {
	
}

struct Condition {
	this(T ...)(const(char)[] expression, T values) {
		//TODO: validate the number of binding slots provided?
		this.expression = expression;
		this.values = uninitializedArray!(typeof(this.values))(values.length);
		foreach(i, value; values) {
			this.values[i] = BindValue(value);
		}
	}
	const(char)[] expression;
	BindValue[] values;
}

Clause whereClause(Condition[] conditions) {
	if(conditions.length == 0) {
		return Clause();
	}

	auto expression = "WHERE " ~ conditions.map!(c => "(%s)".format(c.expression)).join(" AND ");
	Appender!(BindValue[]) values;
	foreach(c; conditions) {
		values.put(c.values);
	}
	return Clause(expression, values.data);
}

unittest {

}

//TODO: return a Clause instead of a string?
string insertClause(const(char)[] table, const(char[])[] columns) pure {
	auto cols = columns.map!(s => s[])();
	return "INSERT INTO %s (%s) VALUES (%s)".format(table, cols.join(","), std.range.repeat("?", columns.length).join(","));
}

unittest {

}

string updateClause(const(char)[] table, const(char[])[] columns) pure {
	auto cols = columns.map!(s => s[])();
	return "UPDATE %s SET %s=?".format(table, cols.join("=?, "));
}

unittest {
	
}

Clause selectClause(const(char)[] table, const(char[])[] columns ...) pure {
	auto cols = columns.map!(s => s[])();
	return Clause("SELECT %s FROM %s".format(cols.join(", "), table));
}

Clause limitClause(size_t limit) {
	//TODO: find a cleaner way of handling the limit?
	if(limit == size_t.max) {
		return Clause();
	} else {
		return Clause("LIMIT " ~ limit.to!string());
	}
}

unittest {

}
