module adbi.database;

public import adbi.table;

abstract class Database {
	TableSet tables;
}

interface TableSet {
	Table opIndex(const(char)[] name);
}