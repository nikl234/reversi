#include "data.cuh"

// todo: add the PostgreSQL implementations here to add and get it out of the DB
result pg::get_open_pg(int size) {
	work w(*c);
	result r = w.exec_prepared("SELECT_PLAYGROUNDS", size);
	return r;
}

result pg::get_open_poss(int size) {
	work w(*c);
	result r = w.exec_prepared("SELECT_POS", size);
	return r;
}

int pg::connect() {
	c = new connection("dbname = reversi user = postgres password = atotallysecurepassword hostaddr = 127.0.0.1 port = 5432");

	if(c->is_open()) {
		cout << "Opened DB: " << (*c).dbname() << endl;

		pg::prepare();

		return 0;
	} else cout << "Can not open DB" << (*c).dbname() << endl;
	return 1;
}

int pg::insertPlayground(short *pg, short *round, int *last_pg, short2 *poss, int size) {
	cout << "Inserting pgs.." << endl;
	work w(*c);

	for(int x = 0; x < size; x++) {
		stringstream s;
		s << "{";

		for(int i = 0; i < 63; i++) {
			s << std::to_string(pg[i]) << ",";
		}
		s << std::to_string(pg[64]) << "}";
		string array = s.str();

		result r = w.exec_prepared("INSERT_PG", round[x] + 1, array);
		w.exec_prepared("UPDATE_POS", r[0][0].as<int>(), last_pg[x], poss[x].x, poss[x].y);
		cout << "New id: " << r[0][0] << " " << array << endl;
	}


	w.commit();

	return 0;
}

int pg::prepare() {
	cout << "Preparing Statements.." << endl;
	cout << c << endl;

	c->prepare("SELECT_PLAYGROUNDS", "SELECT * FROM playground WHERE NOT pos_generated LIMIT $1");
	c->prepare("INSERT_PG", "INSERT INTO playground(round, map) VALUES($1, $2) RETURNING playground");
	c->prepare("UPDATE_PG", "UPDATE playground SET pos_generated = true WHERE playground = $1");
	c->prepare("INSERT_POS", "INSERT INTO link(last_pg, x, y) VALUES($1, $2, $3)");
	c->prepare("UPDATE_POS", "UPDATE link SET next_pg = $1 WHERE last_pg = $2 AND x = $3 AND y = $4");
	c->prepare("SELECT_POS", "SELECT last_pg, x, y, round, map FROM link l LEFT JOIN playground p ON l.last_pg = p.playground WHERE next_pg IS NULL LIMIT $1");

	return 0;
}

int pg::insertPoss(int id, short x, short y) {
	work w(*c);
	w.exec_prepared("INSERT_POS", id, x, y);
	w.exec_prepared("UPDATE_PG", id);
	w.commit();
	return 0;
}
