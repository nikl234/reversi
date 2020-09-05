#ifndef PG_DATA_H
#define PG_DATA_H


#include <iostream>
#include <pqxx/pqxx>


using namespace pqxx;
using namespace std;

class pg {
private:
	connection *c;

public:
	result get_open_pg(int size);

	result get_open_poss(int size);

	int connect();

	int insertPlayground(short *pg, short *round, int *last_pg, short2 *poss, int size);

	int insertPoss(int id, short x, short y);

	int prepare();
};

#endif
