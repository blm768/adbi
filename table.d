module adbi.table;

public import adbi.database;
public import adbi.type;

abstract class Table {
	@property size_t rows;
	ColumnSet columns;
}

abstract class ColumnSet {
	Column opIndex(const(char)[] name);
}

struct Column {
	string name;
}