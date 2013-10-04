module adbi.model.association;

mixin template belongsTo(T, string name) {
	//mixin(typeof(T).stringof ~ " " 

	mixin("RecordID " ~ name ~ "Id;");
	private:
	mixin("alias " ~ name ~ "Id _association_id;");
}
