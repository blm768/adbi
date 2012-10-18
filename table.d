module adbi.table;

public import adbi.database;
public import adbi.type;

abstract class Table {
	//@property size_t rows;
	ColumnSet columns;
}

abstract class ColumnSet {
	Column opIndex(const(char)[] name);
	
	Column opIndex(size_t index) {
		return _columns[index];
	}
	
	private:
	Column[] _columns;
}

enum ColumnType {
	none, int_, float_, text, blob
}

struct Column {
	string name;
	size_t index;
	ColumnType type;
}
