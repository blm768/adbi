module adbi.model.association;

mixin template association(T, name) {

	private:
	mixin(T.stringof ~ " _" ~ name ~ "_id;");
}
